import SwiftUI

// MARK: - Buyer Info Model

struct BuyerInfo: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var phone: String = ""
    var address: String = ""
    var totalDebt: Double = 0
}

// MARK: - BuyerHistoryStore (legacy UserDefaults - kept for migration)

class BuyerHistoryStore {
    static let shared = BuyerHistoryStore()
    private let key = "buyer_history_v1"

    func load() -> [BuyerInfo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([BuyerInfo].self, from: data) else { return [] }
        return list
    }

    func save(_ list: [BuyerInfo]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func upsert(_ buyer: BuyerInfo) {
        var list = load()
        if let idx = list.firstIndex(where: {
            $0.name.lowercased() == buyer.name.lowercased() && $0.phone == buyer.phone
        }) {
            list[idx] = buyer
        } else {
            list.insert(buyer, at: 0)
        }
        save(Array(list.prefix(50)))
    }
}

// MARK: - Main View

struct FinishedGoodsExportView: View {
    @ObservedObject var viewModel: OrderViewModel
    let items: [RestockItem]
    let isImport: Bool          // true = nhập nguyên liệu, false = xuất thành phẩm
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Derived labels
    private var partyLabel: String { isImport ? "Thông tin bên nhập" : "Thông tin bên mua" }
    private var partyNameLabel: String { isImport ? "Tên cơ sở cung cấp" : "Tên người mua / Công ty" }
    private var itemsSectionLabel: String { isImport ? "Nguyên liệu nhập" : "Thành phẩm xuất" }
    private var debtLabel: String { isImport ? "Thiếu nợ còn lại" : "Công nợ còn lại" }
    private var printButtonLabel: String { isImport ? "In bill nhập" : "In bill xuất" }
    private var navTitle: String { isImport ? "Thông tin nhập" : "Thông tin xuất" }
    private var billTitle: String { isImport ? "PHIẾU NHẬP NGUYÊN LIỆU" : "PHIẾU XUẤT THÀNH PHẨM" }
    private var billNavTitle: String { isImport ? "Bill nhập nguyên liệu" : "Bill xuất thành phẩm" }
    private var billPartyHeader: String { isImport ? "THÔNG TIN CƠ SỞ CUNG CẤP" : "THÔNG TIN BÊN MUA" }
    private var partyType: String { isImport ? "supplier" : "buyer" }
    private var validationNameLabel: String { isImport ? "Tên cơ sở cung cấp" : "Tên người mua" }

    // Store info
    private var receiptLines: [String] { StoreManager.shared.currentStoreReceiptHeaderLines() }
    private var vatEnabled: Bool { StoreManager.shared.currentStoreVATEnabled() }
    private var vatRate: Double { StoreManager.shared.currentStoreVATRate() }

    // Buyer
    @State private var buyerName: String = ""
    @State private var buyerPhone: String = ""
    @State private var buyerAddress: String = ""
    @State private var buyerHistory: [TradingParty] = []
    @State private var showBuyerPicker = false
    @State private var pastDebt: Double = 0

    // Payment
    @State private var payFullAmount: Bool = true
    @State private var partialAmountText: String = ""
    @State private var expectedPayDate: Date? = nil
    @State private var showDatePicker = false
    @State private var paymentReceiptImage: UIImage? = nil
    @State private var paymentReceiptURL: String? = nil
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var isUploadingReceipt = false

    // QR
    @State private var loadedQRImage: UIImage? = nil
    @State private var isLoadingQR = false

    // UI state
    @State private var isConfirming = false
    @State private var showPrintSheet = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showConfirmAlert = false
    @State private var isPaid = false

