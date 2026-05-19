import SwiftUI

struct TransactionEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    let original: ProductionTransaction
    @Environment(\.dismiss) var dismiss
    
    @State private var items: [RestockItem] = []
    @State private var editingItem: RestockItem?
    @State private var editingItemIndex: Int?
    @State private var editingIndex: Int?
    @State private var showQuantityWheel = false
    @State private var showUnitPriceWheel = false
    @State private var showAdditionalCostWheel = false
    @State private var editingUnit: String = "kg"
    @State private var quantityWheelSelection = 1
    @State private var quantityWheelMax = 500
    @State private var quantityKgSelection = 0
    @State private var gramsWheelSelection = 0
    @State private var gramsWheelMax = 990
    @State private var quantityKgRangeBase = 0
    @State private var gramsWheelRangeBase = 0
    @State private var showQuantityKgRangePicker = false
    @State private var showGramsRangePicker = false
    @State private var unitPriceWheelSelection = 0
    @State private var unitPriceWheelMax = 5000000
    @State private var unitPriceWheelBaseSelection = 0
    @State private var unitPriceWheelHundredsSelection = 0
    @State private var unitPriceWheelRangeBase = 0
    @State private var showUnitPriceWheelRangePicker = false
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostWheelMax = 1000000
    @State private var additionalCostWheelBaseSelection = 0
    @State private var additionalCostWheelHundredsSelection = 0
    @State private var additionalCostWheelRangeBase = 0
    @State private var showAdditionalCostWheelRangePicker = false
    @State private var noteText: String = ""

    // Buyer info (for xuất thành phẩm)
    @State private var buyerName: String = ""
    @State private var buyerPhone: String = ""
    @State private var buyerAddress: String = ""
    @State private var buyerHistory: [TradingParty] = []
    @State private var showBuyerPicker = false

    // Payment (for xuất thành phẩm)
    @State private var payFullAmount: Bool = true
    @State private var partialAmountText: String = ""
    @State private var showPartialAmountWheel = false
    @State private var partialAmountSelection = 0
    @State private var partialAmountBaseSelection = 0
    @State private var partialAmountHundredsSelection = 0
    @State private var partialAmountMax = 5_000_000
    @State private var partialAmountRangeBase = 0
    @State private var showPartialAmountRangePicker = false
    @State private var expectedPayDate: Date? = nil
    @State private var showDatePicker = false
    @State private var isPaid: Bool = false
    @State private var paymentReceiptImage: UIImage? = nil
    @State private var paymentReceiptURL: String? = nil
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var isUploadingReceipt = false

    // QR
    @State private var loadedQRImage: UIImage? = nil

    private var isExportFinishedGoods: Bool {
        let t = original.mode.lowercased()
        return t.contains("xuất thành phẩm") || t.contains("nhập nguyên liệu")
    }

    private var isFinishedGoods: Bool {
        let t = original.mode.lowercased()
        return t.contains("thành phẩm") && !t.contains("nguyên liệu")
    }
    
    private var unitPriceTitle: String {
        let t = original.mode.lowercased()
        return t.contains("xuất") ? "Đơn giá xuất" : "Đơn giá nhập"
    }

    private var vatEnabled: Bool { StoreManager.shared.currentStoreVATEnabled() }
    private var vatRate: Double { customVATRate ?? StoreManager.shared.currentStoreVATRate() }

    // VAT tùy chỉnh tại bước thanh toán
    @State private var customVATRate: Double? = nil
    @State private var showVATRatePicker = false
    @State private var showDeleteAlert = false
    @State private var deleteNoteText = ""
    @State private var isDeletingTx = false
    @State private var vatRateInputText: String = ""

    private var subtotal: Double {
        items.reduce(0) { sum, item in
            let isCai = item.unit?.lowercased() == "cái"
            let qtyForCalculation: Double
            if isExportFinishedGoods && !isCai {
                qtyForCalculation = Double(item.quantity) / 1000.0
            } else if let unit = item.unit, unit.lowercased() == "kg" {
                qtyForCalculation = Double(item.quantity) / 1000.0
            } else {
                qtyForCalculation = Double(item.quantity)
            }
            let itemTotal = (qtyForCalculation * item.unitPrice) + item.additionalCost
            return sum + itemTotal
        }
    }
    private var vatAmount: Double { vatEnabled ? subtotal * (vatRate / 100.0) : 0 }
    private var grandTotal: Double { subtotal + vatAmount }
    private var paidAmount: Double {
        if payFullAmount { return grandTotal }
        return Double(partialAmountSelection)
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
            List {
                Section(header: Text("Sản phẩm")) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(it.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Spacer()
                                Button {
                                    editingItemIndex = idx
                                    editingItem = it
                                } label: {
                                    Text("Sửa")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                            let src = it.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if !src.isEmpty {
                                Text("Nguồn: \(src)")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            HStack {
                                Text("SL")
                                Spacer()
                                Text(FormatUtils.formatWeight(it.quantity, unit: it.unit))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        quantityWheelSelection = it.quantity
                                        editingUnit = it.unit ?? "kg"
                                        showQuantityWheel = true
                                    }
                            }
                            HStack {
                                Text(unitPriceTitle)
                                Spacer()
                                Text(formatCurrency(it.unitPrice))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        unitPriceWheelSelection = Int(it.unitPrice)
                                        showUnitPriceWheel = true
                                    }
                            }
                            HStack {
                                Text("Chi phí")
                                Spacer()
                                Text(formatCurrency(it.additionalCost))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        additionalCostWheelSelection = Int(it.additionalCost)
                                        showAdditionalCostWheel = true
                                    }
                            }
                            HStack {
                                Text("Đơn giá gồm chi phí")
                                Spacer()
                                Text(formatCurrency(it.finalUnitCost))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                // Buyer info section (only for xuất thành phẩm)
                if isExportFinishedGoods {
                    Section(header: Text(original.mode.lowercased().contains("nhập") ? "Thông tin bên nhập" : "Thông tin bên mua")) {
                        HStack {
                            if !buyerHistory.isEmpty {
                                Button {
                                    showBuyerPicker = true
                                } label: {
                                    Label("Lịch sử", systemImage: "clock.arrow.circlepath")
                                        .font(.caption)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack {
                            Text("Tên / Công ty").font(.caption).foregroundStyle(.gray).frame(width: 110, alignment: .leading)
                            TextField("Nhập tên...", text: $buyerName)
                        }
                        HStack {
                            Text("Số điện thoại").font(.caption).foregroundStyle(.gray).frame(width: 110, alignment: .leading)
                            TextField("Nhập SĐT...", text: $buyerPhone).keyboardType(.phonePad)
                        }
                        HStack {
                            Text("Địa chỉ").font(.caption).foregroundStyle(.gray).frame(width: 110, alignment: .leading)
                            TextField("Nhập địa chỉ...", text: $buyerAddress)
                        }
                    }

                    Section(header: Text("Thanh toán")) {
                        // Totals
                        if vatEnabled {
                            HStack {
                                Text("Tổng tiền hàng").foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(subtotal)).fontWeight(.semibold)
                            }
                            HStack {
                                Button {
                                    vatRateInputText = String(format: "%.0f", vatRate)
                                    showVATRatePicker = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("VAT (\(vatRate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", vatRate) : String(format: "%.1f", vatRate))%)")
                                            .foregroundStyle(.gray)
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(customVATRate != nil ? Color.orange : Color.gray.opacity(0.5))
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text(formatCurrency(vatAmount)).fontWeight(.semibold)
                            }
                        }
                        HStack {
                            Text("Tổng cộng").fontWeight(.bold)
                            Spacer()
                            Text(formatCurrency(grandTotal)).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                        }

                        // Payment option
                        Picker("Thanh toán", selection: $payFullAmount) {
                            Text("100%").tag(true)
                            Text("Trả một phần").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if !payFullAmount {
                            HStack {
                                Text("Số tiền trả").foregroundStyle(.gray)
                                Spacer()
                                Button {
                                    showPartialAmountWheel = true
                                } label: {
                                    Text(formatCurrency(Double(partialAmountSelection)))
                                        .fontWeight(.semibold)
                                }
                            }
                            if debtAmount > 0 {
                                HStack {
                                    Text(original.mode.lowercased().contains("nhập") ? "Thiếu nợ còn lại" : "Công nợ còn lại").foregroundStyle(.red)
                                    Spacer()
                                    Text(formatCurrency(debtAmount)).fontWeight(.bold).foregroundStyle(.red)
                                }
                                HStack {
                                    Text("Dự kiến trả hết").foregroundStyle(.gray)
                                    Spacer()
                                    Button {
                                        showDatePicker = true
                                    } label: {
                                        Text(expectedPayDate == nil ? "Chưa xác định" : formatDateOnly(expectedPayDate!))
                                            .foregroundStyle(expectedPayDate == nil ? .gray : Color.themePrimary)
                                    }
                                }
                            }
                        }

                        // Payment status
                        HStack {
                            Text("Trạng thái").foregroundStyle(.gray)
                            Spacer()
                            Button {
                                isPaid.toggle()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isPaid ? "checkmark.circle.fill" : "clock.fill")
                                    Text(isPaid ? "Đã thanh toán" : "Chưa thanh toán")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(isPaid ? .green : .orange)
                            }
                            .buttonStyle(.plain)
                        }

                        // Receipt image
                        HStack {
                            Text("Chứng từ").foregroundStyle(.gray)
                            Spacer()
                            if isUploadingReceipt {
                                ProgressView()
                            } else if let img = paymentReceiptImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if let urlStr = paymentReceiptURL, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Color.gray.opacity(0.2).frame(width: 44, height: 44)
                                    }
                                }
                            }
                            Button("Chụp") {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showReceiptCamera = true
                                } else { showReceiptLibrary = true }
                            }
                            .font(.caption)
                        }
                    }

                    // QR section (only for xuất)
                    if let url = qrURL, !original.mode.lowercased().contains("nhập") {
                        Section(header: Text("Mã QR thanh toán")) {
                            VStack(spacing: 8) {
                                Text("Số tiền: \(formatCurrency(paidAmount))")
                                    .font(.caption).foregroundStyle(.gray)
                                if let img = loadedQRImage {
                                    Image(uiImage: img)
                                        .resizable().scaledToFit()
                                        .frame(width: 160, height: 160)
                                        .cornerRadius(10)
                                } else {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFit()
                                                .frame(width: 160, height: 160).cornerRadius(10)
                                        case .empty:
                                            ProgressView().frame(width: 160, height: 160)
                                        default:
                                            Image(systemName: "qrcode").font(.system(size: 50))
                                                .foregroundStyle(.gray).frame(width: 160, height: 160)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: paidAmount) { _, _ in loadQRImage(url: url) }
                    }
                }

                Section(header: Text("Ghi chú chỉnh sửa")) {
                    TextField("", text: $noteText)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                }
            }
            .navigationTitle("Sửa giao dịch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        deleteNoteText = ""
                        showDeleteAlert = true
                    } label: {
                        Label("Xoá", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(original.isDeleted || isDeletingTx)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let total = items.reduce(0) { $0 + $1.totalCost }
                        var updated = ProductionTransaction(id: original.id, createdAt: original.createdAt, mode: original.mode, items: items, totalCost: total)
                        updated.note = noteText.isEmpty ? nil : noteText
                        // Preserve / update export info
                        if isExportFinishedGoods {
                            updated.buyerName = buyerName.isEmpty ? nil : buyerName
                            updated.buyerPhone = buyerPhone.isEmpty ? nil : buyerPhone
                            updated.buyerAddress = buyerAddress.isEmpty ? nil : buyerAddress
                            updated.grandTotal = grandTotal
                            updated.paidAmount = paidAmount
                            updated.debtAmount = debtAmount
                            updated.vatRate = vatRate
                            updated.vatAmount = vatAmount
                            updated.isPaid = isPaid
                            updated.expectedPayDate = expectedPayDate
                            updated.paymentReceiptURL = paymentReceiptURL
                        } else {
                            updated.buyerName = original.buyerName
                            updated.buyerPhone = original.buyerPhone
                            updated.buyerAddress = original.buyerAddress
                            updated.grandTotal = original.grandTotal
                            updated.paidAmount = original.paidAmount
                            updated.debtAmount = original.debtAmount
                            updated.vatRate = original.vatRate
                            updated.vatAmount = original.vatAmount
                            updated.isPaid = original.isPaid
                            updated.expectedPayDate = original.expectedPayDate
                            updated.paymentReceiptURL = original.paymentReceiptURL
                        }
                        Task {
                            _ = await viewModel.updateProductionTransaction(original: original, updated: updated)
                            dismiss()
                        }
                    }
                    .disabled(items.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                }
            }
        }
        .alert("Xoá giao dịch", isPresented: $showDeleteAlert) {
            TextField("Lý do xoá...", text: $deleteNoteText)
            Button("Hủy", role: .cancel) { }
            Button("Xoá", role: .destructive) {
                isDeletingTx = true
                Task {
                    _ = await viewModel.softDeleteProductionTransaction(original, note: deleteNoteText)
                    await MainActor.run {
                        isDeletingTx = false
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Kho sẽ được hoàn trả. Hành động này không thể hoàn tác.")
        }
        .onAppear {
            items = original.items
            noteText = ""
            let partyType = original.mode.lowercased().contains("nhập") ? "supplier" : "buyer"
            Task {
                if let parties = try? await viewModel.databaseService.fetchTradingParties(type: partyType) {
                    await MainActor.run { buyerHistory = parties }
                }
            }
            if isExportFinishedGoods {                buyerName = original.buyerName ?? ""
                buyerPhone = original.buyerPhone ?? ""
                buyerAddress = original.buyerAddress ?? ""
                isPaid = original.isPaid
                expectedPayDate = original.expectedPayDate
                paymentReceiptURL = original.paymentReceiptURL
                customVATRate = original.vatRate
                if let paid = original.paidAmount, let grand = original.grandTotal {
                    if paid < grand {
                        payFullAmount = false
                        partialAmountSelection = Int(paid)
                    }
                }
            }
        }
        .sheet(isPresented: $showBuyerPicker) {
            BuyerPickerSheet(buyers: buyerHistory) { selected in
                buyerName = selected.name
                buyerPhone = selected.phone
                buyerAddress = selected.address
            }
        }        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Ngày dự kiến trả", selection: Binding(
                        get: { expectedPayDate ?? Date() },
                        set: { expectedPayDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    Spacer()
                }
                .navigationTitle("Ngày dự kiến trả")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showDatePicker = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Xong") { showDatePicker = false } }
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
        .sheet(isPresented: $showReceiptLibrary, onDismiss: uploadReceiptIfNeeded) {
            ImagePicker(image: $paymentReceiptImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showVATRatePicker) {
            VATRatePickerSheet(
                rateText: $vatRateInputText,
                defaultRate: StoreManager.shared.currentStoreVATRate(),
                onSave: { newRate in customVATRate = newRate },
                onReset: { customVATRate = nil }
            )
        }
        .sheet(isPresented: $showPartialAmountWheel) {
            NavigationStack {
                VStack(spacing: 12) {
                    Text("Số tiền trả").font(.headline)
                    let step = StoreManager.shared.priceStep
                    let rangeMin = max(0, (partialAmountRangeBase / step) * step)
                    HStack {
                        Button {
                            showPartialAmountRangePicker = true
                        } label: {
                            Text(partialAmountRangeBase <= 0 ? ">0" : ">\(partialAmountRangeBase / 1000)k")
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    HStack {
                        VStack {
                            Text("Giá")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Picker("", selection: $partialAmountBaseSelection) {
                                ForEach(Array(stride(from: rangeMin, through: partialAmountMax, by: step)), id: \.self) { v in
                                    Text(formatCurrency(Double(v))).tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: partialAmountBaseSelection) { _, newValue in
                                partialAmountSelection = newValue + partialAmountHundredsSelection
                                if newValue > partialAmountMax - (step * 5) {
                                    partialAmountMax += step * 100
                                }
                            }
                        }
                        VStack {
                            Text("Trăm")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Picker("", selection: $partialAmountHundredsSelection) {
                                ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: partialAmountHundredsSelection) { _, newValue in
                                partialAmountSelection = partialAmountBaseSelection + newValue
                            }
                        }
                        .frame(width: 110)
                    }
                    HStack {
                        Button("Đóng") { showPartialAmountWheel = false }
                        Spacer()
                        Button("Lưu") { showPartialAmountWheel = false }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(300)])
                .onAppear {
                    let step = StoreManager.shared.priceStep
                    let current = max(0, partialAmountSelection)
                    partialAmountRangeBase = (current / 100000) * 100000
                    partialAmountBaseSelection = (current / step) * step
                    let remainder = max(0, current - partialAmountBaseSelection)
                    partialAmountHundredsSelection = min(900, (remainder / 100) * 100)
                }
                .sheet(isPresented: $showPartialAmountRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng giá trị").font(.headline)
                        let step = StoreManager.shared.priceStep
                        Picker("", selection: $partialAmountRangeBase) {
                            ForEach(Array(stride(from: 0, through: min(partialAmountMax, 10_000_000), by: 100_000)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v / 1000)k").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: partialAmountRangeBase) { _, newValue in
                            if newValue >= partialAmountMax - 200_000 {
                                partialAmountMax += 1_000_000
                            }
                        }
                        
                        Button {
                            let rangeMin = max(0, (partialAmountRangeBase / step) * step)
                            if partialAmountBaseSelection < rangeMin { partialAmountBaseSelection = rangeMin }
                            showPartialAmountRangePicker = false
                        } label: {
                            Text("Xong")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.themePrimary)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .presentationDetents([.height(300)])
                }
            }
        }
        .sheet(item: $editingItem) { item in
            ProductionTransactionItemEditView(
                viewModel: viewModel,
                modeTitle: original.mode,
                isFinishedGoods: isFinishedGoods,
                initialItem: item
            ) { updatedItem in
                if let idx = editingItemIndex, items.indices.contains(idx) {
                    items[idx] = updatedItem
                }
                editingItem = nil
                editingItemIndex = nil
            }
        }
        .sheet(isPresented: $showQuantityWheel) {
            NavigationStack {
                VStack(spacing: 12) {
                    let isMaterials = original.mode.lowercased().contains("nguyên liệu")
                    if isMaterials {
                        Picker("Đơn vị", selection: $editingUnit) {
                            Text("Kg").tag("kg")
                            Text("Cái").tag("cái")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    if isMaterials && editingUnit.lowercased() == "cái" {
                        Picker("", selection: $quantityWheelSelection) {
                            ForEach(Array(1...quantityWheelMax), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: quantityWheelSelection) { _, newValue in
                            if newValue >= quantityWheelMax - 10 {
                                quantityWheelMax += 200
                            }
                        }
                    } else {
                        HStack {
                            Button {
                                showQuantityKgRangePicker = true
                            } label: {
                                Text(quantityKgRangeBase <= 0 ? ">0" : ">\(quantityKgRangeBase)")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                showGramsRangePicker = true
                            } label: {
                                Text(gramsWheelRangeBase <= 0 ? ">0" : ">\(gramsWheelRangeBase)")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            VStack {
                                Text("Kg").font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $quantityKgSelection) {
                                    ForEach(Array(quantityKgRangeBase...quantityWheelMax), id: \.self) { kg in
                                        Text("\(kg)").tag(kg)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: quantityKgSelection) { _, newValue in
                                    if newValue >= max(0, quantityWheelMax - 10) {
                                        quantityWheelMax += 200
                                    }
                                }
                            }
                            VStack {
                                Text("Gam").font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $gramsWheelSelection) {
                                    ForEach(Array(stride(from: gramsWheelRangeBase, through: gramsWheelMax, by: 10)), id: \.self) { g in
                                        Text("\(g)").tag(g)
                                    }
                                }
                                .pickerStyle(.wheel)
                            }
                        }
                        .onAppear {
                            let current = quantityWheelSelection
                            quantityKgSelection = max(0, current / 1000)
                            let remainder = max(0, current % 1000)
                            gramsWheelSelection = (remainder / 10) * 10
                            quantityKgRangeBase = (quantityKgSelection / 100) * 100
                            gramsWheelRangeBase = (gramsWheelSelection / 100) * 100
                        }
                    }
                }
                .navigationTitle("Sửa số lượng")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showQuantityWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex {
                                if original.mode.lowercased().contains("nguyên liệu") && editingUnit.lowercased() == "cái" {
                                    items[i].quantity = quantityWheelSelection
                                    items[i].unit = "cái"
                                } else {
                                    let total = quantityKgSelection * 1000 + gramsWheelSelection
                                    items[i].quantity = total
                                    items[i].unit = "kg"
                                    quantityWheelSelection = total
                                }
                            }
                            showQuantityWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(original.mode.lowercased().contains("nguyên liệu") ? 380 : 340)])
            .sheet(isPresented: $showQuantityKgRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng giá trị").font(.headline)
                    Picker("", selection: $quantityKgRangeBase) {
                        ForEach(Array(stride(from: 0, through: quantityWheelMax, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: quantityKgRangeBase) { _, newValue in
                        if newValue >= quantityWheelMax - 100 {
                            quantityWheelMax += 500
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            if quantityKgSelection < quantityKgRangeBase { quantityKgSelection = quantityKgRangeBase }
                            showQuantityKgRangePicker = false
                        } label: {
                            Text("Xong")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.themePrimary)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showGramsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng giá trị Gam").font(.headline)
                    Picker("", selection: $gramsWheelRangeBase) {
                        ForEach(Array(stride(from: 0, through: gramsWheelMax, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: gramsWheelRangeBase) { _, newValue in
                        if gramsWheelSelection < newValue { gramsWheelSelection = newValue }
                    }
                    HStack {
                        Button("Đóng") { showGramsRangePicker = false }
                        Spacer()
                        Button("Xong") { showGramsRangePicker = false }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(300)])
            }
        }
        .sheet(isPresented: $showUnitPriceWheel) {
            NavigationStack {
                Form {
                    Section {
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (unitPriceWheelRangeBase / step) * step)
                        HStack {
                            Button {
                                showUnitPriceWheelRangePicker = true
                            } label: {
                                Text(unitPriceWheelRangeBase <= 0 ? ">0" : ">\(unitPriceWheelRangeBase / 1000)k")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        HStack {
                            VStack {
                                Text("Giá")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $unitPriceWheelBaseSelection) {
                                    ForEach(Array(stride(from: rangeMin, through: unitPriceWheelMax, by: step)), id: \.self) { v in
                                        Text(formatCurrency(Double(v))).tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: unitPriceWheelBaseSelection) { _, newValue in
                                    unitPriceWheelSelection = newValue + unitPriceWheelHundredsSelection
                                    if newValue > unitPriceWheelMax - (step * 5) {
                                        unitPriceWheelMax += step * 100
                                    }
                                }
                            }
                            VStack {
                                Text("Trăm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $unitPriceWheelHundredsSelection) {
                                    ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: unitPriceWheelHundredsSelection) { _, newValue in
                                    unitPriceWheelSelection = unitPriceWheelBaseSelection + newValue
                                }
                            }
                            .frame(width: 110)
                        }
                    }
                }
                .navigationTitle("Sửa giá nhập")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showUnitPriceWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex { items[i].unitPrice = Double(unitPriceWheelSelection) }
                            showUnitPriceWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, unitPriceWheelSelection)
                unitPriceWheelRangeBase = (current / 100000) * 100000
                unitPriceWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - unitPriceWheelBaseSelection)
                unitPriceWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showUnitPriceWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(unitPriceWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        unitPriceWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if unitPriceWheelBaseSelection < rangeMin { unitPriceWheelBaseSelection = rangeMin }
                        showUnitPriceWheelRangePicker = false
                    }
                }
            }
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            NavigationStack {
                Form {
                    Section {
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (additionalCostWheelRangeBase / step) * step)
                        HStack {
                            Button {
                                showAdditionalCostWheelRangePicker = true
                            } label: {
                                Text(additionalCostWheelRangeBase <= 0 ? ">0" : ">\(additionalCostWheelRangeBase / 1000)k")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        HStack {
                            VStack {
                                Text("Giá")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $additionalCostWheelBaseSelection) {
                                    ForEach(Array(stride(from: rangeMin, through: additionalCostWheelMax, by: step)), id: \.self) { v in
                                        Text(formatCurrency(Double(v))).tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: additionalCostWheelBaseSelection) { _, newValue in
                                    additionalCostWheelSelection = newValue + additionalCostWheelHundredsSelection
                                    if newValue > additionalCostWheelMax - (step * 5) {
                                        additionalCostWheelMax += step * 100
                                    }
                                }
                            }
                            VStack {
                                Text("Trăm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $additionalCostWheelHundredsSelection) {
                                    ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: additionalCostWheelHundredsSelection) { _, newValue in
                                    additionalCostWheelSelection = additionalCostWheelBaseSelection + newValue
                                }
                            }
                            .frame(width: 110)
                        }
                    }
                }
                .navigationTitle("Sửa chi phí")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showAdditionalCostWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex { items[i].additionalCost = Double(additionalCostWheelSelection) }
                            showAdditionalCostWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, additionalCostWheelSelection)
                additionalCostWheelRangeBase = (current / 100000) * 100000
                additionalCostWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - additionalCostWheelBaseSelection)
                additionalCostWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showAdditionalCostWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(additionalCostWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        additionalCostWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if additionalCostWheelBaseSelection < rangeMin { additionalCostWheelBaseSelection = rangeMin }
                        showAdditionalCostWheelRangePicker = false
                    }
                }
            }
        }
    }
    // MARK: - Helpers

    private func loadQRImage(url: URL) {
        Task {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                await MainActor.run { loadedQRImage = img }
            }
        }
    }

    private func uploadReceiptIfNeeded() {
        guard let img = paymentReceiptImage, paymentReceiptURL == nil else { return }
        guard let data = img.jpegData(compressionQuality: 0.85) else { return }
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let fileName = UUID().uuidString
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

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

}

// MARK: - VAT Rate Picker Sheet (shared)
struct VATRatePickerSheet: View {
    @Binding var rateText: String
    let defaultRate: Double
    let onSave: (Double) -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Bánh xe: phần nguyên 0–50, phần thập phân 0 / 0.5
    @State private var intSelection: Int = 10
    @State private var decSelection: Int = 0   // 0 → .0,  1 → .5

    private var selectedRate: Double {
        Double(intSelection) + (decSelection == 1 ? 0.5 : 0.0)
    }

    private func formatRate(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("Chỉnh VAT cho đơn này")
                .font(.headline)
                .padding(.top, 14)

            Text("Chỉ áp dụng cho đơn hiện tại")
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 8)

            // Bánh xe
            HStack(spacing: 0) {
                // Cột phần nguyên
                Picker("", selection: $intSelection) {
                    ForEach(0...50, id: \.self) { v in
                        Text("\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text(".")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)

                // Cột thập phân
                Picker("", selection: $decSelection) {
                    Text("0").tag(0)
                    Text("5").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 70)

                Text("%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
                    .padding(.leading, 4)
                    .padding(.trailing, 16)
            }
            .frame(height: 160)

            // Preview
            Text("VAT: \(formatRate(selectedRate))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.themePrimary)
                .padding(.bottom, 4)

            Divider().padding(.horizontal)

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onReset()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Mặc định (\(formatRate(defaultRate))%)")
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Button {
                    onSave(selectedRate)
                    dismiss()
                } label: {
                    Text("Lưu")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.themePrimary))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .onAppear {
            // Khởi tạo bánh xe từ rateText hoặc defaultRate
            let initial = Double(rateText.replacingOccurrences(of: ",", with: ".")) ?? defaultRate
            let clamped = max(0, min(50, initial))
            intSelection = Int(clamped)
            decSelection = (clamped.truncatingRemainder(dividingBy: 1) >= 0.25) ? 1 : 0
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}
