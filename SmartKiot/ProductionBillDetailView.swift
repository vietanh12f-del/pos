import SwiftUI

/// Hiển thị chi tiết phiếu sản xuất (nhập/xuất nguyên liệu, nhập/xuất thành phẩm)
/// và cho phép in lại đơn — tương tự BillDetailView bên bán lẻ.
struct ProductionBillDetailView: View {
    let tx: ProductionTransaction
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSharing = false

    // MARK: - Computed helpers

    private var receiptLines: [String] {
        StoreManager.shared.currentStoreReceiptHeaderLines()
    }

    private var isExport: Bool {
        tx.mode.lowercased().contains("xuất")
    }

    private var isFinishedGoods: Bool {
        tx.mode.lowercased().contains("thành phẩm")
    }

    private var isRegularRestock: Bool { false }

    private var billTitle: String {
        switch tx.mode {
        case "Nhập Nguyên liệu":  return "PHIẾU NHẬP NGUYÊN LIỆU"
        case "Xuất Nguyên liệu":  return "PHIẾU XUẤT NGUYÊN LIỆU"
        case "Nhập Thành Phẩm":   return "PHIẾU NHẬP THÀNH PHẨM"
        case "Xuất Thành Phẩm":   return "PHIẾU XUẤT THÀNH PHẨM"
        default:                  return tx.mode.uppercased()
        }
    }

    private var billNavTitle: String {
        switch tx.mode {
        case "Nhập Nguyên liệu":  return "Bill nhập nguyên liệu"
        case "Xuất Nguyên liệu":  return "Bill xuất nguyên liệu"
        case "Nhập Thành Phẩm":   return "Bill nhập thành phẩm"
        case "Xuất Thành Phẩm":   return "Bill xuất thành phẩm"
        default:                  return "Chi tiết phiếu"
        }
    }

    private var billPartyHeader: String {
        isExport ? "THÔNG TIN BÊN MUA" : "THÔNG TIN CƠ SỞ CUNG CẤP"
    }

    private var vatEnabled: Bool { StoreManager.shared.currentStoreVATEnabled() }
    private var vatRate: Double   { StoreManager.shared.currentStoreVATRate() }

    private var subtotal: Double {
        tx.items.reduce(0) { acc, it in
            let isCai = it.unit?.lowercased() == "cái"
            if isCai {
                return acc + Double(it.quantity) * it.unitPrice + it.additionalCost
            } else {
                return acc + Double(it.quantity) / 1000.0 * it.unitPrice + it.additionalCost
            }
        }
    }
    private var vatAmount: Double  { vatEnabled ? subtotal * (vatRate / 100.0) : 0 }
    private var grandTotal: Double { tx.grandTotal ?? (subtotal + vatAmount) }
    private var paidAmount: Double { tx.paidAmount ?? grandTotal }
    private var debtAmount: Double { tx.debtAmount ?? 0 }

