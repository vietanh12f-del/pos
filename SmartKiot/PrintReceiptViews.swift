import SwiftUI
import PhotosUI

// MARK: - CustomPrintOptionsSheet

struct CustomPrintOptionsSheet: View {
    @Binding var options: PrintOptions
    let onPrint: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct OptionRow: View {
        let icon: String
        let title: String
        let subtitle: String
        @Binding var isOn: Bool

        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.themePrimary.opacity(0.12) : Color.gray.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isOn ? Color.themePrimary : .gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isOn ? Color.themeTextDark : .gray)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color.themePrimary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section(header: Text("Chọn nội dung in").textCase(nil).font(.subheadline).foregroundStyle(.gray)) {
                        OptionRow(icon: "building.2.fill",
                                  title: "Thông tin cửa hàng",
                                  subtitle: "Tên, địa chỉ, SĐT cửa hàng",
                                  isOn: $options.showStoreInfo)
                        OptionRow(icon: "person.fill",
                                  title: "Thông tin khách hàng",
                                  subtitle: "Tên KH, STT, ghi chú, địa chỉ",
                                  isOn: $options.showCustomerInfo)
                        OptionRow(icon: "cart.fill",
                                  title: "Thông tin sản phẩm",
                                  subtitle: "Danh sách hàng hoá, số lượng, giá",
                                  isOn: $options.showProducts)
                        OptionRow(icon: "qrcode",
                                  title: "Mã QR thanh toán",
                                  subtitle: "VietQR chuyển khoản ngân hàng",
                                  isOn: $options.showQRCode)
                        OptionRow(icon: "photo.fill",
                                  title: "Ảnh xác nhận thanh toán",
                                  subtitle: "Ảnh chụp biên lai chuyển khoản",
                                  isOn: $options.showReceiptImage)
                        OptionRow(icon: "checkmark.circle.fill",
                                  title: "Trạng thái thanh toán",
                                  subtitle: "Đã nhận tiền / Chưa thanh toán",
                                  isOn: $options.showPaymentStatus)
                        OptionRow(icon: "shippingbox.fill",
                                  title: "Trạng thái đơn hàng",
                                  subtitle: "Chuẩn bị, đang giao, hoàn thành...",
                                  isOn: $options.showOrderStatus)
                    }
                }
                .listStyle(.insetGrouped)

                Button(action: onPrint) {
                    HStack(spacing: 8) {
                        Image(systemName: "printer.fill")
                        Text("In phiếu")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.themePrimary)
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("In phiếu tuỳ chọn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - PrintReceiptView

struct PrintReceiptView: View {
    let opts: PrintOptions
    let items: [OrderItem]
    let dateString: String
    let sequenceNumber: String?
    let customerName: String
    let customerPhone: String?
    let customerAddress: String?
    let customerEmail: String?
    let note: String?
    var orderFees: [OrderFee] = []
    let grandTotal: Double
    let paidAmount: Double?
    let debtAmount: Double?
    let isPaid: Bool
    let payFullAmount: Bool
    let expectedPayDate: Date?
    let vatRate: Double?
    let orderStatus: String?
    let qrImage: UIImage?
    let receiptImage: UIImage?
    var billIndex: Int? = nil
    var totalBills: Int = 1
    var creatorId: String? = nil

    private static let badgePalette: [(bg: Color, fg: Color)] = [
        (Color(red: 0.20, green: 0.60, blue: 1.00), .white),
        (Color(red: 1.00, green: 0.45, blue: 0.30), .white),
        (Color(red: 0.20, green: 0.78, blue: 0.60), .white),
        (Color(red: 0.65, green: 0.35, blue: 0.95), .white),
        (Color(red: 1.00, green: 0.75, blue: 0.10), .black),
        (Color(red: 0.95, green: 0.35, blue: 0.65), .white),
        (Color(red: 0.30, green: 0.75, blue: 0.30), .white),
        (Color(red: 0.20, green: 0.70, blue: 0.85), .white),
    ]

    private func badgeColors() -> (bg: Color, fg: Color) {
        guard let id = creatorId, !id.isEmpty else {
            return (Color.themePrimary, .white)
        }
        let hash = id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let idx = abs(hash) % Self.badgePalette.count
        return Self.badgePalette[idx]
    }

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "vi_VN")
        f.currencySymbol = "₫"
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v)) ₫"
    }

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }

    private func orderStatusDisplayInfo(_ status: String?) -> (label: String, icon: String, color: Color) {
        switch status {
        case "confirmed": return ("Xác nhận đơn", "checkmark.circle.fill", .blue)
        case "preparing":   return ("Chuẩn bị hàng",  "shippingbox",            .orange)
        case "prepared":    return ("Đã soạn hàng",   "checkmark.circle",       .blue)
        case "delivering":  return ("Đang giao hàng", "bicycle",                .purple)
        case "delivered":   return ("Đã giao hàng",   "checkmark.circle.fill",  .green)
        case "cancelled":   return ("Đã huỷ",         "xmark.circle.fill",      .red)
        default:            return ("Mới tạo",        "doc.text",               .gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if opts.showStoreInfo {
                let headerLines = StoreManager.shared.currentStoreReceiptHeaderLines().filter { !$0.isEmpty }
                if !headerLines.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(headerLines, id: \.self) { line in
                            Text(line)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.themeTextDark)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                }
            }

            if opts.showCustomerInfo {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(customerName)
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                            .fixedSize(horizontal: false, vertical: true)
                        if let p = customerPhone, !p.isEmpty {
                            Text("SĐT: \(p)").font(.subheadline).foregroundStyle(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let e = customerEmail, !e.isEmpty {
                            Text("Email: \(e)").font(.subheadline).foregroundStyle(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(dateString).font(.subheadline).foregroundStyle(.gray)
                        if let a = customerAddress, !a.isEmpty {
                            Text("Địa chỉ: \(a)").font(.subheadline).foregroundStyle(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let n = note, !n.isEmpty {
                            Text("Ghi chú: \(n)")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.85))
                                .cornerRadius(8)
                                .padding(.top, 4)
                        }
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        if let stt = sequenceNumber {
                            Text("STT: \(stt)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                                .multilineTextAlignment(.center)
                        }
                        if let idx = billIndex {
                            let colors = badgeColors()
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colors.bg)
                                    .frame(width: 64, height: 64)
                                Text("\(idx)")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(colors.fg)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            Text("mã bill")
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            if opts.showCustomerInfo || opts.showStoreInfo {
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 1)
                    .padding(.bottom, 8)
            }

            if opts.showProducts {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            if let data = item.imageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: item.systemImage ?? "cart.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.themePrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.themePrimary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).fontWeight(.medium).foregroundStyle(Color.themeTextDark)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(item.quantity) x \(fmt(item.price))").font(.subheadline).foregroundStyle(.gray)
                                if item.discount > 0 {
                                    Text("-\(fmt(item.discount))").font(.caption).foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            Text(fmt(item.total)).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.bottom, 8)

                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 1)
                    .padding(.bottom, 8)

                let vatEnabled = StoreManager.shared.currentStoreVATEnabled()
                let rate = vatRate ?? StoreManager.shared.currentStoreVATRate()
                let subtotal = items.reduce(0) { $0 + $1.total }
                let discountVal = max(0, subtotal - items.reduce(0) { $0 + ($1.price * Double($1.quantity)) })
                if vatEnabled {
                    HStack {
                        Text("Tổng tiền hàng").foregroundStyle(.gray)
                        Spacer()
                        Text(fmt(subtotal)).fontWeight(.bold)
                    }.font(.subheadline)
                    HStack {
                        Text("VAT (\(rate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", rate) : String(format: "%.1f", rate))%)").foregroundStyle(.gray)
                        Spacer()
                        Text(fmt(subtotal * rate / 100)).fontWeight(.bold)
                    }.font(.subheadline)
                }
                if discountVal > 0 {
                    HStack {
                        Text("Giảm giá").foregroundStyle(.gray)
                        Spacer()
                        Text("-\(fmt(discountVal))").fontWeight(.bold).foregroundStyle(.red)
                    }.font(.subheadline)
                }
                CustomerOrderFeeRows(fees: orderFees)
                HStack {
                    Text("Tổng cộng").font(.title3).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                    Spacer()
                    Text(fmt(grandTotal)).font(.title3).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                }
                .padding(.bottom, 8)
            }

            if opts.showQRCode, let qr = qrImage {
                VStack(spacing: 4) {
                    Image(uiImage: qr)
                        .resizable().interpolation(.none).scaledToFit()
                        .frame(width: 180, height: 180)
                    Text("Quét mã để thanh toán").font(.caption).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if opts.showReceiptImage, let img = receiptImage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Xác nhận thanh toán").font(.caption).fontWeight(.bold).foregroundStyle(.gray)
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 6)
            }

            if opts.showPaymentStatus {
                HStack {
                    Text("Đã trả").font(.caption).foregroundStyle(.gray)
                    Spacer()
                    if !isPaid {
                        Text("Chưa thanh toán").font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                    } else if payFullAmount {
                        Text(fmt(grandTotal)).font(.caption).fontWeight(.bold).foregroundStyle(.green)
                    } else {
                        Text(fmt(paidAmount ?? grandTotal)).font(.caption).fontWeight(.bold).foregroundStyle(.green)
                    }
                }
                if let debt = debtAmount, debt > 0, !payFullAmount {
                    HStack {
                        Text("Công nợ").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Text(fmt(debt)).font(.caption).fontWeight(.bold).foregroundStyle(.red)
                    }
                }
                if let d = expectedPayDate {
                    HStack {
                        Text("Ngày dự kiến trả").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Text(fmtDate(d)).font(.caption).fontWeight(.bold)
                    }
                }
            }

            if opts.showOrderStatus, let status = orderStatus, !status.isEmpty {
                let info = orderStatusDisplayInfo(status)
                HStack(spacing: 8) {
                    Text("Trạng thái đơn hàng:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: info.icon).font(.caption).foregroundStyle(info.color)
                        Text(info.label).font(.caption).fontWeight(.bold).foregroundStyle(info.color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(info.color.opacity(0.1)))
                }
                .padding(.top, 4)
            }

            HStack {
                Spacer()
                Text("Cảm ơn quý khách!")
                    .font(.caption).italic().foregroundStyle(.gray)
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
    }
}
