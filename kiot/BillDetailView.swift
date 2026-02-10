import SwiftUI

struct BillDetailView: View {
    let bill: Bill
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var isPaid: Bool = true
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Text("Đóng")
                        .font(.headline)
                        .foregroundStyle(Color.gray)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.startEditing(bill)
                    dismiss()
                }) {
                    Text("Sửa")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.blue)
                }
            }
            .padding()
            .background(Color.white)
            
            ScrollView {
                BillReceiptView(
                    items: bill.items,
                    totalAmount: bill.total,
                    dateString: formatDate(bill.createdAt),
                    qrURL: generateQRURL(for: bill),
                    qrImage: nil,
                    billPayload: nil,
                    showButtons: false,
                    onComplete: nil,
                    customerName: bill.customerName ?? "Khách lẻ",
                    onOpenBankSettings: nil,
                    onCaptureReceipt: nil,
                    receiptImageURL: bill.paymentReceiptURL,
                    onPickedReceiptImage: nil
                )
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                // Payment Status Toggle
                Button(action: {
                    isPaid.toggle()
                    var updatedBill = bill
                    updatedBill.isPaid = isPaid
                    Task {
                        do {
                            try await viewModel.updateOrder(updatedBill)
                        } catch {
                            print("❌ Error updating payment status: \(error)")
                            // Rollback on error
                            isPaid.toggle()
                        }
                    }
                }) {
                    Text(isPaid ? "Đã nhận tiền" : "Chưa nhận tiền")
                        .fontWeight(.bold)
                        .foregroundStyle(isPaid ? Color.green : Color.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isPaid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Button(action: {
                    renderImage()
                }) {
                    HStack {
                        Image(systemName: "printer.fill")
                        Text("In đơn (FlashLabel)")
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Xóa đơn hàng")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Chi tiết đơn hàng")
        .navigationBarHidden(true)
        .background(Color.themeBackgroundLight)
        .onAppear {
            isPaid = bill.isPaid
        }
        .alert("Xóa đơn hàng?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Xóa", role: .destructive) {
                viewModel.deleteOrder(bill)
                dismiss()
            }
        } message: {
            Text("Bạn có chắc muốn xóa đơn hàng này? Hành động này không thể hoàn tác.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    @MainActor
    private func renderImage() {
        Task {
            // Pre-load QR Code Image because ImageRenderer cannot capture AsyncImage
            var loadedQR: UIImage? = nil
            let qrURL = generateQRURL(for: bill)
            
            if let url = qrURL {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    loadedQR = UIImage(data: data)
                }
            }
            
            let renderView = BillReceiptView(
                items: bill.items,
                totalAmount: bill.total,
                dateString: formatDate(bill.createdAt),
                qrURL: qrURL,
                qrImage: loadedQR,
                billPayload: nil,
                showButtons: false,
                onComplete: nil,
                customerName: bill.customerName ?? "Khách lẻ",
                onOpenBankSettings: nil,
                onCaptureReceipt: nil,
                receiptImageURL: bill.paymentReceiptURL,
                onPickedReceiptImage: nil
            )
            .frame(width: 375)
            .background(Color.white)
            
            let renderer = ImageRenderer(content: renderView)
            renderer.scale = UIScreen.main.scale
            
            if let image = renderer.uiImage {
                renderedImage = image
                showShareSheet = true
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func generateQRURL(for bill: Bill) -> URL? {
        guard bill.total > 0 else { return nil }
        guard let rawBankName = StoreManager.shared.currentStore?.bankName, !rawBankName.isEmpty else { return nil }
        guard let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber, !bankAccount.isEmpty else { return nil }
        var bankName = rawBankName
        if let range = bankName.range(of: "\\((.*?)\\)", options: .regularExpression) {
            let code = bankName[range]
            let cleanCode = code.dropFirst().dropLast()
            bankName = String(cleanCode)
        }
        let finalBankAccount = bankAccount
        let amount = Int(bill.total)
        let base = "https://img.vietqr.io/image/\(bankName)-\(finalBankAccount)-compact.png"
        let shortId = bill.id.uuidString.prefix(8)
        let infoBase = "KNOTE \(shortId)"
        let allowed = CharacterSet.urlQueryAllowed
        let encodedInfo = infoBase.addingPercentEncoding(withAllowedCharacters: allowed) ?? "KNOTE"
        let urlString = "\(base)?amount=\(amount)&addInfo=\(encodedInfo)"
        return URL(string: urlString)
    }
}