    // Computed totals
    private var subtotal: Double {
        items.reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) + $1.additionalCost }
    }
    private var vatAmount: Double { vatEnabled ? subtotal * (vatRate / 100.0) : 0 }
    private var grandTotal: Double { subtotal + vatAmount }
    private var paidAmount: Double {
        if payFullAmount { return grandTotal }
        return Double(partialAmountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var debtAmount: Double { max(0, grandTotal - paidAmount) }

    private var qrURL: URL? {
        guard grandTotal > 0,
              let bankName = StoreManager.shared.currentStore?.bankName, !bankName.isEmpty,
              let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber, !bankAccount.isEmpty
        else { return nil }
        var code = bankName
        if let range = code.range(of: "\\((.*?)\\)", options: .regularExpression) {
            code = String(code[range].dropFirst().dropLast())
        }
        let amount = Int(paidAmount)
        let info = "XuatTP \(buyerName.prefix(10))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "XuatTP"
        return URL(string: "https://img.vietqr.io/image/\(code)-\(bankAccount)-compact.png?amount=\(amount)&addInfo=\(info)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    storeHeaderSection
                    creatorSection
                    buyerSection
                    itemsSummarySection
                    paymentSection
                    qrSection
                    actionButtons
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .onAppear {
            Task { await loadPartyHistory() }
            loadQRImage()
        }
        .onChange(of: paidAmount) { _, _ in loadQRImage() }
        .onChange(of: buyerName) { _, _ in updatePastDebt() }
        .onChange(of: buyerPhone) { _, _ in updatePastDebt() }
        .sheet(isPresented: $showBuyerPicker) {
            BuyerPickerSheet(buyers: buyerHistory) { selected in
                buyerName = selected.name
                buyerPhone = selected.phone
                buyerAddress = selected.address
                pastDebt = selected.totalDebt
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Ngày dự kiến trả", selection: Binding(
                        get: { expectedPayDate ?? Date() },
                        set: { expectedPayDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle("Ngày dự kiến trả")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { showDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Xong") { showDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showReceiptCamera, onDismiss: uploadReceiptIfNeeded) {
            ImagePicker(image: $paymentReceiptImage, sourceType: .camera).ignoresSafeArea()
        }
        .sheet(isPresented: $showReceiptLibrary, onDismiss: uploadReceiptIfNeeded) {
            ImagePicker(image: $paymentReceiptImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showPrintSheet) {
            ExportBillPrintView(
                receiptLines: receiptLines,
                creatorName: AuthManager.shared.currentUserProfile?.fullName ?? "",
                date: Date(),
                buyerName: buyerName,
                buyerPhone: buyerPhone,
                buyerAddress: buyerAddress,
                items: items,
                subtotal: subtotal,
                vatEnabled: vatEnabled,
                vatRate: vatRate,
                vatAmount: vatAmount,
                grandTotal: grandTotal,
                paidAmount: paidAmount,
                debtAmount: debtAmount,
                expectedPayDate: expectedPayDate,
                qrURL: isImport ? nil : qrURL,
                billTitle: billTitle,
                debtLabel: debtLabel,
                billNavTitle: billNavTitle,
                billPartyHeader: billPartyHeader
            )
        }
        .alert("Thiếu thông tin", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .alert(isImport ? "Xác nhận nhập nguyên liệu?" : "Xác nhận xuất thành phẩm?", isPresented: $showConfirmAlert) {
            Button("Huỷ", role: .cancel) { }
            Button("Xác nhận") {
                Task { await confirmExport() }
            }
        } message: {
            Text(isImport ? "Hệ thống sẽ cộng kho và lưu lịch sử nhập." : "Hệ thống sẽ trừ kho và lưu lịch sử xuất.")
        }
    }

    // MARK: - Sections

    private var storeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(receiptLines.enumerated()), id: \.offset) { _, line in
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                }
            }
            if receiptLines.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                Text(StoreManager.shared.currentStore?.name ?? "Cửa hàng")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var creatorSection: some View {
        HStack(spacing: 12) {
            Label(AuthManager.shared.currentUserProfile?.fullName ?? "Nhân viên", systemImage: "person.fill")
                .font(.subheadline)
                .foregroundStyle(.gray)
            Spacer()
            Label(formatDateTime(Date()), systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var buyerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(partyLabel)
                    .font(.headline)
                Spacer()
                if !buyerHistory.isEmpty {
                    Button {
                        showBuyerPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Lịch sử")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.themePrimary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(partyNameLabel)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(width: 140, alignment: .leading)
                    TextField("Nhập tên...", text: $buyerName)
                        .font(.subheadline)
                }
                Divider()
                HStack {
                    Text("Số điện thoại")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(width: 140, alignment: .leading)
                    TextField("Nhập SĐT...", text: $buyerPhone)
                        .font(.subheadline)
                        .keyboardType(.phonePad)
                }
                Divider()
                HStack {
                    Text("Địa chỉ")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(width: 140, alignment: .leading)
                    TextField("Nhập địa chỉ...", text: $buyerAddress)
                        .font(.subheadline)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))

            if pastDebt > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Công nợ cũ: \(formatCurrency(pastDebt))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var itemsSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(itemsSectionLabel)
                .font(.headline)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                        Text(FormatUtils.formatWeight(item.quantity))
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Text(formatCurrency(Double(item.quantity) / 1000.0 * item.unitPrice))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Divider()
            }

            if vatEnabled {
                HStack {
                    Text("Tổng tiền hàng")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(formatCurrency(subtotal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("VAT (\(Int(vatRate))%)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(formatCurrency(vatAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            HStack {
                Text("Tổng cộng")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(grandTotal))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thanh toán")
                .font(.headline)

            // Payment option
            HStack(spacing: 12) {
                Button {
                    payFullAmount = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: payFullAmount ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(payFullAmount ? Color.themePrimary : .gray)
                        Text("100%")
                            .font(.subheadline)
                            .fontWeight(payFullAmount ? .bold : .regular)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(payFullAmount ? Color.themePrimary.opacity(0.12) : Color.gray.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    payFullAmount = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: !payFullAmount ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(!payFullAmount ? Color.themePrimary : .gray)
                        Text("Trả một phần")
                            .font(.subheadline)
                            .fontWeight(!payFullAmount ? .bold : .regular)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(!payFullAmount ? Color.themePrimary.opacity(0.12) : Color.gray.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            if !payFullAmount {
                HStack {
                    Text("Số tiền trả:")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    TextField("0", text: $partialAmountText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("đ")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))

                if debtAmount > 0 {
                    HStack {
                        Text(debtLabel)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatCurrency(debtAmount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }

                    // Expected pay date
                    HStack {
                        Text("Dự kiến trả hết:")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        Spacer()
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(expectedPayDate == nil ? "Chưa xác định" : formatDateOnly(expectedPayDate!))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(expectedPayDate == nil ? .gray : Color.themePrimary)
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(expectedPayDate == nil ? .gray : Color.themePrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.gray.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Receipt image
            VStack(alignment: .leading, spacing: 8) {
                Text("Chứng từ chuyển khoản")
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                HStack(spacing: 12) {
                    if let img = paymentReceiptImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let urlStr = paymentReceiptURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if isUploadingReceipt {
                        ProgressView()
                    } else {
                        Button("Chụp ảnh") {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showReceiptCamera = true
                            } else {
                                showReceiptLibrary = true
                            }
                        }
                        .font(.subheadline)
                        Button("Thư viện") { showReceiptLibrary = true }
                            .font(.subheadline)
                        if paymentReceiptURL != nil || paymentReceiptImage != nil {
                            Button("Xoá") {
                                paymentReceiptImage = nil
                                paymentReceiptURL = nil
                            }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    private var qrSection: some View {
        VStack(spacing: 12) {
            if !isImport, let url = qrURL {
                Text("Quét mã QR để thanh toán")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                if isLoadingQR {
                    ProgressView()
                        .frame(width: 180, height: 180)
                } else if let img = loadedQRImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .cornerRadius(12)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: 180, height: 180)
                                .cornerRadius(12)
                        case .empty:
                            ProgressView().frame(width: 180, height: 180)
                        default:
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                                .frame(width: 180, height: 180)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isImport ? 0 : 12)
        .background(Group {
            if isImport {
                Color.clear
            } else {
                RoundedRectangle(cornerRadius: 14).fill(Color.white)
            }
        })
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Print bill
            Button {
                if let msg = validate() {
                    validationMessage = msg
                    showValidationAlert = true
                    return
                }
                showPrintSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "printer.fill")
                    Text(printButtonLabel)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.12))
                .foregroundStyle(Color.themeTextDark)
                .cornerRadius(16)
            }

            // Payment status toggle
            HStack {
                Text("Trạng thái thanh toán")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
                Button {
                    isPaid.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPaid ? "checkmark.circle.fill" : "clock.fill")
                            .foregroundStyle(isPaid ? .green : .orange)
                        Text(isPaid ? "Đã thanh toán" : "Chưa thanh toán")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isPaid ? .green : .orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(isPaid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

            // Confirm
            Button {
                if let msg = validate() {
                    validationMessage = msg
                    showValidationAlert = true
                    return
                }
                showConfirmAlert = true
            } label: {
                HStack(spacing: 8) {
                    if isConfirming { ProgressView().tint(.white) }
                    Text("Xác nhận")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(
                    colors: [Color.purple, Color.purple.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .foregroundStyle(.white)
                .cornerRadius(16)
            }
            .disabled(isConfirming)
        }
    }

    // MARK: - Helpers

    private func validate() -> String? {
        let name = buyerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = buyerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = buyerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        var missing: [String] = []
        if name.isEmpty { missing.append(validationNameLabel) }
        if phone.isEmpty { missing.append("Số điện thoại") }
        if address.isEmpty { missing.append("Địa chỉ") }
        if missing.isEmpty { return nil }
        return "Vui lòng điền: " + missing.joined(separator: ", ")
    }

    private func loadPartyHistory() async {
        do {
            buyerHistory = try await viewModel.databaseService.fetchTradingParties(type: partyType)
        } catch {
            // Fallback to legacy UserDefaults
            let legacy = BuyerHistoryStore.shared.load()
            buyerHistory = legacy.map {
                TradingParty(id: $0.id, partyType: partyType, name: $0.name, phone: $0.phone, address: $0.address, totalDebt: $0.totalDebt)
            }
        }
    }

    private func updatePastDebt() {
        let name = buyerName.lowercased()
        let phone = buyerPhone
        if let found = buyerHistory.first(where: {
            $0.name.lowercased() == name && $0.phone == phone
        }) {
            pastDebt = found.totalDebt
        } else {
            pastDebt = 0
        }
    }

    private func loadQRImage() {
        guard let url = qrURL else { loadedQRImage = nil; return }
        isLoadingQR = true
        Task {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                await MainActor.run {
                    loadedQRImage = img
                    isLoadingQR = false
                }
            } else {
                await MainActor.run { isLoadingQR = false }
            }
        }
    }

    private func uploadReceiptIfNeeded() {
        guard let img = paymentReceiptImage, paymentReceiptURL == nil else { return }
        guard let data = img.jpegData(compressionQuality: 0.85) else { return }
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let fileName = "\(UUID().uuidString)"
        isUploadingReceipt = true
        Task {
            do {
                let url = try await StorageManager.shared.uploadRestockDocumentImage(data: data, fileName: fileName, storeId: storeId)
                await MainActor.run {
                    paymentReceiptURL = url
                    isUploadingReceipt = false
                }
            } catch {
                await MainActor.run { isUploadingReceipt = false }
            }
        }
    }

    private func confirmExport() async {
        isConfirming = true
        defer { isConfirming = false }

        // Save party to DB
        let party = TradingParty(
            id: buyerHistory.first(where: {
                $0.name.lowercased() == buyerName.lowercased() && $0.phone == buyerPhone
            })?.id ?? UUID(),
            partyType: partyType,
            name: buyerName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: buyerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            address: buyerAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            totalDebt: debtAmount,
            updatedAt: Date()
        )
        Task {
            try? await viewModel.databaseService.upsertTradingParty(party)
        }

        // Build note
        let note = "\(isImport ? "Cơ sở cung cấp" : "Bên mua"): \(party.name) | SĐT: \(party.phone) | ĐC: \(party.address) | Thanh toán: \(formatCurrency(paidAmount)) | \(debtLabel): \(formatCurrency(debtAmount))"

        viewModel.pendingExportNote = note
        viewModel.pendingExportPaymentReceiptURL = paymentReceiptURL
        viewModel.pendingExportInfo = OrderViewModel.PendingExportInfo(
            buyerName: party.name,
            buyerPhone: party.phone,
            buyerAddress: party.address,
            grandTotal: grandTotal,
            paidAmount: paidAmount,
            debtAmount: debtAmount,
            vatRate: vatRate,
            vatAmount: vatAmount,
            isPaid: isPaid,
            expectedPayDate: expectedPayDate,
            paymentReceiptURL: paymentReceiptURL
        )
        onConfirm()
        dismiss()
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Buyer Picker Sheet

struct BuyerPickerSheet: View {
    let buyers: [TradingParty]
    let onSelect: (TradingParty) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { buyer in
                    Button {
                        onSelect(buyer)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(buyer.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                            HStack(spacing: 8) {
                                if !buyer.phone.isEmpty {
                                    Label(buyer.phone, systemImage: "phone.fill")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                if buyer.totalDebt > 0 {
                                    Label(formatCurrency(buyer.totalDebt), systemImage: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            if !buyer.address.isEmpty {
                                Text(buyer.address)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Tìm...")
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    private var filtered: [TradingParty] {
        let t = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return buyers }
        return buyers.filter {
            $0.name.lowercased().contains(t) ||
            $0.phone.contains(t) ||
            $0.address.lowercased().contains(t)
        }
    }
}

// MARK: - Print Bill View

struct ExportBillPrintView: View {
    let receiptLines: [String]
    let creatorName: String
    let date: Date
    let buyerName: String
    let buyerPhone: String
    let buyerAddress: String
    let items: [RestockItem]
    let subtotal: Double
    let vatEnabled: Bool
    let vatRate: Double
    let vatAmount: Double
    let grandTotal: Double
    let paidAmount: Double
    let debtAmount: Double
    let expectedPayDate: Date?
    var qrURL: URL? = nil
    var billTitle: String = "PHIẾU XUẤT THÀNH PHẨM"
    var debtLabel: String = "Còn lại"
    var billNavTitle: String = "Bill xuất thành phẩm"
    var billPartyHeader: String = "THÔNG TIN BÊN MUA"

    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                billContent
                    .padding()
            }
            .navigationTitle(billNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await shareBill() }
                    } label: {
                        if isSharing {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up").fontWeight(.bold)
                        }
                    }
                }
            }
        }
    }

    private var billContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Store header
            VStack(alignment: .center, spacing: 4) {
                ForEach(Array(receiptLines.enumerated()), id: \.offset) { _, line in
                    if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(line)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    }
                }
                Text(billTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.top, 4)
                Text(formatDateTime(date))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Creator
            if !creatorName.isEmpty {
                HStack {
                    Text("Nhân viên xuất:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(creatorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            // Buyer info
            VStack(alignment: .leading, spacing: 4) {
                Text(billPartyHeader)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                Text(buyerName).font(.subheadline).fontWeight(.semibold)
                if !buyerPhone.isEmpty {
                    Text("SĐT: \(buyerPhone)").font(.caption).foregroundStyle(.gray)
                }
                if !buyerAddress.isEmpty {
                    Text("ĐC: \(buyerAddress)").font(.caption).foregroundStyle(.gray)
                }
            }

            Divider()

            // Items
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Hàng hoá").font(.caption).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)
                    Text("SL").font(.caption).foregroundStyle(.gray).frame(width: 70, alignment: .trailing)
                    Text("Thành tiền").font(.caption).foregroundStyle(.gray).frame(width: 90, alignment: .trailing)
                }
                Divider()
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline)
                            Text(formatCurrency(item.unitPrice) + "/kg").font(.caption).foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(FormatUtils.formatWeight(item.quantity))
                            .font(.subheadline)
                            .frame(width: 70, alignment: .trailing)
                        Text(formatCurrency(Double(item.quantity) / 1000.0 * item.unitPrice))
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
                    Text(formatCurrency(grandTotal)).font(.headline).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                }
                if debtAmount > 0 {
                    HStack {
                        Text(debtLabel).font(.subheadline).foregroundStyle(.red)
                        Spacer()
                        Text(formatCurrency(debtAmount)).font(.subheadline).fontWeight(.bold).foregroundStyle(.red)
                    }
                    if let d = expectedPayDate {
                        HStack {
                            Text("Dự kiến trả:").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatDateOnly(d)).font(.caption).fontWeight(.semibold)
                        }
                    }
                }
            }

            // QR code
            if let url = qrURL {
                Divider()
                VStack(spacing: 8) {
                    Text("Quét mã QR để thanh toán")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: 160, height: 160)
                                .cornerRadius(10)
                        case .empty:
                            ProgressView().frame(width: 160, height: 160)
                        default:
                            Image(systemName: "qrcode")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                                .frame(width: 160, height: 160)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

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

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}
