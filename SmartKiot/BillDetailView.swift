import SwiftUI
import PhotosUI

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
    @State private var receiptPickerItem: PhotosPickerItem? = nil
    @State private var showReceiptPreview = false
    @State private var showEditHistory = false
    @State private var dbEdits: [OrderEdit] = []
    @State private var resolvedCustomerAddress: String? = nil
    @State private var resolvedCustomerPhone: String? = nil
    @State private var orderStatus: String? = nil
    @State private var showOrderStatusPicker = false
    @State private var showCancelConfirmation = false
    
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
                showPaymentInfo: false,
                onComplete: nil,
                customerName: bill.customerName ?? "Khách lẻ",
                customerPhone: resolvedCustomerPhone ?? bill.customerPhone,
                customerAddress: resolvedCustomerAddress ?? bill.customerAddress,
                customerEmail: bill.customerEmail,
                onOpenBankSettings: nil,
                onCaptureReceipt: { showReceiptCamera = true },
                receiptImageURL: receiptImageURLString,
                onPickedReceiptImage: { img in receiptImage = img },
                onEditDiscount: nil,
                sequenceNumber: bill.sequenceNumber,
                customVATRate: bill.vatRate,
                payFullAmount: .constant(bill.paidAmount == nil || bill.paidAmount == bill.total),
                partialAmount: .constant(bill.paidAmount ?? bill.total),
                expectedPayDate: .constant(bill.expectedPayDate),
                note: .constant(bill.note ?? ""),
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
                    
                    if let paidAmount = bill.paidAmount {
                        HStack {
                            Text("Đã trả")
                                .font(.caption).foregroundStyle(.gray)
                            Spacer()
                            if !isPaid {
                                Text(formatCurrency(0))
                                    .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                            } else {
                                Text(formatCurrency(paidAmount))
                                    .font(.caption).fontWeight(.bold).foregroundStyle(.green)
                            }
                        }
                    }
                    
                    if let debtAmount = bill.debtAmount, debtAmount > 0 {
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
                    
                    // Trạng thái thanh toán toggle
                    HStack {
                        Text("Trạng thái thanh toán")
                            .font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Button(action: {
                            isPaid.toggle()
                            var updatedBill = bill
                            updatedBill.isPaid = isPaid
                            Task {
                                do {
                                    try await viewModel.updateOrder(updatedBill)
                                } catch {
                                    print("❌ Error updating payment status: \(error)")
                                    isPaid.toggle()
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isPaid ? .green : .red)
                                Text(isPaid ? "Đã nhận tiền" : "Chưa nhận tiền")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundStyle(isPaid ? .green : .red)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(isPaid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                
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
                        } else if let urlStr = receiptImageURLString, let url = URL(string: urlStr) {
                            Button {
                                showReceiptPreview = true
                            } label: {
                                AsyncImage(url: url) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                    } else {
                                        ZStack {
                                            Color.gray.opacity(0.08)
                                            ProgressView()
                                        }
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            ZStack {
                                Color.gray.opacity(0.08)
                                Image(systemName: "photo")
                                    .foregroundStyle(.gray)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if let _ = receiptImageURLString {
                                Text("Đã lưu ảnh xác nhận")
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
                    HStack {
                        Text("Trạng thái đơn hàng")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themeTextDark)
                        Spacer()
                        let isCancelledOrDeleted = bill.isDeleted || orderStatus == "cancelled"
                        if isCancelledOrDeleted {
                            // Đơn đã huỷ — khoá không cho chỉnh
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(Color.red.opacity(0.5))
                        } else {
                            Button {
                                showOrderStatusPicker = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.themePrimary)
                            }
                        }
                    }
                    
                    let statusInfo = orderStatusInfo(orderStatus)
                    HStack(spacing: 8) {
                        Image(systemName: statusInfo.icon)
                            .foregroundStyle(statusInfo.color)
                        Text(statusInfo.label)
                            .fontWeight(.medium)
                            .foregroundStyle(statusInfo.color)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(statusInfo.color.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Button(action: {
                    // Lưu trạng thái thanh toán + trạng thái đơn hàng hiện tại rồi thoát
                    var updatedBill = bill
                    updatedBill.isPaid = isPaid
                    updatedBill.orderStatus = orderStatus
                    Task {
                        do {
                            try await viewModel.updateOrder(updatedBill)
                        } catch {
                            print("❌ Error saving bill: \(error)")
                        }
                    }
                    dismiss()
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
            orderStatus = bill.orderStatus
            receiptImageURLString = bill.paymentReceiptURL
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
                viewModel.deleteOrder(bill)
                dismiss()
            }
        } message: {
            Text("Bạn có chắc muốn xóa đơn hàng này? Hành động này không thể hoàn tác.")
        }
        .confirmationDialog("Chọn trạng thái đơn hàng", isPresented: $showOrderStatusPicker, titleVisibility: .visible) {
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
        .sheet(isPresented: $showReceiptPreview) {
            NavigationStack {
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()
                    if let urlStr = receiptImageURLString, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ProgressView().tint(.white)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { showReceiptPreview = false }
                            .foregroundStyle(.white)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
                customerPhone: bill.customerPhone,
                customerAddress: resolvedCustomerAddress ?? bill.customerAddress,
                customerEmail: bill.customerEmail,
                onOpenBankSettings: nil,
                onCaptureReceipt: nil,
                receiptImageURL: bill.paymentReceiptURL,
                onPickedReceiptImage: nil,
                onEditDiscount: nil,
                sequenceNumber: bill.sequenceNumber,
                customVATRate: bill.vatRate,
                payFullAmount: .constant(bill.paidAmount == nil || bill.paidAmount == bill.total),
                partialAmount: .constant(bill.paidAmount ?? bill.total),
                expectedPayDate: .constant(bill.expectedPayDate),
                note: .constant(bill.note ?? ""),
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
                List(edits.sorted { $0.createdAt > $1.createdAt }) { e in
                    EditHistoryRow2(edit: e)
                }
                .navigationTitle("Lịch sử chỉnh sửa")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // MARK: - Order Status Helpers

    private func orderStatusInfo(_ status: String?) -> (label: String, icon: String, color: Color) {
        switch status {
        case "preparing":  return ("Chuẩn bị hàng",  "bag.fill",              .purple)
        case "prepared":   return ("Đã soạn hàng",   "shippingbox.fill",      .orange)
        case "delivering": return ("Đang giao hàng", "figure.walk",           Color(red: 0.0, green: 0.6, blue: 1.0))
        case "delivered":  return ("Đã giao hàng",   "bicycle",               Color(red: 0.2, green: 0.6, blue: 1.0))
        case "completed":  return ("Hoàn thành",      "checkmark.seal.fill",  .green)
        case "cancelled":  return ("Đã Huỷ",          "xmark.circle.fill",    .red)
        default:           return ("Chưa cập nhật",   "circle.dotted",        .gray)
        }
    }

    private func updateOrderStatus(_ status: String?) {
        orderStatus = status
        var updatedBill = bill
        updatedBill.orderStatus = status
        if status == "cancelled" {
            // Soft delete + hoàn tồn kho, đồng thời lưu orderStatus = "cancelled" lên DB
            Task {
                do {
                    try await viewModel.updateOrder(updatedBill)
                } catch {
                    print("❌ Error saving cancelled status: \(error)")
                }
            }
            viewModel.deleteOrder(bill) // soft delete + revert inventory
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
