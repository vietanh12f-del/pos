import SwiftUI

/// Phiếu xuất kho - không hiển thị giá, thành tiền, tổng cộng
/// Chỉ hiển thị tên hàng, số lượng, đơn vị
struct ProductionExportWarehouseBillView: View {
    let tx: ProductionTransaction
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSharing = false

    private var receiptLines: [String] {
        StoreManager.shared.currentStoreReceiptHeaderLines()
    }

    private var isExport: Bool {
        tx.mode.lowercased().contains("xuất")
    }

    private var billTitle: String {
        switch tx.mode {
        case "Nhập Nguyên liệu":  return "PHIẾU NHẬP KHO"
        case "Xuất Nguyên liệu":  return "PHIẾU XUẤT KHO"
        case "Nhập Thành Phẩm":   return "PHIẾU NHẬP KHO"
        case "Xuất Thành Phẩm":   return "PHIẾU XUẤT KHO"
        default:                  return tx.mode.uppercased()
        }
    }

    private var billNavTitle: String {
        switch tx.mode {
        case "Nhập Nguyên liệu":  return "Phiếu nhập kho"
        case "Xuất Nguyên liệu":  return "Phiếu xuất kho"
        case "Nhập Thành Phẩm":   return "Phiếu nhập kho"
        case "Xuất Thành Phẩm":   return "Phiếu xuất kho"
        default:                  return "Chi tiết phiếu"
        }
    }

    private var billPartyHeader: String {
        isExport ? "THÔNG TIN BÊN NHẬN" : "THÔNG TIN BÊN GIAO"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    billContent
                        .padding()

                    // Button In phiếu
                    Button {
                        Task { await shareBill() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSharing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "printer")
                                Text("In phiếu")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.themePrimary)
                        .cornerRadius(12)
                    }
                    .disabled(isSharing)
                    .padding()
                }
            }
            .navigationTitle(billNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bill content (không hiển thị giá)
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

            // Items - KHÔNG hiển thị giá và thành tiền
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Hàng hoá").font(.caption).foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("SL").font(.caption).foregroundStyle(.gray)
                        .frame(width: 80, alignment: .trailing)
                    Text("Đơn vị").font(.caption).foregroundStyle(.gray)
                        .frame(width: 60, alignment: .trailing)
                }
                Divider()
                ForEach(tx.items, id: \.id) { item in
                    let isCai = item.unit?.lowercased() == "cái"
                    let qtyText = isCai ? "\(item.quantity)" : FormatUtils.formatWeight(item.quantity, unit: item.unit)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(qtyText).font(.subheadline)
                            .frame(width: 80, alignment: .trailing)
                        Text(item.unit ?? "kg").font(.subheadline)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Divider()

            // Chữ ký
            Group {
                if isExport {
                    HStack(alignment: .top) {
                        VStack(spacing: 8) {
                            Text("Người giao hàng")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                            Text("Ký và ghi rõ họ tên")
                                .font(.caption).foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 8) {
                            Text("Người nhận hàng")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                            Text("Ký và ghi rõ họ tên")
                                .font(.caption).foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(alignment: .top) {
                        VStack(spacing: 4) {
                            Text("Người giao")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                            Text(tx.creatorName ?? " ")
                                .font(.caption).fontWeight(.bold).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("Người nhận")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.gray)
                            Text(" ").font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Share
    private func shareBill() async {
        isSharing = true
        defer { isSharing = false }
        let renderer = ImageRenderer(content:
            billContent
                .padding(20)
                .background(Color.white)
                .frame(width: 390)
        )
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    // MARK: - Formatters
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }
}
