import SwiftUI

struct BillDetailView: View {
    let bill: Bill
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var isPaid: Bool = true
    @State private var showReceiptCamera = false
    @State private var receiptImage: UIImage? = nil
    @State private var isUploadingReceipt = false
    @State private var receiptImageURLString: String? = nil
    @State private var showEditHistory = false
    @State private var dbEdits: [OrderEdit] = []
    
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
                    showButtons: true,
                    onComplete: nil,
                    customerName: bill.customerName ?? "Khách lẻ",
                    onOpenBankSettings: nil,
                    onCaptureReceipt: { showReceiptCamera = true },
                    receiptImageURL: receiptImageURLString,
                    onPickedReceiptImage: { img in receiptImage = img },
                    onEditDiscount: nil
                )
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                if !dbEdits.isEmpty || viewModel.hasHistory(for: bill.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Đã chỉnh sửa")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Button {
                            showEditHistory = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Xem lịch sử chỉnh sửa")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                
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
            receiptImageURLString = bill.paymentReceiptURL
            Task {
                do {
                    dbEdits = try await SupabaseDatabaseService().fetchOrderEdits(orderId: bill.id)
                    print("✅ [OrderEdit] Loaded \(dbEdits.count) edits in detail for \(bill.id)")
                } catch {
                    dbEdits = []
                    print("⚠️ [OrderEdit] Load edits failed for \(bill.id): \(error)")
                }
            }
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
        .sheet(isPresented: $showEditHistory) {
            if !dbEdits.isEmpty {
                EditHistorySheet2(edits: dbEdits)
            } else {
                EditHistorySheet(entries: viewModel.history(for: bill.id))
            }
        }
        .fullScreenCover(isPresented: $showReceiptCamera) {
            ImagePicker(image: $receiptImage)
                .ignoresSafeArea()
        }
        .onChange(of: receiptImage) { img in
            guard let img else { return }
            Task {
                isUploadingReceipt = true
                defer { isUploadingReceipt = false }
                if let data = img.jpegData(compressionQuality: 0.8) {
                    let fileName = StorageManager.shared.generateImageName()
                    do {
                        let url = try await StorageManager.shared.uploadReceiptImage(data: data, fileName: fileName)
                        let target = CGSize(width: 800, height: 800)
                        let down = BillReceiptView.CachedImageLoader.downsample(data: data, to: target, scale: UIScreen.main.scale) ?? img
                        let previewData = down.jpegData(compressionQuality: 0.8) ?? data
                        let previewURL = try await StorageManager.shared.uploadReceiptPreviewImage(data: previewData, fileName: fileName)
                        if let u = URL(string: url) {
                            BillReceiptView.ImageCache.shared.insert(img, for: u)
                        }
                        if let pu = URL(string: previewURL) {
                            BillReceiptView.ImageCache.shared.insert(down, for: pu)
                        }
                        var updated = bill
                        updated.paymentReceiptURL = url
                        try await viewModel.updateOrder(updated)
                        await MainActor.run {
                            receiptImageURLString = url
                        }
                    } catch {
                        print("❌ Error uploading receipt: \(error)")
                    }
                }
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
                onPickedReceiptImage: nil,
                onEditDiscount: nil
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
    
    struct EditHistoryRow: View {
        let entry: OrderViewModel.BillEditEntry
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(format(entry.date))
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text("\(formatCurrency(entry.oldTotal)) → \(formatCurrency(entry.newTotal))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                if let name = entry.editorName, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(.gray)
                }
            }
            .padding(.vertical, 6)
        }
        private func format(_ date: Date) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "dd/MM/yyyy HH:mm"
            return f.string(from: date)
        }
    }
    
    struct EditHistorySheet: View {
        let entries: [OrderViewModel.BillEditEntry]
        var body: some View {
            NavigationStack {
                List(entries.sorted { $0.date > $1.date }) { e in
                    EditHistoryRow(entry: e)
                }
                .navigationTitle("Lịch sử chỉnh sửa")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    struct EditHistoryRow2: View {
        let edit: OrderEdit
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(format(edit.createdAt))
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    if let name = edit.editorName, !name.isEmpty {
                        Text(name).font(.caption).foregroundStyle(.gray)
                    }
                }
                Text("\(formatCurrency(edit.oldTotal)) → \(formatCurrency(edit.newTotal))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let note = edit.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let details = edit.details, !details.isEmpty {
                    ForEach(details, id: \.self) { d in
                        Text("• " + d).font(.caption)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        private func format(_ date: Date) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "dd/MM/yyyy HH:mm"
            return f.string(from: date)
        }
    }
    
    struct EditHistorySheet2: View {
        let edits: [OrderEdit]
        var body: some View {
            NavigationStack {
                List(edits.sorted { $0.createdAt > $1.createdAt }) { e in
                    EditHistoryRow2(edit: e)
                }
                .navigationTitle("Lịch sử chỉnh sửa")
                .navigationBarTitleDisplayMode(.inline)
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
        let infoBase = "SmartKiot \(shortId)"
        let allowed = CharacterSet.urlQueryAllowed
        let encodedInfo = infoBase.addingPercentEncoding(withAllowedCharacters: allowed) ?? "KNOTE"
        let urlString = "\(base)?amount=\(amount)&addInfo=\(encodedInfo)"
        return URL(string: urlString)
    }
}
