import SwiftUI
import PhotosUI
import UIKit

struct BillDetailView: View {
    @ObservedObject private var advances = EmployeeAdvanceStore.shared
    let bill: Bill

    // The sheet's input is a snapshot. Receipt edits are saved into pastOrders,
    // so subsequent saves must start from that updated order.
    private var currentBill: Bill {
        viewModel.pastOrders.first(where: { $0.id == bill.id }) ?? bill
    }

    @ObservedObject var viewModel: OrderViewModel
    var onDeleted: (() -> Void)? = nil   // callback khi đơn bị xoá
    var showEditButton: Bool = true      // Điều khiển hiển thị nút Sửa
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var isPaid: Bool = true
    @State private var localPaidAmount: Double? = nil   // cached cho UI refresh ngay
    @State private var localDebtAmount: Double? = nil   // cached cho UI refresh ngay
    @State private var debtCleared: Bool = false        // true khi user chủ động xoá nợ (đã thanh toán đủ)
    @State private var showReceiptCamera = false
    @State private var receiptImage: UIImage? = nil
    @State private var isUploadingReceipt = false
    @State private var receiptImageURLString: String? = nil
    @State private var receiptPickerItem: PhotosPickerItem? = nil
    @State private var showEditHistory = false
    @State private var dbEdits: [OrderEdit] = []
    @State private var resolvedCustomerAddress: String? = nil
    @State private var resolvedCustomerPhone: String? = nil
    @State private var orderStatus: String? = nil
    @State private var showOrderStatusPicker = false
    @State private var showCancelConfirmation = false
    @State private var showConfirmPaidFull = false      // alert xác nhận xoá công nợ
    @State private var printOptions = PrintOptions()
    @State private var showPrintOptionsSheet = false
    @State private var renderedCustomImages: [UIImage] = []
    @State private var showPaymentStatusPicker = false
    @State private var showCopiedAlert = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Text("Đóng")
                        .font(.headline)
                        .foregroundStyle(Color.gray)
                }
                
                Spacer()

                Button(action: copyBillSummary) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
                }

                if showEditButton {
                    Button(action: {
                        viewModel.startEditing(currentBill)
                        dismiss()
                    }) {
                        Text("Sửa")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.blue)
                    }
                }
            }
            .padding()
            .background(Color.white)
            
            ScrollView {
                BillReceiptView(
                items: bill.items,
                totalAmount: bill.salesRevenue - bill.vatAmount, orderFees: bill.fees,
                dateString: formatDate(bill.createdAt),
                qrURL: generateQRURL(for: bill),
                qrImage: nil,
                billPayload: nil,
                showButtons: false,
                showPaymentInfo: false,
                onComplete: nil,
                customerName: bill.customerName ?? "Khách lẻ",
                customerPhone: resolvedCustomerPhone ?? bill.customerPhone,
                customerAddress: resolvedCustomerAddress ?? bill.customerAddress,
                customerEmail: bill.customerEmail,
                onOpenBankSettings: nil,
                onCaptureReceipt: { showReceiptCamera = true },
                receiptImageURL: receiptImageURLString,
                onRemoveReceiptImage: removeReceiptImage,
                onPickedReceiptImage: { img in receiptImage = img },
                onEditDiscount: nil,
                sequenceNumber: bill.sequenceNumber,
                customVATRate: bill.vatRate,
                payFullAmount: .constant(bill.paidAmount == nil || bill.paidAmount == bill.total),
                partialAmount: .constant(bill.paidAmount ?? bill.total),
                expectedPayDate: .constant(bill.expectedPayDate),
                note: .constant(bill.note ?? ""),
                selectedBillNumber: .constant(bill.billNumber),
                grandTotal: bill.total
            )
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                // Payment information + toggle gộp chung
                VStack(alignment: .leading, spacing: 10) {
                    Text("Thông tin thanh toán")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    
                    HStack {
                        Text("Tổng tiền")
                            .font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Text(formatCurrency(bill.total))
                            .font(.caption).fontWeight(.bold)
                    }
                    
                    if let paidAmount = localPaidAmount ?? bill.paidAmount {
                        HStack {
                            Text("Đã trả")
                                .font(.caption).foregroundStyle(.gray)
                            Spacer()
                            let effectiveDebt: Double? = debtCleared ? nil : (localDebtAmount ?? bill.debtAmount)
                            let status = PaymentStatus.from(isPaid: isPaid, debtAmount: effectiveDebt)
                            if status == .unpaid {
                                Text(formatCurrency(0))
                                    .font(.caption).fontWeight(.bold).foregroundStyle(.gray)
                            } else {
                                Text(formatCurrency(status == .paidFull ? bill.total : paidAmount))
                                    .font(.caption).fontWeight(.bold).foregroundStyle(status.color)
                            }
                        }
                    }
                    
                    let effectiveDebtForDisplay: Double? = debtCleared ? nil : (localDebtAmount ?? bill.debtAmount)
                    if let debtAmount = effectiveDebtForDisplay, debtAmount > 0 {
                        HStack {
                            Text("Công nợ")
                                .font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(debtAmount))
                                .font(.caption).fontWeight(.bold).foregroundStyle(.red)
                        }
                    }
                    
                    if let expectedDate = bill.expectedPayDate {
                        HStack {
                            Text("Ngày dự kiến trả")
                                .font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatDateOnly(expectedDate))
                                .font(.caption).fontWeight(.bold)
                        }
                    }
                    
                    Divider()
                    
                    // Trạng thái thanh toán — 3 trạng thái
                    HStack {
                        Text("Trạng thái thanh toán")
                            .font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Button {
                            showPaymentStatusPicker = true
                        } label: {
                            let status = PaymentStatus.from(isPaid: isPaid, debtAmount: debtCleared ? nil : (localDebtAmount ?? bill.debtAmount))
                            HStack(spacing: 4) {
                                Image(systemName: status.icon)
                                    .foregroundStyle(status.color)
                                Text(status.label)
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundStyle(status.color)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(status.color.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                
                if !currentBill.fees.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chi phí đơn hàng").font(.headline)
                        ForEach(currentBill.fees) { fee in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(fee.name)
                                    Spacer()
                                    Text(formatCurrency(fee.amount))
                                }
                                Text(fee.bearer == "shop" ? "Shop chịu" : fee.funding == "customer" ? "Khách trả trực tiếp" : "Khách chịu — thu hộ")
                                    .font(.caption).foregroundStyle(.secondary)
                                if fee.funding == "employee" {
                                    Text("Ứng trước: \(fee.employeeName ?? "Nhân viên")").font(.caption)
                                    if let advance = advances.advances.first(where: { $0.id == fee.id }) {
                                        Text(advance.settledAt == nil ? "Công ty chưa hoàn ứng" : "Công ty đã hoàn ứng")
                                            .font(.caption).foregroundStyle(advance.settledAt == nil ? .orange : .green)
                                    }
                                }
                            }
                        }
                    }.padding().background(Color.white).cornerRadius(12)
                    .task { await advances.refresh() }
                }
                // Chụp hình chuyển khoản
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chụp hình chuyển khoản")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    
                    HStack(spacing: 12) {
                        // Preview ảnh
                        if isUploadingReceipt {
                            ZStack {
                                Color.gray.opacity(0.08)
                                ProgressView()
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            PaymentReceiptGallery(storedImages: receiptImageURLString, onRemove: removeReceiptImage)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if !PaymentReceiptImages.urls(receiptImageURLString).isEmpty {
                                Text("Đã lưu \(PaymentReceiptImages.urls(receiptImageURLString).count) ảnh xác nhận")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Chưa có ảnh xác nhận")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        showReceiptCamera = true
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                        Text("Chụp")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.themePrimary)
                                
                                PhotosPicker(selection: $receiptPickerItem, matching: .images) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                        Text("Thư viện")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.themePrimary)
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                
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
                
                // Order Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trạng thái đơn hàng")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 14)
                    
                    let statusInfo = orderStatusInfo(orderStatus)
                    let isCancelledOrDeleted = bill.isDeleted || orderStatus == "cancelled"
                    Button {
                        if !isCancelledOrDeleted {
                            showOrderStatusPicker = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: statusInfo.icon)
                                .foregroundStyle(statusInfo.color)
                            Text(statusInfo.label)
                                .fontWeight(.medium)
                                .foregroundStyle(statusInfo.color)
                            Spacer()
                            if !isCancelledOrDeleted {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.gray.opacity(0.6))
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.red.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(statusInfo.color.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCancelledOrDeleted)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Button(action: {
                    // Lưu trạng thái thanh toán + trạng thái đơn hàng hiện tại rồi thoát
                    var updatedBill = currentBill
                    updatedBill.isPaid = isPaid
                    updatedBill.orderStatus = orderStatus
                    // Dùng local state (đã cập nhật khi user chọn từ dialog) để tránh mất công nợ
                    let currentDebt = debtCleared ? nil : (localDebtAmount ?? bill.debtAmount)
                    let currentPaid = localPaidAmount ?? bill.paidAmount
                    if !isPaid {
                        updatedBill.paidAmount = 0
                        updatedBill.debtAmount = bill.total
                    } else if (currentDebt ?? 0) <= 0 {
                        updatedBill.paidAmount = bill.total
                        updatedBill.debtAmount = nil
                    } else {
                        updatedBill.paidAmount = currentPaid
                        updatedBill.debtAmount = currentDebt
                    }
                    // Optimistic update pastOrders ngay trước dismiss để list refresh đúng
                    viewModel.applyLocalUpdate(updatedBill)
                    dismiss()
                    // Async DB update sau khi đã dismiss
                    Task { try? await viewModel.updateOrder(updatedBill) }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Lưu và thoát")
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.themePrimary)
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
                    showPrintOptionsSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline)
                        Text("In bill tuỳ chọn")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
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
            localPaidAmount = bill.paidAmount
            localDebtAmount = bill.debtAmount
            orderStatus = bill.orderStatus
            receiptImageURLString = currentBill.paymentReceiptURL
            Task {
                // Resolve customer address và phone từ TradingParty nếu không có trên bill
                let db = SupabaseDatabaseService()
                let buyers = (try? await db.fetchTradingParties(type: "buyer")) ?? []
                let billPhone = bill.customerPhone ?? ""
                let billName = (bill.customerName ?? "").lowercased()
                let match = buyers.first { party in
                    let phoneMatch = !billPhone.isEmpty && party.phone == billPhone
                    let nameMatch = !billName.isEmpty && party.name.lowercased() == billName
                    return phoneMatch || nameMatch
                }

                if let address = bill.customerAddress, !address.isEmpty {
                    resolvedCustomerAddress = address
                } else if let addr = match?.address, !addr.isEmpty {
                    resolvedCustomerAddress = addr
                }

                if !billPhone.isEmpty {
                    resolvedCustomerPhone = billPhone
                } else if let phone = match?.phone, !phone.isEmpty {
                    resolvedCustomerPhone = phone
                }
                
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
                viewModel.deleteOrder(currentBill)
                onDeleted?()
                dismiss()
            }
        } message: {
            Text("Bạn có chắc muốn xóa đơn hàng này? Hành động này không thể hoàn tác.")
        }
        .alert("Đã copy đơn hàng", isPresented: $showCopiedAlert) {
            Button("Đã hiểu", role: .cancel) { }
        } message: {
            Text("Bạn có thể dán nội dung vào Zalo, tin nhắn hoặc ghi chú.")
        }
        .confirmationDialog("Chọn trạng thái thanh toán", isPresented: $showPaymentStatusPicker, titleVisibility: .visible) {
            Button("✅ Đã thanh toán đủ") {
                let hasDebt = !debtCleared && (localDebtAmount ?? bill.effectiveDebt) > 0
                if hasDebt {
                    // Có công nợ → hỏi xác nhận trước
                    showConfirmPaidFull = true
                } else {
                    applyPaidFull()
                }
            }
            Button("🔶 Đã thanh toán 1 phần") {
                isPaid = true
                debtCleared = false
                var updatedBill = currentBill
                updatedBill.isPaid = true
                if (bill.debtAmount ?? 0) <= 0 {
                    localPaidAmount = 0
                    localDebtAmount = bill.total
                    updatedBill.paidAmount = 0
                    updatedBill.debtAmount = bill.total
                }
                viewModel.applyLocalUpdate(updatedBill)
                viewModel.addQuickEditHistory(original: bill, updated: updatedBill)
                Task { try? await viewModel.updateOrder(updatedBill) }
            }
            Button("⭕ Chưa thanh toán") {
                isPaid = false
                debtCleared = false
                localPaidAmount = 0
                localDebtAmount = bill.total
                var updatedBill = currentBill
                updatedBill.isPaid = false
                updatedBill.paidAmount = 0
                updatedBill.debtAmount = bill.total
                viewModel.applyLocalUpdate(updatedBill)
                viewModel.addQuickEditHistory(original: bill, updated: updatedBill)
                Task { try? await viewModel.updateOrder(updatedBill) }
            }
            Button("Hủy", role: .cancel) { }
        }
        .alert("Xác nhận thanh toán đủ?", isPresented: $showConfirmPaidFull) {
            Button("Hủy", role: .cancel) { }
            Button("Xác nhận", role: .destructive) {
                applyPaidFull()
            }
        } message: {
            let debt = localDebtAmount ?? bill.effectiveDebt
            Text("Xác nhận đã nhận đủ tiền và xoá công nợ \(formatCurrency(debt))?")
        }
        .confirmationDialog("Chọn trạng thái đơn hàng", isPresented: $showOrderStatusPicker, titleVisibility: .visible) {
            Button("☑️ Xác nhận đơn") { updateOrderStatus("confirmed") }
            Button("🛍️ Chuẩn bị hàng")  { updateOrderStatus("preparing") }
            Button("📦 Đã soạn hàng")    { updateOrderStatus("prepared") }
            Button("🚴 Đang giao hàng")  { updateOrderStatus("delivering") }
            Button("✅ Đã giao hàng")    { updateOrderStatus("delivered") }
            Button("🎉 Hoàn thành")      { updateOrderStatus("completed") }
            Button("❌ Đã Huỷ", role: .destructive) { showCancelConfirmation = true }
            Button("⭕ Bỏ chọn")         { updateOrderStatus(nil) }
            Button("Hủy", role: .cancel) { }
        }
        .alert("Huỷ đơn hàng?", isPresented: $showCancelConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Xác nhận huỷ", role: .destructive) {
                updateOrderStatus("cancelled")
            }
        } message: {
            let itemList = bill.items.map { "• \($0.name): +\($0.quantity)" }.joined(separator: "\n")
            Text("Đơn sẽ bị xoá và lưu vào lịch sử xoá. Số lượng sản phẩm sẽ được hoàn lại:\n\n\(itemList)")
        }
        .sheet(isPresented: $showShareSheet) {
            if !renderedCustomImages.isEmpty {
                ShareSheet(items: renderedCustomImages)
            } else if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showPrintOptionsSheet) {
            CustomPrintOptionsSheet(options: $printOptions) {
                showPrintOptionsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    Task { await renderImageWithOptions() }
                }
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
                        var updated = currentBill
                        updated.paymentReceiptURL = PaymentReceiptImages.appending(url, to: receiptImageURLString)
                        try await viewModel.updateOrder(updated)
                        await MainActor.run {
                            receiptImageURLString = updated.paymentReceiptURL
                        }
                    } catch {
                        print("❌ Error uploading receipt: \(error)")
                    }
                }
            }
        }
        .onChange(of: receiptPickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    receiptImage = img
                    receiptPickerItem = nil
                }
            }
        }
    }
    
    @MainActor
    private func removeReceiptImage(_ url: String) async throws {
        let original = viewModel.pastOrders.first(where: { $0.id == bill.id }) ?? bill
        var updated = original
        updated.paymentReceiptURL = PaymentReceiptImages.removing(url, from: receiptImageURLString)
        do {
            try await viewModel.updateOrder(updated)
            receiptImageURLString = updated.paymentReceiptURL
        } catch {
            viewModel.applyLocalUpdate(original)
            throw error
        }
    }

    private func copyBillSummary() {
        UIPasteboard.general.string = billSummaryText()
        showCopiedAlert = true
    }

    private func billSummaryText() -> String {
        let target = currentBill
        let customerName = target.customerName ?? "Khách lẻ"
        let customerPhone = resolvedCustomerPhone ?? target.customerPhone
        let customerAddress = resolvedCustomerAddress ?? target.customerAddress
        let itemLines = target.items.map {
            "- \($0.name): \($0.quantity) x \(formatCurrency($0.price)) = \(formatCurrency($0.total))"
        }.joined(separator: "\n")

        var lines: [String] = [customerName]
        if let phone = customerPhone, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("SĐT: \(phone)")
        }
        if let address = customerAddress, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Địa chỉ: \(address)")
        }
        if let sequence = target.sequenceNumber, !sequence.isEmpty {
            lines.append("STT: \(sequence)")
        }
        if let billNumber = target.billNumber {
            lines.append("Mã bill: \(billNumber)")
        }

        lines.append("")
        lines.append("Đơn hàng:")
        lines.append(itemLines)
        lines.append("")
        lines.append("Tổng cộng: \(formatCurrency(target.total))")

        let effectiveDebt = debtCleared ? 0 : (localDebtAmount ?? target.debtAmount ?? target.effectiveDebt)
        if effectiveDebt > 0 {
            lines.append("Công nợ: \(formatCurrency(effectiveDebt))")
        }

        return lines.joined(separator: "\n")
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
                totalAmount: bill.salesRevenue - bill.vatAmount, orderFees: bill.fees,
                dateString: formatDate(bill.createdAt),
                qrURL: qrURL,
                qrImage: loadedQR,
                billPayload: nil,
                showButtons: false,
                onComplete: nil,
                customerName: bill.customerName ?? "Khách lẻ",
                customerPhone: bill.customerPhone,
                customerAddress: resolvedCustomerAddress ?? bill.customerAddress,
                customerEmail: bill.customerEmail,
                onOpenBankSettings: nil,
                onCaptureReceipt: nil,
                receiptImageURL: receiptImageURLString,
                onPickedReceiptImage: nil,
                onEditDiscount: nil,
                sequenceNumber: bill.sequenceNumber,
                customVATRate: bill.vatRate,
                payFullAmount: .constant(bill.paidAmount == nil || bill.paidAmount == bill.total),
                partialAmount: .constant(bill.paidAmount ?? bill.total),
                expectedPayDate: .constant(bill.expectedPayDate),
                note: .constant(bill.note ?? ""),
                selectedBillNumber: .constant(bill.billNumber),
                grandTotal: bill.total,
                initialIsPaid: isPaid
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

    @MainActor
    private func renderImageWithOptions() async {
        let opts = printOptions

        // Load QR nếu cần
        var loadedQR: UIImage? = nil
        if opts.showQRCode, let url = generateQRURL(for: bill),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            loadedQR = UIImage(data: data)
        }

        // Load receipt image nếu cần
        var loadedReceiptImage: UIImage? = nil
        if opts.showReceiptImage,
           let urlStr = PaymentReceiptImages.urls(receiptImageURLString).last,
           let url = URL(string: urlStr),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            loadedReceiptImage = UIImage(data: data)
        }

        let renderView = PrintReceiptView(
            opts: opts,
            items: bill.items,
            dateString: formatDate(bill.createdAt),
            sequenceNumber: bill.sequenceNumber,
            customerName: bill.customerName ?? "Khách lẻ",
            customerPhone: bill.customerPhone,
            customerAddress: resolvedCustomerAddress ?? bill.customerAddress,
            customerEmail: bill.customerEmail,
            note: bill.note,
            orderFees: currentBill.fees,
                grandTotal: bill.total,
            paidAmount: isPaid ? (localPaidAmount ?? bill.paidAmount ?? bill.total) : 0,
            debtAmount: localDebtAmount ?? bill.debtAmount,
            isPaid: isPaid,
            payFullAmount: (localPaidAmount ?? bill.paidAmount) == nil || (localPaidAmount ?? bill.paidAmount) == bill.total,
            expectedPayDate: bill.expectedPayDate,
            vatRate: bill.vatRate,
            orderStatus: orderStatus ?? bill.orderStatus,
            qrImage: loadedQR,
            receiptImage: loadedReceiptImage,
            billIndex: bill.billNumber,
            totalBills: 1,
            creatorId: bill.creatorId?.uuidString
        )
        .frame(width: 375)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }

        renderedCustomImages = [image]
        renderedImage = nil
        showShareSheet = true
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
        private func formatCurrency(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.currencySymbol = "₫"
            return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
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
            VStack(alignment: .leading, spacing: 0) {
                // Header: thời gian + người sửa
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(format(edit.createdAt))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        if let name = edit.editorName, !name.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(name)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    // Hiển thị thay đổi tổng tiền nếu có
                    if Int(edit.oldTotal) != Int(edit.newTotal) {
                        HStack(spacing: 4) {
                            Text(formatCurrency(edit.oldTotal))
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatCurrency(edit.newTotal))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        .font(.caption)
                    }
                }
                .padding(.bottom, 8)

                // Chi tiết thay đổi
                if let details = edit.details, !details.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(details, id: \.self) { line in
                            detailRow(for: line)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }

        @ViewBuilder
        private func detailRow(for line: String) -> some View {
            let (icon, color) = iconAndColor(for: line)
            HStack(alignment: .top, spacing: 6) {
                Text(icon)
                    .font(.caption)
                    .frame(width: 18)
                Text(cleanedLine(line))
                    .font(.caption)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        /// Trả về (icon, color) dựa theo emoji prefix của dòng detail
        private func iconAndColor(for line: String) -> (String, Color) {
            if line.hasPrefix("💳") { return ("💳", .blue) }
            if line.hasPrefix("✅") { return ("✅", .green) }
            if line.hasPrefix("🔴") { return ("🔴", .red) }
            if line.hasPrefix("📦") { return ("📦", .orange) }
            if line.hasPrefix("💰") { return ("💰", Color.themePrimary) }
            if line.hasPrefix("📅") { return ("📅", .purple) }
            if line.hasPrefix("👤") { return ("👤", .gray) }
            if line.hasPrefix("📝") { return ("📝", .gray) }
            if line.hasPrefix("🖼️") { return ("🖼️", .gray) }
            if line.hasPrefix("➕") { return ("➕", .green) }
            if line.hasPrefix("➖") { return ("➖", .red) }
            if line.hasPrefix("✏️") { return ("✏️", Color.themePrimary) }
            return ("•", .primary)
        }

        /// Bỏ emoji prefix ở đầu dòng (đã hiển thị qua icon riêng)
        private func cleanedLine(_ line: String) -> String {
            let prefixes = ["💳 ", "✅ ", "🔴 ", "📦 ", "💰 ", "📅 ", "👤 ", "📝 ", "🖼️ ", "➕ ", "➖ ", "✏️ "]
            for p in prefixes {
                if line.hasPrefix(p) { return String(line.dropFirst(p.count)) }
            }
            return line
        }

        private func format(_ date: Date) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "dd/MM/yyyy HH:mm"
            return f.string(from: date)
        }

        private func formatCurrency(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.currencySymbol = "₫"
            return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
        }
    }

    struct EditHistorySheet2: View {
        let edits: [OrderEdit]
        var body: some View {
            NavigationStack {
                List {
                    ForEach(edits.sorted { $0.createdAt > $1.createdAt }) { e in
                        EditHistoryRow2(edit: e)
                            .listRowBackground(Color(.systemBackground))
                            .listRowSeparatorTint(Color(.systemGray5))
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Lịch sử chỉnh sửa")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // MARK: - Order Status Helpers

    private func orderStatusInfo(_ status: String?) -> (label: String, icon: String, color: Color) {
        switch status {
        case "confirmed": return ("Xác nhận đơn", "checkmark.circle.fill", .blue)
        case "preparing":  return ("Chuẩn bị hàng",  "bag.fill",              .purple)
        case "prepared":   return ("Đã soạn hàng",   "shippingbox.fill",      .orange)
        case "delivering": return ("Đang giao hàng", "figure.walk",           Color(red: 0.0, green: 0.6, blue: 1.0))
        case "delivered":  return ("Đã giao hàng",   "bicycle",               Color(red: 0.2, green: 0.6, blue: 1.0))
        case "completed":  return ("Hoàn thành",      "checkmark.seal.fill",  .green)
        case "cancelled":  return ("Đã Huỷ",          "xmark.circle.fill",    .red)
        default:           return ("Chưa cập nhật",   "circle.dotted",        .gray)
        }
    }

    private func applyPaidFull() {
        isPaid = true
        debtCleared = true
        localPaidAmount = bill.total
        localDebtAmount = nil
        var updatedBill = currentBill
        updatedBill.isPaid = true
        updatedBill.paidAmount = bill.total
        updatedBill.debtAmount = nil
        viewModel.applyLocalUpdate(updatedBill)
        viewModel.addQuickEditHistory(original: bill, updated: updatedBill)
        Task { try? await viewModel.updateOrder(updatedBill) }
    }

    private func updateOrderStatus(_ status: String?) {
        orderStatus = status
        var updatedBill = currentBill
        updatedBill.orderStatus = status
        viewModel.applyLocalUpdate(updatedBill)
        viewModel.addQuickEditHistory(original: bill, updated: updatedBill)
        if status == "cancelled" {
            // Soft delete + hoàn tồn kho, đồng thời lưu orderStatus = "cancelled" lên DB
            Task {
                do {
                    try await viewModel.updateOrder(updatedBill)
                } catch {
                    print("❌ Error saving cancelled status: \(error)")
                }
            }
            viewModel.deleteOrder(currentBill) // soft delete + revert inventory
        } else {
            Task {
                do {
                    try await viewModel.updateOrder(updatedBill)
                } catch {
                    print("❌ Error updating order status: \(error)")
                    orderStatus = bill.orderStatus // rollback
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.currencySymbol = "₫"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
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
        let amount = Int(bill.vietQRCollectAmount)
        let base = "https://img.vietqr.io/image/\(bankName)-\(finalBankAccount)-compact.png"
        let shortId = bill.id.uuidString.prefix(8)
        let infoBase = "SmartKiot \(shortId)"
        let allowed = CharacterSet.urlQueryAllowed
        let encodedInfo = infoBase.addingPercentEncoding(withAllowedCharacters: allowed) ?? "KNOTE"
        let urlString = "\(base)?amount=\(amount)&addInfo=\(encodedInfo)"
        return URL(string: urlString)
    }
}