    private var qrURL: URL? {
        guard isExport, grandTotal > 0,
              let bankName = StoreManager.shared.currentStore?.bankName, !bankName.isEmpty,
              let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber, !bankAccount.isEmpty
        else { return nil }
        var code = bankName
        if let range = code.range(of: "\\((.*?)\\)", options: .regularExpression) {
            code = String(code[range].dropFirst().dropLast())
        }
        let amount = Int(paidAmount)
        let buyer = (tx.buyerName ?? "").prefix(10)
        let info = "XuatTP \(buyer)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "XuatTP"
        return URL(string: "https://img.vietqr.io/image/\(code)-\(bankAccount)-compact.png?amount=\(amount)&addInfo=\(info)")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    billContent
                        .padding()

                    // Button In đơn
                    Button {
                        Task { await shareBill() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSharing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                            }
                            Text(isSharing ? "Đang xử lý..." : "In đơn")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.themePrimary, Color.themePrimary.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.themePrimary.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSharing)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(billNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bill content (tái sử dụng layout của ExportBillPrintView)

    private var billContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Store header
            VStack(alignment: .center, spacing: 4) {
                ForEach(Array(receiptLines.enumerated()), id: \.offset) { _, line in
                    if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(line)
                            .font(.subheadline).fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    }
                }
                Text(billTitle)
                    .font(.headline).fontWeight(.bold)
                    .padding(.top, 4)
                if let stt = tx.sequenceNumber {
                    Text("STT: \(stt)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                Text(formatDateTime(tx.createdAt))
                    .font(.caption).foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Creator
            if let name = tx.creatorName, !name.isEmpty {
                HStack {
                    Text(isExport ? "Nhân viên xuất:" : "Nhân viên nhập:")
                        .font(.caption).foregroundStyle(.gray)
                    Text(name).font(.caption).fontWeight(.semibold)
                }
            }

            // Buyer / Supplier info (chỉ khi có)
            if let buyerName = tx.buyerName, !buyerName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(billPartyHeader)
                        .font(.caption).fontWeight(.bold).foregroundStyle(.gray)
                    Text(buyerName).font(.subheadline).fontWeight(.semibold)
                    if let phone = tx.buyerPhone, !phone.isEmpty {
                        Text("SĐT: \(phone)").font(.caption).foregroundStyle(.gray)
                    }
                    if let address = tx.buyerAddress, !address.isEmpty {
                        Text("ĐC: \(address)").font(.caption).foregroundStyle(.gray)
                    }
                }
            }

            Divider()

            // Items
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Hàng hoá").font(.caption).foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("SL").font(.caption).foregroundStyle(.gray)
                        .frame(width: 70, alignment: .trailing)
                    Text("Thành tiền").font(.caption).foregroundStyle(.gray)
                        .frame(width: 90, alignment: .trailing)
                }
                Divider()
                ForEach(tx.items, id: \.id) { item in
                    let isCai = item.unit?.lowercased() == "cái"
                    let qtyText = isCai ? "\(item.quantity)" : FormatUtils.formatWeight(item.quantity, unit: item.unit)
                    let lineTotal: Double = isCai
                        ? Double(item.quantity) * item.unitPrice + item.additionalCost
                        : Double(item.quantity) / 1000.0 * item.unitPrice + item.additionalCost
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.name).font(.subheadline)
                                if item.hasVAT {
                                    Text("VAT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.green.opacity(0.85))
                                        .clipShape(Capsule())
                                }
                            }
                            let unitLabel = isCai ? "/cái" : "/kg"
                            Text(formatCurrency(item.unitPrice) + unitLabel)
                                .font(.caption).foregroundStyle(.gray)
                            if item.additionalCost > 0 {
                                Text("Chi phí: \(formatCurrency(item.additionalCost))")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(qtyText).font(.subheadline)
                            .frame(width: 70, alignment: .trailing)
                        Text(formatCurrency(lineTotal)).font(.subheadline).fontWeight(.semibold)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            }

            Divider()

            // Totals
            VStack(spacing: 6) {
                if vatEnabled {
                    HStack {
                        Text("Tổng tiền hàng").font(.subheadline).foregroundStyle(.gray)
                        Spacer()
                        Text(formatCurrency(subtotal)).font(.subheadline)
                    }
                    HStack {
                        Text("VAT (\(Int(vatRate))%)").font(.subheadline).foregroundStyle(.gray)
                        Spacer()
                        Text(formatCurrency(vatAmount)).font(.subheadline)
                    }
                }
                HStack {
                    Text("Tổng cộng").font(.headline).fontWeight(.bold)
                    Spacer()
                    Text(formatCurrency(grandTotal)).font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                if debtAmount > 0 {
                    HStack {
                        Text("Còn lại").font(.subheadline).foregroundStyle(.red)
                        Spacer()
                        Text(formatCurrency(debtAmount)).font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    if let payDate = tx.expectedPayDate {
                        HStack {
                            Text("Dự kiến trả:").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatDateOnly(payDate)).font(.caption).fontWeight(.semibold)
                        }
                    }
                }
            }

            // QR code (chỉ khi xuất và có thông tin ngân hàng)
            if let url = qrURL {
                Divider()
                VStack(spacing: 8) {
                    Text("Quét mã QR để thanh toán")
                        .font(.caption).foregroundStyle(.gray)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: 160, height: 160).cornerRadius(10)
                        case .empty:
                            ProgressView().frame(width: 160, height: 160)
                        default:
                            Image(systemName: "qrcode")
                                .font(.system(size: 50)).foregroundStyle(.gray)
                                .frame(width: 160, height: 160)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Chữ ký
            Divider()
            HStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text(isExport ? "Người xuất" : "Người nhập")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                    Text(tx.creatorName ?? " ")
                        .font(.caption).fontWeight(.bold).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text("Người xác nhận")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                    Text(" ").font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Share

    @MainActor
    private func shareBill() async {
        isSharing = true
        defer { isSharing = false }
        let renderer = ImageRenderer(content:
            billContent
                .padding(20)
                .background(Color.white)
                .frame(width: 390)
        )
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var top = root
            while let p = top.presentedViewController { top = p }
            av.popoverPresentationController?.sourceView = top.view
            top.present(av, animated: true)
        }
    }

    // MARK: - Formatters

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}
