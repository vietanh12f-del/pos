import Foundation
import Combine
import SwiftUI
import Supabase

class OrderViewModel: ObservableObject {
    private func getInventoryKey(name: String, isFinishedGood: Bool) -> String {
        let prefix = isFinishedGood ? "fg:" : "good:"
        return prefix + name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @Published var currentInput: String = ""
    @Published var items: [OrderItem] = []
    @Published var lastFocusedItemId: UUID?
    @Published var showPayment: Bool = false {
        didSet {
            if showPayment && currentSequenceNumber == nil {
                currentSequenceNumber = FormatUtils.generateSequenceNumber()
            }
        }
    }
    /// Khi true, reset() sẽ không tự set showPayment = false (dùng cho flow in phiếu)
    var suppressPaymentDismissOnReset: Bool = false
    @Published var currentSequenceNumber: String? = nil
    @Published var walkInName: String = "Khách lẻ"
    @Published var walkInPhone: String = ""
    @Published var walkInAddress: String = ""
    @Published var walkInEmail: String = ""
    @Published var paymentReceiptImageURL: String? = nil
    @Published var payFullAmount: Bool = true
    @Published var editingBillIsPaid: Bool = false  // trạng thái isPaid của bill đang sửa
    @Published var isPaidConfirmedByUser: Bool? = nil  // override isPaid từ toggle UI
    @Published var newOrderStatus: String? = nil    // trạng thái đơn hàng khi tạo/sửa
    @Published var partialAmount: Double = 0
    @Published var expectedPayDate: Date? = nil
    @Published var note: String = ""
    @Published var selectedBillNumber: Int? = nil // nil = không hiển thị mã bill trên phiếu
    
    var totalAmountWithVAT: Double {
        let baseTotal = items.reduce(0) { $0 + $1.total }
        if let vatRate = vatRate, StoreManager.shared.currentStoreVATEnabled() {
            return baseTotal + (baseTotal * vatRate / 100)
        }
        return baseTotal
    }
    
    var debtAmount: Double {
        if payFullAmount {
            return 0
        }
        return max(0, totalAmountWithVAT - partialAmount)
    }
    
    var paidAmount: Double {
        if payFullAmount {
            return totalAmountWithVAT
        }
        return partialAmount
    }
    
    // Pending export info (set by FinishedGoodsExportView before confirming)
    var pendingExportNote: String? = nil
    var pendingExportPaymentReceiptURL: String? = nil

    struct PendingExportInfo {
        var buyerName: String
        var buyerPhone: String
        var buyerAddress: String
        var buyerTaxCode: String?
        var grandTotal: Double
        var paidAmount: Double
        var debtAmount: Double
        var vatRate: Double
        var vatAmount: Double
        var isPaid: Bool
        var expectedPayDate: Date?
        var paymentReceiptURL: String?
        var note: String?
    }
    var pendingExportInfo: PendingExportInfo? = nil
    
    @Published var priceHistory: [String: Double] = [:]
    @Published var inventory: [String: Int] = [:]
    @Published var pastOrders: [Bill] = []
    @Published var billEditHistory: [UUID: [BillEditEntry]] = [:]
    
    // Navigation Triggers
    @Published var shouldShowRestockSheet = false
    @Published var shouldShowOrderSheet = false
    @Published var showOrderSuccessToast: Bool = false
    
    @Published var lastCreatedBill: Bill?
    
    struct BillEditEntry: Codable, Identifiable {
        let id: UUID
        let date: Date
        let oldTotal: Double
        let newTotal: Double
        let editorName: String?
    }
    private let editHistoryKey = "bill_edit_history_v1"
    @Published var editedOrderIds: Set<UUID> = []
    @Published var editedProductionTxIds: Set<UUID> = []
    @Published var editedRestockBillIds: Set<UUID> = []
    @Published var autoMaterialExportTemplates: [AutoMaterialExportTemplate] = []
    
    // Cache control
    private var loadedStoreId: UUID?

    // Voice & AI
    @Published var isProcessingVoice: Bool = false
    @Published var useGPT: Bool = true // Toggle for AI parser
    @Published var isRecordingCustomerName: Bool = false
    @Published var isRecordingManualProductName: Bool = false
    @Published var manualRecordedName: String = ""
    @Published var isRecordingManualSource: Bool = false
    @Published var manualRecordedSource: String = ""


    // Alerting
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""

    // Dashboard Stats
    @Published var revenue: Double = 0
    @Published var orderCount: Int = 0
    @Published var totalRestockCost: Double = 0
    @Published var totalOperatingCost: Double = 0 // Added for net profit calculation
    
    // Daily Stats Cache
    @Published var todayStats: DailyFinancialStats?
    
    // Global Stats (All Time) - kept for compatibility, but maybe should be deprecated or updated
    var netProfit: Double {
        // Simple global calculation (Cash flow based or Accrual?)
        // Let's keep it simple: Revenue - COGS - Expenses (Global)
        // But COGS is tracked in bills.
        let paidOrders = pastOrders.filter { $0.isPaid }
        let globalRevenue = paidOrders.reduce(0) { $0 + $1.total }
        let globalCOGS = paidOrders.reduce(0) { $0 + $1.totalCost }
        let globalOpEx = operatingExpenses.reduce(0) { $0 + $1.amount }
        let globalIncurredFees = restockHistory.filter { !$0.isDeleted }.reduce(0) { billSum, bill in
            billSum + bill.items.reduce(0) { $0 + $1.additionalCost }
        }
        
        return globalRevenue - globalCOGS - globalOpEx - globalIncurredFees
    }
    
    // Restock
    @Published var isRestockMode: Bool = false {
        didSet {
            if isRestockMode && currentSequenceNumber == nil {
                currentSequenceNumber = FormatUtils.generateSequenceNumber()
            }
        }
    }
    @Published var currentRestockSessionTag: String = ""
    @Published var restockItems: [RestockItem] = []
    @Published var restockHistory: [RestockBill] = []
    @Published var editingRestockBill: RestockBill?
    @Published var operatingExpenses: [OperatingExpense] = []
    @Published var materialCategories: Set<String> = Set(Category.allCases.filter { $0 != .all }.map { $0.rawValue })
    @Published var productCategories: Set<String> = Set(Category.allCases.filter { $0 != .all }.map { $0.rawValue })
    @Published var materialsInventory: [MaterialItem] = []
    @Published var materials: [MaterialItem] = []
    @Published var productionHistory: [ProductionTransaction] = []
    @Published var suppliers: [TradingParty] = []
    
    // Catalog & Dashboard
    @Published var selectedCategory: Category = .all
    @Published var products: [Product] = [
        Product(name: "Hoa hồng đỏ", price: 20000, productPrice: 15000, shippingCost: 2000, costPrice: 17000, category: "Hoa tươi", imageName: "rosette", color: "red"),
        Product(name: "Hoa hướng dương", price: 30000, productPrice: 25000, shippingCost: 3000, costPrice: 28000, category: "Hoa tươi", imageName: "sun.max.fill", color: "yellow"),
        Product(name: "Hoa tulip", price: 25000, productPrice: 20000, shippingCost: 2000, costPrice: 22000, category: "Hoa tươi", imageName: "camera.macro", color: "purple"),
        Product(name: "Bó hoa hỗn hợp", price: 350000, productPrice: 300000, shippingCost: 20000, costPrice: 320000, category: "Bó hoa", imageName: "gift.fill", color: "pink"),
        Product(name: "Bó hoa sinh nhật", price: 500000, productPrice: 450000, shippingCost: 20000, costPrice: 470000, category: "Bó hoa", imageName: "birthday.cake.fill", color: "blue"),
        Product(name: "Bình hoa", price: 150000, productPrice: 120000, shippingCost: 10000, costPrice: 130000, category: "Phụ kiện", imageName: "cylinder.split.1x2.fill", color: "gray"),
        Product(name: "Ruy băng", price: 10000, productPrice: 8000, shippingCost: 1000, costPrice: 9000, category: "Phụ kiện", imageName: "scribble.variable", color: "red"),
        Product(name: "Thiệp chúc mừng", price: 15000, productPrice: 12000, shippingCost: 1000, costPrice: 13000, category: "Phụ kiện", imageName: "envelope.fill", color: "orange")
    ]
    
    var filteredProducts: [Product] {
        let base = products
        if selectedCategory == .all { return base }
        return base.filter { $0.category == selectedCategory.rawValue }
    }
    
    // Smart Suggestion
    @Published var searchText: String = ""
    
    var searchSuggestions: [Product] {
        if searchText.isEmpty { return [] }
        let lowerText = searchText.lowercased()
        return products.filter { 
            $0.name.lowercased().contains(lowerText) || 
            $0.category.lowercased().contains(lowerText) ||
            ($0.barcode?.contains(lowerText) ?? false)
        }
    }
    
    var finishedGoods: [Product] {
        products.filter { $0.isFinishedGood }
    }
    
    func addProduct(_ product: Product) {
        if let index = items.firstIndex(where: { $0.name == product.name && $0.price == product.price && $0.systemImage == product.imageName }) {
            items[index].quantity += 1
            lastFocusedItemId = items[index].id
        } else {
            items.append(OrderItem(name: product.name, quantity: 1, price: product.price, costPrice: product.costPrice, imageData: product.imageData, systemImage: product.imageName))
            lastFocusedItemId = items.last?.id
        }
    }
    
    // Speech integration
    @Published var speechRecognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()
    
    // Database Service
    private let database: DatabaseService = SupabaseDatabaseService()
    
    var databaseService: DatabaseService { database }
    
    // Connection Status
    @Published var isDatabaseConnected: Bool = false
    @Published var databaseError: String? = nil
    @Published var isLoading: Bool = false
    
    private var realtimeChannel: RealtimeChannelV2?
    /// IDs của orders vừa được edit locally — realtime update sẽ bị skip trong 3s để tránh race condition với order_items
    private var locallyEditedOrderIds: Set<UUID> = []
    
    init() {
        // Recalculate stats
        recalculateStats()
        loadEditHistory()
        
        // Listen to transcript changes
        speechRecognizer.$transcript
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main) // Reduced debounce for responsiveness
            .sink { [weak self] newText in
                // Only update if we have new text (even if recording just stopped)
                if !newText.isEmpty {
                    if self?.isRecordingCustomerName == true {
                        let name = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            self?.walkInName = name
                        }
                    } else if self?.isRecordingManualProductName == true {
                        let productName = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !productName.isEmpty {
                            self?.manualRecordedName = productName
                        }
                    } else if self?.isRecordingManualSource == true {
                        let sourceName = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sourceName.isEmpty {
                            self?.manualRecordedSource = sourceName
                        }
                    } else {
                        self?.currentInput = newText
                    }
                }
            }
            .store(in: &cancellables)
            
        // Listen for recording state changes to auto-process
        speechRecognizer.$isRecording
            .dropFirst()
            .sink { [weak self] isRecording in
                if !isRecording {
                    if self?.isRecordingCustomerName == true {
                        self?.isRecordingCustomerName = false
                    } else if self?.isRecordingManualProductName == true {
                        self?.isRecordingManualProductName = false
                    } else if self?.isRecordingManualSource == true {
                        self?.isRecordingManualSource = false
                    } else {
                        // Recording stopped (manual or auto)
                        // Wait slightly for final transcript
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            self?.processInput()
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        // Listen for AppIntent notifications
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TriggerVoiceInput"), object: nil, queue: .main) { [weak self] notification in
            if let text = notification.object as? String {
                self?.currentInput = text
                self?.processInput()
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TriggerRestockInput"), object: nil, queue: .main) { [weak self] notification in
            if let text = notification.object as? String {
                self?.currentInput = text
                // Ensure intent is detected as Restock
                if !(text.lowercased().contains("nhập") || text.lowercased().contains("restock")) {
                    self?.currentInput = "nhập " + text
                }
                self?.processInput()
            }
        }
    }
    
    func loadEditHistory() {
        if let data = UserDefaults.standard.data(forKey: editHistoryKey),
           let decoded = try? JSONDecoder().decode([UUID: [BillEditEntry]].self, from: data) {
            billEditHistory = decoded
        }
    }
    
    func saveEditHistory() {
        if let data = try? JSONEncoder().encode(billEditHistory) {
            UserDefaults.standard.set(data, forKey: editHistoryKey)
        }
    }
    
    func addEditHistory(for original: Bill, updated: Bill) {
        let entry = BillEditEntry(id: UUID(), date: Date(), oldTotal: original.total, newTotal: updated.total, editorName: AuthManager.shared.currentUserProfile?.fullName)
        var arr = billEditHistory[original.id] ?? []
        arr.append(entry)
        billEditHistory[original.id] = arr
        saveEditHistory()
        
        // Save to DB
        let editorId = AuthManager.shared.currentUserProfile?.id
        let details = buildEditDetails(original: original, updated: updated)
        let note = "Đã chỉnh sửa đơn"
        print("🧾 [OrderEdit] Original=\(Int(original.total)) Updated=\(Int(updated.total)) Details=\(details.joined(separator: " | "))")
        let edit = OrderEdit(id: entry.id, orderId: original.id, createdAt: entry.date, oldTotal: entry.oldTotal, newTotal: entry.newTotal, editorId: editorId, editorName: entry.editorName, note: note, details: details)
        Task {
            do {
                try await database.saveOrderEdit(edit)
                await MainActor.run {
                    editedOrderIds.insert(original.id)
                }
            } catch {
                print("❌ Error saving order edit history: \(error)")
                if let ns = error as NSError?, ns.domain == "StoreMissing" {
                    self.errorMessage = "Không thể lưu lịch sử chỉnh sửa vì chưa chọn cửa hàng."
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    /// Gọi từ BillDetailView khi thay đổi nhanh (trạng thái thanh toán, trạng thái đơn, công nợ)
    /// mà không đi qua flow sửa đơn toàn phần.
    func addQuickEditHistory(original: Bill, updated: Bill) {
        let details = buildEditDetails(original: original, updated: updated)
        guard !details.isEmpty else { return }  // Không có gì thay đổi → bỏ qua

        let entryId = UUID()
        let now = Date()
        let editorName = AuthManager.shared.currentUserProfile?.fullName
        let editorId   = AuthManager.shared.currentUserProfile?.id

        // Cập nhật legacy local cache (để hasHistory() trả về đúng)
        let entry = BillEditEntry(id: entryId, date: now, oldTotal: original.total, newTotal: updated.total, editorName: editorName)
        var arr = billEditHistory[original.id] ?? []
        arr.append(entry)
        billEditHistory[original.id] = arr
        saveEditHistory()
        editedOrderIds.insert(original.id)

        // Tạo note tóm tắt từ dòng đầu tiên của details
        let note = details.first ?? "Đã cập nhật đơn"
        let edit = OrderEdit(id: entryId, orderId: original.id, createdAt: now,
                             oldTotal: original.total, newTotal: updated.total,
                             editorId: editorId, editorName: editorName,
                             note: note, details: details)
        Task {
            do {
                try await database.saveOrderEdit(edit)
            } catch {
                print("❌ Error saving quick edit history: \(error)")
            }
        }
    }

    private func buildEditDetails(original: Bill, updated: Bill) -> [String] {
        // Helper format currency inline
        let fmtCurrency: (Double) -> String = { amount in
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = Locale(identifier: "vi_VN")
            f.currencySymbol = "₫"
            return f.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
        }
        var lines: [String] = []
        if (original.customerName ?? "") != (updated.customerName ?? "") {
            let o = (original.customerName ?? "").isEmpty ? "—" : (original.customerName ?? "")
            let n = (updated.customerName ?? "").isEmpty ? "—" : (updated.customerName ?? "")
            lines.append("👤 Khách: \(o) → \(n)")
        }
        if (original.paymentReceiptURL ?? "") != (updated.paymentReceiptURL ?? "") {
            lines.append("🖼️ Ảnh thanh toán: đã cập nhật")
        }
        var origMap: [String: OrderItem] = [:]
        var updMap: [String: OrderItem] = [:]
        for it in original.items { origMap[it.name] = it }
        for it in updated.items { updMap[it.name] = it }
        for name in Set(origMap.keys).union(updMap.keys).sorted() {
            let o = origMap[name]
            let n = updMap[name]
            if o == nil, let n {
                lines.append("➕ Thêm \(name): SL \(n.quantity), giá \(fmtCurrency(n.price))")
            } else if let o, n == nil {
                lines.append("➖ Xoá \(name): SL \(o.quantity)")
            } else if let o, let n {
                var parts: [String] = []
                if o.quantity != n.quantity { parts.append("SL \(o.quantity)→\(n.quantity)") }
                if Int(o.price) != Int(n.price) { parts.append("Giá \(fmtCurrency(o.price))→\(fmtCurrency(n.price))") }
                if Int(o.discount) != Int(n.discount) { parts.append("Giảm \(Int(o.discount))→\(Int(n.discount))") }
                if !parts.isEmpty {
                    lines.append("✏️ Sửa \(name): " + parts.joined(separator: ", "))
                }
            }
        }
        if original.total != updated.total {
            lines.append("💰 Tổng tiền: \(fmtCurrency(original.total)) → \(fmtCurrency(updated.total))")
        }
        // Trạng thái thanh toán (3 mức)
        let origPS = PaymentStatus.from(isPaid: original.isPaid, debtAmount: original.debtAmount)
        let updPS  = PaymentStatus.from(isPaid: updated.isPaid,  debtAmount: updated.debtAmount)
        if origPS != updPS {
            lines.append("💳 Thanh toán: \(origPS.label) → \(updPS.label)")
        }
        // Số tiền đã trả
        let origPaid = Int(original.paidAmount ?? (original.isPaid ? original.total : 0))
        let updPaid  = Int(updated.paidAmount  ?? (updated.isPaid  ? updated.total  : 0))
        if origPaid != updPaid {
            lines.append("✅ Đã trả: \(fmtCurrency(Double(origPaid))) → \(fmtCurrency(Double(updPaid)))")
        }
        // Công nợ
        let origDebt = Int(original.debtAmount ?? 0)
        let updDebt  = Int(updated.debtAmount  ?? 0)
        if origDebt != updDebt {
            lines.append("🔴 Công nợ: \(fmtCurrency(Double(origDebt))) → \(fmtCurrency(Double(updDebt)))")
        }
        // Trạng thái đơn hàng
        if (original.orderStatus ?? "") != (updated.orderStatus ?? "") {
            let fmtStatus: (String?) -> String = { s in
                switch s {
                case "preparing":  return "Chuẩn bị hàng"
                case "prepared":   return "Đã soạn hàng"
                case "delivering": return "Đang giao hàng"
                case "delivered":  return "Đã giao hàng"
                case "completed":  return "Hoàn thành"
                case "cancelled":  return "Đã huỷ"
                default:           return "Chưa cập nhật"
                }
            }
            lines.append("📦 Trạng thái đơn: \(fmtStatus(original.orderStatus)) → \(fmtStatus(updated.orderStatus))")
        }
        if (original.expectedPayDate) != (updated.expectedPayDate) {
            let fmt: (Date?) -> String = { d in
                guard let d else { return "—" }
                let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f.string(from: d)
            }
            lines.append("📅 Ngày trả: \(fmt(original.expectedPayDate)) → \(fmt(updated.expectedPayDate))")
        }
        if (original.note ?? "") != (updated.note ?? "") {
            let o = (original.note ?? "").isEmpty ? "—" : (original.note ?? "")
            let n = (updated.note ?? "").isEmpty ? "—" : (updated.note ?? "")
            lines.append("📝 Ghi chú: \(o) → \(n)")
        }
        return lines
    }
    
    func history(for billId: UUID) -> [BillEditEntry] {
        billEditHistory[billId] ?? []
    }
    
    func hasHistory(for billId: UUID) -> Bool {
        !(billEditHistory[billId]?.isEmpty ?? true) || editedOrderIds.contains(billId)
    }
    
    @MainActor
    func finalizeEditedPayment() async {
        guard let original = editingBill else { return }
        let newTotal = totalAmountWithVAT  // dùng total bao gồm VAT để nhất quán với paidAmount
        var updatedBill = Bill(id: original.id, createdAt: original.createdAt, items: items, total: newTotal)
        updatedBill.sequenceNumber = original.sequenceNumber
        updatedBill.customerName = walkInName
        updatedBill.customerPhone = walkInPhone.isEmpty ? nil : walkInPhone
        updatedBill.customerAddress = walkInAddress.isEmpty ? nil : walkInAddress
        updatedBill.customerEmail = walkInEmail.isEmpty ? nil : walkInEmail
        updatedBill.paymentReceiptURL = paymentReceiptImageURL ?? original.paymentReceiptURL
        updatedBill.vatRate = vatRate
        updatedBill.creatorId = original.creatorId
        updatedBill.creatorName = original.creatorName
        updatedBill.note = note.isEmpty ? nil : note
        updatedBill.expectedPayDate = expectedPayDate
        updatedBill.orderStatus = newOrderStatus  // lưu trạng thái đơn hàng
        // Tính toán thanh toán từ state người dùng đã chỉnh
        let currentDebt = debtAmount   // computed từ payFullAmount/partialAmount/totalAmountWithVAT
        let currentPaid = paidAmount   // computed từ payFullAmount/partialAmount/totalAmountWithVAT
        // isPaidConfirmedByUser ưu tiên hơn: người dùng có thể toggle trực tiếp trên UI
        let effectivePaid = isPaidConfirmedByUser ?? (currentDebt <= 0)
        updatedBill.isPaid = effectivePaid
        if !effectivePaid {
            updatedBill.paidAmount = 0
            updatedBill.debtAmount = updatedBill.total
        } else {
            updatedBill.paidAmount = currentPaid
            updatedBill.debtAmount = currentDebt > 0 ? currentDebt : nil
        }
        
        // Calculate VAT amount
        let vatEnabled = StoreManager.shared.currentStoreVATEnabled()
        let rate = vatRate ?? StoreManager.shared.currentStoreVATRate()
        updatedBill.vatAmount = vatEnabled ? (totalAmount * rate / 100.0) : 0
        if let index = pastOrders.firstIndex(where: { $0.id == original.id }) {
            pastOrders[index] = updatedBill
        }
        Task {
            do {
                // Mark locally edited để realtime update không overwrite items
                locallyEditedOrderIds.insert(original.id)
                try await database.updateOrder(updatedBill)
                addEditHistory(for: original, updated: updatedBill)
                // Clear flag sau 3s
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                locallyEditedOrderIds.remove(original.id)
            } catch {
                print("❌ Error updating edited payment: \(error)")
                locallyEditedOrderIds.remove(original.id)
            }
        }
        recalculateStats()
        reset()
    }
    
    func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            do {
                try speechRecognizer.startRecording()
                currentInput = "" // Clear input when starting new recording
            } catch {
                print("Error starting recording: \(error)")
            }
        }
    }
    
    func cancelVoiceProcessing() {
        if isProcessingVoice {
            isProcessingVoice = false
        }
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
    }
    
    // Clear all data (used when switching stores)
    func clearData() {
        self.loadedStoreId = nil // Reset cache
        self.products = []
        self.pastOrders = []
        self.restockHistory = []
        self.suppliers = []
        self.priceHistory = [:]
        self.operatingExpenses = []
        self.inventory = [:]
        self.revenue = 0
        self.orderCount = 0
        self.totalRestockCost = 0
        self.totalOperatingCost = 0
        self.todayStats = nil
        self.walkInName = "Khách lẻ"
        self.walkInPhone = ""
        self.walkInAddress = ""
        self.walkInEmail = ""
    }
    
    @MainActor
    func loadData(force: Bool = false) async {
        let storeId = StoreManager.shared.currentStore?.id
        
        // Skip if already loaded for this store, unless forced
        if !force && storeId == self.loadedStoreId && storeId != nil && !products.isEmpty {
             print("✅ OrderViewModel: Data already loaded for store \(storeId!.uuidString). Skipping.")
             return
        }
        
        guard let storeId = storeId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 OrderViewModel: Loading data for store: \(storeId) (Force: \(force))")
        
        // Define a helper for async results to avoid one failure killing the whole batch
        func fetchResult<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
            do {
                let value = try await operation()
                return .success(value)
            } catch {
                return .failure(error)
            }
        }
        
        // Fetch all data in parallel, but handle errors individually
        async let productsResult = fetchResult { try await self.database.fetchProducts() }
        async let ordersResult = fetchResult { try await self.database.fetchOrders() }
        async let restockResult = fetchResult { try await self.database.fetchRestockHistory() }
        async let pricesResult = fetchResult { try await self.database.fetchPriceHistory() }
        async let expensesResult = fetchResult { try await self.database.fetchOperatingExpenses() }
        async let suppliersResult = fetchResult { try await self.database.fetchTradingParties(type: "supplier") }
        
        let (rProds, rOrders, rRestock, rPrices, rExpenses, rSuppliers) = await (productsResult, ordersResult, restockResult, pricesResult, expensesResult, suppliersResult)
        
        // 1. Products (CRITICAL)
        switch rProds {
        case .success(let prods):
            self.products = prods
            let productsWithCost = prods.filter { $0.costPrice > 0 }
            if let first = prods.first {
                 print("✅ [OrderViewModel] Loaded \(prods.count) products. \(productsWithCost.count) have cost > 0. Sample: \(first.name) - Price: \(first.price), Cost: \(first.costPrice)")
            }
            // If we successfully fetched products, we assume we are connected
            self.isDatabaseConnected = true
            self.databaseError = nil
        case .failure(let error):
            // Check for cancellation to avoid false disconnected state
            let nsError = error as NSError
            if error is CancellationError || (error as? URLError)?.code == .cancelled || nsError.code == -999 {
                print("⚠️ Load data cancelled - keeping previous state")
                return
            }
            
            print("❌ Error fetching products: \(error)")
            self.isDatabaseConnected = false
            self.databaseError = error.localizedDescription
            self.errorMessage = "Không tải được danh sách hàng hóa từ cơ sở dữ liệu: \(error.localizedDescription)"
            self.showErrorAlert = true
            // If products fail, we can't do much, but we continue to process others just in case
        }
        
        // 2. Orders
        switch rOrders {
        case .success(let orders):
            self.pastOrders = orders
        case .failure(let error):
            print("⚠️ Error fetching orders: \(error)")
            // Don't set isDatabaseConnected = false here, as it might be a permission issue
        }
        
        // Fetch edited order IDs for badge
        if let sid = StoreManager.shared.currentStore?.id {
            do {
                let ids = try await self.database.fetchEditedOrderIds(storeId: sid)
                self.editedOrderIds = Set(ids)
            } catch {
                print("⚠️ Error fetching edited order ids: \(error)")
            }
        }
        
        // Fetch edited production transaction IDs for badge
        if let sid = StoreManager.shared.currentStore?.id {
            do {
                let ids = try await self.database.fetchEditedProductionTransactionIds(storeId: sid)
                self.editedProductionTxIds = Set(ids)
            } catch {
                print("⚠️ Error fetching edited production tx ids: \(error)")
            }
        }
        
        // Fetch edited restock bill IDs for badge
        if let sid = StoreManager.shared.currentStore?.id {
            do {
                let ids = try await self.database.fetchEditedRestockBillIds(storeId: sid)
                self.editedRestockBillIds = Set(ids)
            } catch {
                print("⚠️ Error fetching edited restock bill ids: \(error)")
            }
        }
        
        if let sid = StoreManager.shared.currentStore?.id {
            do {
                let templates = try await self.database.fetchAutoMaterialExportTemplates(storeId: sid)
                await MainActor.run {
                    self.autoMaterialExportTemplates = templates
                }
            } catch {
                print("⚠️ Error fetching auto material export templates: \(error)")
            }
        }
        
        // 3. Restock History
        switch rRestock {
        case .success(let restocks):
            self.restockHistory = restocks
        case .failure(let error):
            print("⚠️ Error fetching restock history: \(error)")
        }
        
        // 4. Price History
        switch rPrices {
        case .success(let prices):
            self.priceHistory = prices
        case .failure(let error):
            print("⚠️ Error fetching price history: \(error)")
        }
        
        // 5. Operating Expenses
        switch rExpenses {
        case .success(let expenses):
            self.operatingExpenses = expenses
        case .failure(let error):
            print("⚠️ Error fetching expenses: \(error)")
        }
        
        // 6. Suppliers
        switch rSuppliers {
        case .success(let suppliers):
            self.suppliers = suppliers
        case .failure(let error):
            print("⚠️ Error fetching suppliers: \(error)")
        }
        
        // Fetch categories from DB (merge with in-memory sets)
        do {
            let prodCats = try await database.fetchCategories(kind: "product")
            let matCats = try await database.fetchCategories(kind: "material")
            self.productCategories.formUnion(prodCats)
            self.materialCategories.formUnion(matCats)
        } catch {
            print("⚠️ Error fetching categories: \(error)")
        }
        
        // Sync inventory dictionary from products
        self.syncInventoryFromProducts()
        
        recalculateStats()
        
        // Mark as successfully loaded for this store
        if self.isDatabaseConnected {
            self.loadedStoreId = storeId
        }
        
        if database.isMock {
            print("⚠️ Running in Mock Mode (Supabase not installed)")
            self.isDatabaseConnected = false
            self.databaseError = "Chưa cài đặt Supabase Package"
        } else {
            // Setup Realtime Subscription
            setupRealtimeSubscription()
        }
    }
    
    var suggestedItems: [String] {
        return priceHistory.keys.sorted()
    }
    
    // MARK: - Realtime Sync
    func setupRealtimeSubscription() {
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        
        // Remove existing channel if any
        if let channel = realtimeChannel {
            Task { await channel.unsubscribe() }
        }
        
        let client = SupabaseConfig.client
        let decoder = client.database.configuration.decoder
        let channel = client.channel("db-changes")
        let filter = "store_id=eq.\(storeId)"
        
        // --- Products ---
        let _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "products", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Insert Product: \(change)")
            Task { @MainActor in
                do {
                    let dto = try change.decodeRecord(as: ProductDTO.self, decoder: decoder)
                    let product = dto.toDomain()
                    if !self.products.contains(where: { $0.id == product.id }) {
                        self.products.append(product)
                        let key = self.getInventoryKey(name: product.name, isFinishedGood: product.isFinishedGood)
                        self.inventory[key] = product.stockQuantity
                        self.recalculateStats()
                    }
                } catch {
                    print("❌ Error decoding product insert: \(error)")
                }
            }
        }
        
        let _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "products", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Update Product: \(change)")
            Task { @MainActor in
                do {
                    let dto = try change.decodeRecord(as: ProductDTO.self, decoder: decoder)
                    let product = dto.toDomain()
                    if let index = self.products.firstIndex(where: { $0.id == product.id }) {
                        self.products[index] = product
                        let key = self.getInventoryKey(name: product.name, isFinishedGood: product.isFinishedGood)
                        self.inventory[key] = product.stockQuantity
                        self.recalculateStats()
                    }
                } catch {
                    print("❌ Error decoding product update: \(error)")
                }
            }
        }
        
        let _ = channel.onPostgresChange(DeleteAction.self, schema: "public", table: "products", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Delete Product: \(change)")
            struct DeletePayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeOldRecord(as: DeletePayload.self, decoder: decoder)
                print("⚠️ Realtime delete detected for product ID: \(payload.id)")
                if let deletedProduct = self.products.first(where: { $0.id == payload.id }) {
                    print("⚠️ Deleted product name: \(deletedProduct.name), isFinishedGood: \(deletedProduct.isFinishedGood)")
                }
                Task { @MainActor in
                    self.products.removeAll { $0.id == payload.id }
                    self.recalculateStats()
                }
            } catch {
                print("❌ Error decoding product delete: \(error)")
            }
        }
        
        // --- Orders (Bills) ---
        let _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "orders", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Insert Order: \(change)")
            struct OrderPayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeRecord(as: OrderPayload.self, decoder: decoder)
                Task {
                    if let fullBill = try? await self.database.fetchOrder(id: payload.id) {
                        await MainActor.run {
                            if !self.pastOrders.contains(where: { $0.id == fullBill.id }) {
                                self.pastOrders.insert(fullBill, at: 0)
                                self.recalculateStats()
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error decoding order insert: \(error)")
            }
        }
        
        let _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "orders", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Update Order: \(change)")
            struct OrderPayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeRecord(as: OrderPayload.self, decoder: decoder)
                Task {
                    // Skip nếu order vừa được edit locally — tránh race condition với order_items delete+reinsert
                    guard !self.locallyEditedOrderIds.contains(payload.id) else {
                        print("⏭️ Realtime Update skipped (locally edited): \(payload.id)")
                        return
                    }
                    if let fullBill = try? await self.database.fetchOrder(id: payload.id) {
                        await MainActor.run {
                            if let index = self.pastOrders.firstIndex(where: { $0.id == fullBill.id }) {
                                self.pastOrders[index] = fullBill
                                self.recalculateStats()
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error decoding order update: \(error)")
            }
        }
        
        let _ = channel.onPostgresChange(DeleteAction.self, schema: "public", table: "orders", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Delete Order: \(change)")
            struct DeletePayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeOldRecord(as: DeletePayload.self, decoder: decoder)
                Task { @MainActor in
                    self.pastOrders.removeAll { $0.id == payload.id }
                    self.recalculateStats()
                }
            } catch {
                print("❌ Error decoding order delete: \(error)")
            }
        }
        
        // --- Restock Bills ---
        let _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "restock_bills", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Insert RestockBill: \(change)")
            struct RestockPayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeRecord(as: RestockPayload.self, decoder: decoder)
                Task {
                    if let fullBill = try? await self.database.fetchRestockBill(id: payload.id) {
                        await MainActor.run {
                            if !self.restockHistory.contains(where: { $0.id == fullBill.id }) {
                                self.restockHistory.insert(fullBill, at: 0)
                                self.recalculateStats()
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error decoding restock insert: \(error)")
            }
        }

        let _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "restock_bills", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Update RestockBill: \(change)")
            struct RestockPayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeRecord(as: RestockPayload.self, decoder: decoder)
                Task {
                    if let fullBill = try? await self.database.fetchRestockBill(id: payload.id) {
                        await MainActor.run {
                            if let index = self.restockHistory.firstIndex(where: { $0.id == fullBill.id }) {
                                self.restockHistory[index] = fullBill
                                self.recalculateStats()
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error decoding restock update: \(error)")
            }
        }
        
        let _ = channel.onPostgresChange(DeleteAction.self, schema: "public", table: "restock_bills", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Delete RestockBill: \(change)")
            struct DeletePayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeOldRecord(as: DeletePayload.self, decoder: decoder)
                Task { @MainActor in
                    self.restockHistory.removeAll { $0.id == payload.id }
                    self.recalculateStats()
                }
            } catch {
                print("❌ Error decoding restock delete: \(error)")
            }
        }
        
        // --- Operating Expenses ---
        let _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "operating_expenses", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Insert Expense: \(change)")
            Task { @MainActor in
                do {
                    let dto = try change.decodeRecord(as: OperatingExpenseDTO.self, decoder: decoder)
                    let expense = dto.toDomain()
                    if !self.operatingExpenses.contains(where: { $0.id == expense.id }) {
                        self.operatingExpenses.insert(expense, at: 0)
                        self.recalculateStats()
                    }
                } catch {
                    print("❌ Error decoding expense insert: \(error)")
                }
            }
        }

        let _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "operating_expenses", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Update Expense: \(change)")
            Task { @MainActor in
                do {
                    let dto = try change.decodeRecord(as: OperatingExpenseDTO.self, decoder: decoder)
                    let expense = dto.toDomain()
                    if let index = self.operatingExpenses.firstIndex(where: { $0.id == expense.id }) {
                        self.operatingExpenses[index] = expense
                        self.recalculateStats()
                    }
                } catch {
                    print("❌ Error decoding expense update: \(error)")
                }
            }
        }
        
        let _ = channel.onPostgresChange(DeleteAction.self, schema: "public", table: "operating_expenses", filter: filter) { [weak self] change in
            guard let self = self else { return }
            print("🔔 Realtime Delete Expense: \(change)")
            struct DeletePayload: Decodable { let id: UUID }
            do {
                let payload = try change.decodeOldRecord(as: DeletePayload.self, decoder: decoder)
                Task { @MainActor in
                    self.operatingExpenses.removeAll { $0.id == payload.id }
                    self.recalculateStats()
                }
            } catch {
                print("❌ Error decoding expense delete: \(error)")
            }
        }

        Task {
            await channel.subscribe()
            self.realtimeChannel = channel
            print("📡 Realtime subscription started for store: \(storeId)")
        }
    }

    enum DiscountMode: String, Codable {
        case percent
        case amount
        case finalPrice
    }
    
    @Published var discountMode: DiscountMode = .amount
    @Published var discountPercent: Int = 0            // 0...100
    @Published var discountAmountValue: Double = 0     // VND
    @Published var discountFinalPriceTarget: Double? = nil // VND
    @Published var vatRate: Double? = nil               // Custom VAT rate for the order
    
    var subtotalAmount: Double {
        items.reduce(0) { $0 + $1.total }
    }
    
    var billLevelDiscount: Double {
        let subtotal = subtotalAmount
        switch discountMode {
        case .percent:
            let v = Double(discountPercent)
            return max(0, min(100, v)) * subtotal / 100.0
        case .amount:
            return max(0, min(discountAmountValue, subtotal))
        case .finalPrice:
            if let target = discountFinalPriceTarget {
                return max(0, subtotal - max(0, min(target, subtotal)))
            } else {
                return 0
            }
        }
    }
    
    var totalAmount: Double {
        max(0, subtotalAmount - billLevelDiscount)
    }
    
    func processInput() {
        if useGPT {
            Task {
                await processInputGPT()
            }
        } else {
            processInputLegacy()
        }
    }
    
    @MainActor
    func processInputGPT() async {
        let rawText = currentInput
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            // Safety: Ensure processing flag is off if input is empty
            isProcessingVoice = false
            return 
        }
        
        // Prevent double processing if already processing
        if isProcessingVoice { return }
        
        isProcessingVoice = true
        // Keep processing flag on for a bit longer or handle it in UI
        
        do {
            let currentMode = isRestockMode ? "restock" : "order"
            let response = try await OpenAIService.shared.parseOrder(text: rawText, currentMode: currentMode)
            
            // Check if cancelled (user dismissed overlay)
            if !isProcessingVoice { return }
            
            isProcessingVoice = false // Done processing
            
            // Determine Intent
            let isRestock = response.intent == "restock"
            let intentEnum: SmartIntent = isRestock ? .restock : .order
            
            // Switch Mode
            if isRestock {
                if !isRestockMode {
                    self.isRestockMode = true
                    self.shouldShowRestockSheet = true
                } else {
                    self.shouldShowRestockSheet = true
                }
            } else {
                if isRestockMode {
                    self.isRestockMode = false
                    self.shouldShowOrderSheet = true
                } else {
                    self.shouldShowOrderSheet = true
                }
            }
            
            // Process Items
            for item in response.items {
                let tuple = (
                    name: item.name,
                    quantity: item.quantity,
                    price: item.price,
                    discount: item.discount,
                    discountIsPercent: item.discountIsPercent,
                    additionalCost: item.additionalCost,
                    isTotal: Optional(item.isTotal),
                    intent: Optional(intentEnum)
                )
                
                if isRestock {
                    handleRestockParsed(tuple)
                } else {
                    handleOrderParsed(tuple)
                }
            }
            
            currentInput = ""
            
        } catch {
            print("GPT Parsing Failed: \(error). Falling back to legacy.")
            isProcessingVoice = false
            processInputLegacy()
        }
    }

    func processInputLegacy() {
        let rawText = currentInput
        let lines = rawText.components(separatedBy: CharacterSet(charactersIn: ",\n"))
        
        for line in lines {
            if let parsed = SmartParser.parse(text: line) {
                // 1. Check Intent to possibly switch modes
                if let intent = parsed.intent {
                    if intent == .restock {
                        if !isRestockMode {
                            DispatchQueue.main.async { 
                                self.isRestockMode = true 
                                self.shouldShowRestockSheet = true
                            }
                        } else {
                             // Already in restock mode, but maybe sheet is closed?
                             DispatchQueue.main.async { self.shouldShowRestockSheet = true }
                        }
                        handleRestockParsed(parsed)
                        continue
                    } else if intent == .order {
                        if isRestockMode {
                            DispatchQueue.main.async { 
                                self.isRestockMode = false 
                                self.shouldShowOrderSheet = true
                            }
                        } else {
                            DispatchQueue.main.async { self.shouldShowOrderSheet = true }
                        }
                        handleOrderParsed(parsed)
                        continue
                    }
                }
                
                // 2. No explicit intent, use current mode
                if isRestockMode {
                    DispatchQueue.main.async { self.shouldShowRestockSheet = true }
                    handleRestockParsed(parsed)
                } else {
                    DispatchQueue.main.async { self.shouldShowOrderSheet = true }
                    handleOrderParsed(parsed)
                }
            }
        }
        
        currentInput = ""
    }
    
    private func handleOrderParsed(_ parsed: (name: String, quantity: Int, price: Double, discount: Double, discountIsPercent: Bool, additionalCost: Double, isTotal: Bool?, intent: SmartIntent?)) {
        var finalName = parsed.name
        var price = parsed.price
        var systemImage: String? = nil
        var costPrice: Double = 0
        var imageData: Data? = nil
        
        // Intelligent Mapping
        if let match = SmartParser.findBestMatch(name: parsed.name, in: products) {
            finalName = match.name
            systemImage = match.imageName
            costPrice = match.costPrice
            imageData = match.imageData
            
            if price == 0 {
                price = match.price
            }
        } else {
            // Fallback to history
            if price == 0 {
                if let historyPrice = priceHistory[parsed.name.lowercased()] {
                    price = historyPrice
                }
            }
        }
        
        // Calculate Discount Amount
        var finalDiscount = parsed.discount
        if parsed.discountIsPercent {
             // If price is 0, we can't calculate percentage discount yet. 
             // Ideally we should store the percentage, but OrderItem only has discount value.
             // For now, if price > 0, calculate it. If not, it might be 0.
             if price > 0 {
                 finalDiscount = price * (parsed.discount / 100.0)
             }
        }
        
        // Add item
        let item = OrderItem(name: finalName, quantity: parsed.quantity, price: price, costPrice: costPrice, discount: finalDiscount, imageData: imageData, systemImage: systemImage)
        
        // Update or append
        // Logic fix: Only merge if the user explicitly wants to add more. 
        // For voice input, usually it's a new request. 
        // But if the user says "2 coffee" then "1 coffee", they might expect 3.
        // HOWEVER, the bug report says "automatically multiple 3 times".
        // This might be due to UI triggering processInput multiple times or GPT returning multiple items?
        // Or maybe this merge logic is running too often?
        // Let's assume for now we want to merge if it's the exact same item.
        
        if let index = items.firstIndex(where: { $0.name == item.name && $0.price == item.price && $0.discount == item.discount && $0.systemImage == item.systemImage }) {
             // If coming from GPT, we should probably NOT merge automatically if it causes confusion, 
             // but merging is standard POS behavior.
             // The issue "multiply 3 times" suggests `quantity` is being tripled.
             // Check if `item.quantity` itself is already tripled? No, that's in GPT.
             // Check if this function is called 3 times?
             // If so, we need to debounce or prevent multiple calls.
             items[index].quantity += item.quantity
        } else {
            items.append(item)
        }
        
        // Update history
        if item.price > 0 {
            priceHistory[item.name.lowercased()] = item.price
            Task {
                try? await database.upsertPriceHistory(name: item.name.lowercased(), price: item.price)
            }
        }
    }
    
    private func handleRestockParsed(_ parsed: (name: String, quantity: Int, price: Double, discount: Double, discountIsPercent: Bool, additionalCost: Double, isTotal: Bool?, intent: SmartIntent?)) {
        var finalName = parsed.name
        
        if let match = SmartParser.findBestMatch(name: parsed.name, in: products) {
            finalName = match.name
        }
        
        var unitPrice: Double = 0
        var quantity = parsed.quantity
        let rawPrice = parsed.price
        
        if rawPrice > 0 {
            if let isTotal = parsed.isTotal {
                if isTotal {
                    unitPrice = rawPrice / Double(quantity)
                } else {
                    unitPrice = rawPrice
                }
            } else {
                if quantity == 1 {
                     unitPrice = rawPrice
                } else if rawPrice > 500_000 {
                    unitPrice = rawPrice / Double(quantity)
                } else {
                    unitPrice = rawPrice
                }
            }
        }
        
        // Discount in restock usually means discount from supplier
        // We can subtract it from unit price or treat as negative additional cost
        // Here we'll treat it as negative additional cost for simplicity in unit cost calc
        var discountValue = parsed.discount
        if parsed.discountIsPercent {
             if unitPrice > 0 {
                 discountValue = unitPrice * (parsed.discount / 100.0) * Double(quantity) // Total discount? Or per unit?
                 // Let's assume parsed.discount is total discount if we used total price logic, or unit discount if unit price.
                 // Actually, additionalCost is usually total for the batch.
                 // If percentage, it's usually on the total cost.
                 let totalBaseCost = unitPrice * Double(quantity)
                 discountValue = totalBaseCost * (parsed.discount / 100.0)
             }
        }
        
        // Include manually added additional cost (parsed.additionalCost)
        // Note: discountValue is treated as negative additional cost
        let totalAdditionalCost = parsed.additionalCost - discountValue
        
        restockItems.append(RestockItem(name: finalName, quantity: quantity, unitPrice: unitPrice, additionalCost: totalAdditionalCost))
    }
    
    func processRestockInput() {
        // Deprecated by processInput handling both, but kept for compatibility if called directly
        processInput()
    }
    
    func stockLevel(for name: String, isFinishedGood: Bool? = nil) -> Int {
        let searchName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let isFG = isFinishedGood {
            return inventory[self.getInventoryKey(name: searchName, isFinishedGood: isFG)] ?? 0
        }
        
        // Fallback for legacy calls without isFinishedGood parameter
        // Priority: Normal Good > Finished Good (usually sales are goods)
        if let goodStock = inventory[self.getInventoryKey(name: searchName, isFinishedGood: false)] {
            return goodStock
        }
        return inventory[self.getInventoryKey(name: searchName, isFinishedGood: true)] ?? 0
    }
    
    func materialStockLevel(for name: String) -> Int {
        let key = name.lowercased()
        if let m = materials.first(where: { $0.name.lowercased() == key }) {
            return m.stockQuantity
        }
        if let m = materialsInventory.first(where: { $0.name.lowercased() == key }) {
            return m.stockQuantity
        }
        return 0
    }
    
    func currentStockLevel(for name: String) -> Int {
        let key = name.lowercased()
        let ms = materialStockLevel(for: name)
        if ms > 0 { return ms }
        // Prefer runtime inventory cache if present
        if let inv = inventory[getInventoryKey(name: name, isFinishedGood: false)] {
            return inv
        }
        if let inv = inventory[getInventoryKey(name: name, isFinishedGood: true)] {
            return inv
        }
        // Fallback to product catalog stock (convert to grams for finished goods)
        if let p = products.first(where: { $0.name.lowercased() == key }) {
            return p.isFinishedGood ? (p.stockQuantity * 1000) : p.stockQuantity
        }
        return 0
    }
    
    func parseItem(from text: String) -> OrderItem? {
        // Use SmartParser for flexible "AI-like" parsing
        if let parsed = SmartParser.parse(text: text) {
            var finalName = parsed.name
            var price = parsed.price
            var systemImage: String? = nil
            var costPrice: Double = 0
            
            // 1. Try to find matching product in catalog (Intelligent Mapping)
            if let match = SmartParser.findBestMatch(name: parsed.name, in: products) {
                finalName = match.name
                systemImage = match.imageName
                costPrice = match.costPrice // Capture current Unit Cost
                
                // If price wasn't specified in speech, use catalog price
                if price == 0 {
                    price = match.price
                }
            } else {
                // 2. Fallback to history if not found in catalog
                if price == 0 {
                    if let historyPrice = priceHistory[parsed.name.lowercased()] {
                        price = historyPrice
                    }
                }
            }
            
            // Calculate Discount
            var finalDiscount = parsed.discount
            if parsed.discountIsPercent {
                if price > 0 {
                    finalDiscount = price * (parsed.discount / 100.0)
                }
            }
            
            return OrderItem(name: finalName, quantity: parsed.quantity, price: price, costPrice: costPrice, discount: finalDiscount, systemImage: systemImage)
        }
        return nil
    }
    
    func removeItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func checkStockWarnings() -> [String] {
        var warnings: [String] = []
        for item in items {
            let currentStock = stockLevel(for: item.name)
            if item.quantity > currentStock {
                warnings.append("⚠️ \(item.name): Đặt \(item.quantity), Kho còn \(currentStock)")
            }
        }
        return warnings
    }
    
    func completeOrder(isPaid: Bool) {
        // Create bill
        if let bill = makeBill(isPaid: isPaid) {
            pastOrders.insert(bill, at: 0) // Newest first
            lastCreatedBill = bill
            
            // Save Order to DB + gán STT đầy đủ sau khi lưu
            Task {
                do {
                    try await database.saveOrder(bill)
                    // Lấy N và cập nhật sequenceNumber với format đầy đủ
                    let n = await database.nextSequenceNumber(type: SequenceType.retailSale)
                    let fullStt = FormatUtils.buildSequenceNumber(type: SequenceType.retailSale, n: n)
                    var updated = bill
                    updated.sequenceNumber = fullStt
                    try? await database.updateOrder(updated)
                    await MainActor.run {
                        if let idx = pastOrders.firstIndex(where: { $0.id == bill.id }) {
                            pastOrders[idx].sequenceNumber = fullStt
                        }
                        lastCreatedBill?.sequenceNumber = fullStt
                    }
                } catch {
                    print("❌ Error saving order: \(error)")
                }
            }

            // Lưu khách hàng vào trading_parties nếu có tên thực
            let trimmedName = walkInName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = walkInPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty && trimmedName.lowercased() != "khách lẻ" {
                let capturedPhone = trimmedPhone
                let capturedAddress = walkInAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                let capturedEmail = walkInEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    // Reuse existing party id nếu đã có, tránh tạo bản ghi trùng
                    var existing = try? await database.fetchTradingPartyByNameOrPhone(trimmedName, capturedPhone, "buyer")
                    if existing == nil {
                        existing = try? await database.fetchTradingPartyByName(trimmedName, type: "buyer")
                    }
                    var party = existing ?? TradingParty(
                        id: UUID(),
                        partyType: "buyer",
                        name: trimmedName,
                        phone: capturedPhone,
                        address: capturedAddress,
                        totalDebt: 0
                    )
                    // Cập nhật thông tin mới nhất từ đơn hàng
                    party.name = trimmedName
                    if !capturedPhone.isEmpty { party.phone = capturedPhone }
                    if !capturedAddress.isEmpty { party.address = capturedAddress }
                    if !capturedEmail.isEmpty { party.email = capturedEmail }
                    party.updatedAt = Date()
                    try? await database.upsertTradingParty(party)
                }
            }
            
            // Deduct from Inventory
            for item in bill.items {
                let lowerName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                // Find product to determine if it's a finished good
                let product = products.first(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == lowerName })
                let isFG = product?.isFinishedGood ?? false
                let invKey = getInventoryKey(name: lowerName, isFinishedGood: isFG)
                
                if let current = inventory[invKey] {
                    let newQuantity = max(0, current - item.quantity)
                    inventory[invKey] = newQuantity
                    
                    // Update Product in DB
                    if var p = product {
                        p.stockQuantity = newQuantity
                        // Update in local array
                        if let index = products.firstIndex(where: { $0.id == p.id }) {
                            products[index] = p
                        }
                        
                        Task {
                            do {
                                try await database.updateProduct(p)
                            } catch {
                                print("❌ Error updating product stock: \(error)")
                            }
                        }
                    }
                }
            }
            
            // Update stats
                recalculateStats()
                
                // Show Success Toast
                DispatchQueue.main.async {
                    self.showOrderSuccessToast = true
                    // Hide after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showOrderSuccessToast = false
                    }
                }
            }
            
            // Clear order
        reset()
    }
    
    /// Chỉ fetch lại orders + edited IDs — nhẹ, dùng cho pull-to-refresh ở lịch sử đơn hàng
    func refreshOrders() async {
        guard let sid = StoreManager.shared.currentStore?.id else { return }
        do {
            let orders = try await database.fetchOrders()
            let ids = (try? await database.fetchEditedOrderIds(storeId: sid)) ?? []
            await MainActor.run {
                // Giữ nguyên các order đang được edit locally (tránh overwrite với DB cũ)
                let merged = orders.map { fetched -> Bill in
                    if self.locallyEditedOrderIds.contains(fetched.id),
                       let local = self.pastOrders.first(where: { $0.id == fetched.id }) {
                        return local
                    }
                    return fetched
                }
                self.pastOrders = merged
                self.editedOrderIds = Set(ids)
                self.recalculateStats()
            }
            print("✅ refreshOrders: loaded \(orders.count) orders")
        } catch {
            print("⚠️ refreshOrders error: \(error)")
        }
    }

    func recalculateStats() {
        // Global Stats
        revenue = pastOrders.filter { $0.isPaid && !$0.isDeleted }.reduce(0) { $0 + $1.total }
        orderCount = pastOrders.filter { !$0.isDeleted }.count
        
        // Total Restock Cost (Import Price + Fees)
        totalRestockCost = restockHistory.filter { !$0.isDeleted }.reduce(0) { $0 + $1.totalCost }
        
        // Total Operating Cost
        totalOperatingCost = operatingExpenses.reduce(0) { $0 + $1.amount }
        
        // Calculate Today's Stats
        calculateTodayStats()
    }
    
    func calculateTodayStats() {
        let service = FinancialReportService.shared
        let todayStatsList = service.generateReport(
            orders: pastOrders,
            expenses: operatingExpenses,
            restocks: restockHistory,
            range: .today
        )
        self.todayStats = todayStatsList.first
    }
    
    func exportFinancialReport(range: ReportDateRange, allProductionTx: [ProductionTransaction] = []) -> URL? {
        let service = FinancialReportService.shared
        let stats = service.generateReport(
            orders: pastOrders,
            expenses: operatingExpenses,
            restocks: restockHistory,
            range: range
        )
        let ws = wholesaleStats(for: range, allTransactions: allProductionTx)
        return service.exportToCSV(stats: stats, wholesale: ws)
    }
    
    // MARK: - Operating Expenses
    func addOperatingExpense(title: String, amount: Double, note: String?) {
        var expense = OperatingExpense(id: UUID(), title: title, amount: amount, note: note, createdAt: Date())
        expense.creatorId = AuthManager.shared.currentUserProfile?.id
        expense.creatorName = AuthManager.shared.currentUserProfile?.fullName
        
        // Optimistic UI update
        operatingExpenses.insert(expense, at: 0)
        recalculateStats()
        
        Task {
            do {
                try await database.saveOperatingExpense(expense)
            } catch {
                print("❌ Error saving expense: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Không thể lưu chi phí: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    // Revert optimistic update
                    if let index = self.operatingExpenses.firstIndex(where: { $0.id == expense.id }) {
                        self.operatingExpenses.remove(at: index)
                        self.recalculateStats()
                    }
                }
            }
        }
    }
    
    func updateOperatingExpense(_ expense: OperatingExpense) {
        // Optimistic UI update
        if let index = operatingExpenses.firstIndex(where: { $0.id == expense.id }) {
            let oldExpense = operatingExpenses[index]
            operatingExpenses[index] = expense
            recalculateStats()
            
            Task {
                do {
                    try await database.updateOperatingExpense(expense)
                } catch {
                    print("❌ Error updating expense: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Không thể cập nhật chi phí: \(error.localizedDescription)"
                        self.showErrorAlert = true
                        // Revert
                        if let idx = self.operatingExpenses.firstIndex(where: { $0.id == expense.id }) {
                            self.operatingExpenses[idx] = oldExpense
                            self.recalculateStats()
                        }
                    }
                }
            }
        }
    }
    
    func deleteOperatingExpense(_ expense: OperatingExpense) {
        if let index = operatingExpenses.firstIndex(where: { $0.id == expense.id }) {
            operatingExpenses.remove(at: index)
            recalculateStats()
            
            Task {
                do {
                    try await database.deleteOperatingExpense(expense.id)
                } catch {
                    print("❌ Error deleting expense: \(error)")
                }
            }
        }
    }
    
    // MARK: - Restock Actions
    
    func addRestockItem(_ name: String, unitPrice: Double, quantity: Int, additionalCost: Double = 0, suggestedPrice: Double? = nil, category: String? = nil, source: String? = nil, documentImageURL: String? = nil, weightPerUnitGrams: Int? = nil, isFinishedGood: Bool = false, importFromFinishedGood: Bool = false, sourceFinishedGoodId: UUID? = nil, unit: String? = nil, hasVAT: Bool = false) {
        restockItems.append(
            RestockItem(
                name: name,
                quantity: quantity,
                unitPrice: unitPrice,
                additionalCost: additionalCost,
                suggestedPrice: suggestedPrice,
                isConfirmed: false,
                category: category,
                source: source,
                documentImageURL: documentImageURL,
                weightPerUnitGrams: weightPerUnitGrams,
                isFinishedGood: isFinishedGood,
                importFromFinishedGood: importFromFinishedGood,
                sourceFinishedGoodId: sourceFinishedGoodId,
                unit: unit,
                hasVAT: hasVAT
            )
        )
    }

    func sourceHistory(for itemName: String) -> [String] {
        let key = itemName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return [] }
        
        var seen = Set<String>()
        var result: [String] = []
        
        for bill in restockHistory {
            for it in bill.items {
                if it.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != key { continue }
                let s = it.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if s.isEmpty { continue }
                let k = s.lowercased()
                if seen.contains(k) { continue }
                seen.insert(k)
                result.append(s)
            }
        }
        
        for tx in productionHistory {
            for it in tx.items {
                if it.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != key { continue }
                let s = it.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if s.isEmpty { continue }
                let k = s.lowercased()
                if seen.contains(k) { continue }
                seen.insert(k)
                result.append(s)
            }
        }
        
        return result
    }
    
    func latestSource(for itemName: String) -> String? {
        return sourceHistory(for: itemName).first
    }
    
    func removeRestockItem(at offsets: IndexSet) {
        restockItems.remove(atOffsets: offsets)
    }
    
    func updateRestockItem(_ item: RestockItem) {
        if let index = restockItems.firstIndex(where: { $0.id == item.id }) {
            restockItems[index] = item
        }
    }
    
    func toggleRestockItemConfirmation(_ item: RestockItem) {
        if let index = restockItems.firstIndex(where: { $0.id == item.id }) {
            restockItems[index].isConfirmed.toggle()
        }
    }
    
    func completeRestockSession() {
        print("🔍 [DEBUG] completeRestockSession() called! Will save to restock_bills table!")
        guard !restockItems.isEmpty else { return }
        
        let total = restockItems.reduce(0) { $0 + $1.totalCost }
        let original = editingRestockBill
        let billId = original?.id ?? UUID()
        let createdAt = original?.createdAt ?? Date()
        var bill = RestockBill(id: billId, createdAt: createdAt, items: restockItems, totalCost: total)
        bill.sequenceNumber = currentSequenceNumber ?? FormatUtils.generateSequenceNumber()
        
        // Reset STT ngay lập tức để đơn tiếp theo có STT mới
        currentSequenceNumber = nil
        
        // Snapshot trước khi clear (phải làm trước khi gán cho bill)
        let itemsSnapshot = restockItems
        let exportInfoSnapshot = pendingExportInfo
        
        bill.creatorId = original?.creatorId ?? AuthManager.shared.currentUserProfile?.id
        bill.creatorName = original?.creatorName ?? AuthManager.shared.currentUserProfile?.fullName
        
        if let original = original {
            bill.supplierName = original.supplierName
            bill.supplierPhone = original.supplierPhone
            bill.supplierAddress = original.supplierAddress
            bill.note = original.note
        } else if let info = exportInfoSnapshot {
            bill.supplierName = info.buyerName
            bill.supplierPhone = info.buyerPhone
            bill.supplierAddress = info.buyerAddress
            bill.note = info.note
        }
        
        pendingExportNote = nil
        pendingExportPaymentReceiptURL = nil
        pendingExportInfo = nil
        
                Task { @MainActor in
            do {
                if let original {
                    await revertInventoryForRestockBill(original)
                }
                
                await applyInventoryForRestockItems(restockItems)
                
                if let idx = restockHistory.firstIndex(where: { $0.id == bill.id }) {
                    restockHistory[idx] = bill
                } else {
                    restockHistory.insert(bill, at: 0)
                }
                
                if original != nil {
                    try await database.updateRestockBill(bill)
                    let didSaveEdit = await addRestockEditHistory(for: original!, updated: bill)
                    if didSaveEdit {
                        editedRestockBillIds.insert(bill.id)
                    }
                } else {
                    print("🔍 [DEBUG] About to call database.saveRestockBill with bill.id = \(bill.id)")
                    try await database.saveRestockBill(bill)
                    // Gán STT đầy đủ NBL — chỉ fetch N nếu STT chưa có suffix type
                    let existingSTT = bill.sequenceNumber ?? ""
                    let hasFullSTT = existingSTT.components(separatedBy: "-").count >= 4
                    let fullStt: String
                    if hasFullSTT {
                        fullStt = existingSTT
                    } else {
                        let n = await database.nextSequenceNumber(type: SequenceType.retailRestock)
                        fullStt = FormatUtils.buildSequenceNumber(type: SequenceType.retailRestock, n: n)
                    }
                    var updatedBill = bill
                    updatedBill.sequenceNumber = fullStt
                    try? await database.updateRestockBill(updatedBill)
                    if let idx = restockHistory.firstIndex(where: { $0.id == bill.id }) {
                        restockHistory[idx].sequenceNumber = fullStt
                    }
                    
                    // Tạo ProductionTransaction "Xuất Thành Phẩm" cho các item là thành phẩm hoặc nhập từ thành phẩm
                    var exportTxItems: [RestockItem] = []
                    
                    // Trường hợp 1: Nhập hàng hoá TỪ thành phẩm nguồn (importFromFinishedGood == true)
                    let importFromFGItems = itemsSnapshot.filter { $0.importFromFinishedGood && $0.source != nil }
                    for it in importFromFGItems {
                        if let sourceName = it.source, let gramsPerUnit = it.weightPerUnitGrams, gramsPerUnit > 0 {
                            let totalGrams = it.quantity * gramsPerUnit
                            let sourceProduct = products.first(where: { $0.name.lowercased() == sourceName.lowercased() && $0.isFinishedGood })
                            
                            var exportItem = RestockItem(
                                name: sourceName,
                                quantity: totalGrams,
                                unitPrice: sourceProduct?.costPrice ?? 0,
                                category: Category.materials.rawValue, // Để xử lý tính toán gram/kg
                                source: "Xuất để nhập hàng: \(it.name)",
                                isFinishedGood: true
                            )
                            exportItem.isConfirmed = true
                            exportTxItems.append(exportItem)
                        }
                    }
                    
                    // Trường hợp 2: Item bản thân là thành phẩm (giữ logic cũ)
                    let directFGItems = itemsSnapshot.filter { item in
                        if item.importFromFinishedGood { return false } // Đã xử lý ở trên
                        if item.isFinishedGood { return true }
                        return products.first(where: { $0.name.lowercased() == item.name.lowercased() })?.isFinishedGood == true
                    }
                    for it in directFGItems {
                        var exportItem = it
                        exportItem.isFinishedGood = true
                        exportItem.isConfirmed = true
                        exportTxItems.append(exportItem)
                    }

                    if !exportTxItems.isEmpty {
                        var fgTotal = 0.0
                        for it in exportTxItems {
                            let stockDelta = it.weightPerUnitGrams != nil ? Double(it.weightPerUnitGrams! * it.quantity) : Double(it.quantity)
                            let price = it.suggestedPrice ?? it.unitPrice
                            fgTotal += stockDelta / 1000.0 * price
                        }
                        
                        var exportTx = ProductionTransaction(
                            id: UUID(),
                            createdAt: Date(),
                            mode: "Xuất Thành Phẩm",
                            items: exportTxItems,
                            totalCost: fgTotal
                        )
                        exportTx.sequenceNumber = FormatUtils.generateSequenceNumber()
                        exportTx.creatorId = AuthManager.shared.currentUserProfile?.id
                        exportTx.creatorName = AuthManager.shared.currentUserProfile?.fullName
                        exportTx.note = "Xuất sang kho hàng hoá từ phiếu nhập #\(bill.id.uuidString.prefix(6))"
                        
                        if let info = exportInfoSnapshot {
                            exportTx.buyerName = info.buyerName
                            exportTx.buyerPhone = info.buyerPhone
                            exportTx.buyerAddress = info.buyerAddress
                            exportTx.buyerTaxCode = info.buyerTaxCode
                            exportTx.grandTotal = info.grandTotal
                            exportTx.paidAmount = info.paidAmount
                            exportTx.debtAmount = info.debtAmount
                            exportTx.vatRate = info.vatRate
                            exportTx.vatAmount = info.vatAmount
                            exportTx.isPaid = info.isPaid
                            exportTx.expectedPayDate = info.expectedPayDate
                            exportTx.paymentReceiptURL = info.paymentReceiptURL
                        }
                        
                        do {
                            try await database.saveProductionTransaction(exportTx)
                            // Gán STT XTP
                            let n = await database.nextSequenceNumber(type: SequenceType.finishedExport)
                            let fullStt = FormatUtils.buildSequenceNumber(type: SequenceType.finishedExport, n: n)
                            var updatedTx = exportTx
                            updatedTx.sequenceNumber = fullStt
                            try? await database.updateProductionTransaction(updatedTx)
                            await loadProductionHistory(mode: "Xuất Thành Phẩm")
                            print("✅ Saved finished goods export tx for \(exportTxItems.count) items")
                        } catch {
                            print("❌ Error saving FG export tx: \(error)")
                        }
                    }
                }
                
                // Success - clean up
                editingRestockBill = nil
                await loadProducts() // Ensure everything is in sync
                
                // Reload restock history from database to ensure latest
                do {
                    let freshRestocks = try await database.fetchRestockHistory()
                    await MainActor.run {
                        self.restockHistory = freshRestocks
                    }
                    print("🔄 [OrderViewModel] Successfully reloaded restockHistory from DB! Count: \(freshRestocks.count)")
                } catch {
                    print("❌ [OrderViewModel] Failed to reload restockHistory from DB: \(error)")
                }
                
                recalculateStats()
                restockItems.removeAll()
                isRestockMode = false
                
            } catch {
                print("❌ Error saving restock bill: \(error)")
                self.databaseError = "Lỗi lưu phiếu: \(error.localizedDescription)"
                
                // On failure, we don't clear restockItems so the user can try again
                // But we might need to revert the in-memory inventory changes if they were applied
                // However, for simplicity now, we just notify the user.
            }
        }
    }
    
    // MARK: - Restock Editing/Deleting
    func deleteRestockBill(_ bill: RestockBill) {
        Task { @MainActor in
            await deleteRestockBillForEditing(bill)
        }
    }
    
    @MainActor
    func softDeleteRestockBill(_ bill: RestockBill) async {
        guard !bill.isDeleted else { return }
        
        let deletedAt = Date()
        let deletedBy = AuthManager.shared.currentUserProfile?.id
        
        var affectedKeys = Set<String>()
        
        await revertInventoryForRestockBill(bill)
        for item in bill.items { affectedKeys.insert(item.name.lowercased()) }
        
        if let index = restockHistory.firstIndex(where: { $0.id == bill.id }) {
            var updated = restockHistory[index]
            updated.isDeleted = true
            updated.deletedAt = deletedAt
            updated.deletedBy = deletedBy
            restockHistory[index] = updated
        }
        
        for key in affectedKeys {
            await recomputeProductPricingAfterRestockChange(productKey: key)
        }
        
        do {
            try await database.softDeleteRestockBill(bill.id, deletedAt: deletedAt, deletedBy: deletedBy)
        } catch {
            print("❌ Error soft deleting restock bill: \(error)")
        }
        
        recalculateStats()
    }
    
    @MainActor
    private func deleteRestockBillForEditing(_ bill: RestockBill) async {
        if let index = restockHistory.firstIndex(where: { $0.id == bill.id }) {
            await revertInventoryForRestockBill(bill)
            
            restockHistory.remove(at: index)
            
            do {
                try await database.deleteRestockBill(bill.id)
            } catch {
                print("❌ Error deleting restock bill: \(error)")
            }
            
            recalculateStats()
        }
    }
    
    @MainActor
    private func recomputeProductPricingAfterRestockChange(productKey: String) async {
        guard let pIndex = products.firstIndex(where: { $0.name.lowercased() == productKey }) else { return }
        
        // Lấy finalUnitCost của lần nhập gần nhất (không bị xóa)
        let sortedBills = restockHistory
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt } // mới nhất trước
        
        var latestItem: RestockItem?
        var latestSuggestedPrice: Double? = nil
        
        for bill in sortedBills {
            if let match = bill.items.first(where: { $0.name.lowercased() == productKey }) {
                latestItem = match
                latestSuggestedPrice = match.suggestedPrice
                break
            }
        }
        
        var p = products[pIndex]
        if let latestItem {
            p.costPrice = latestItem.finalUnitCost
            if let suggested = latestSuggestedPrice {
                p.price = suggested
            }
        } else {
            p.costPrice = 0
        }
        
        products[pIndex] = p
        do { try await database.updateProduct(p) } catch { print("❌ Error recomputing product pricing: \(error)") }
    }

    @MainActor
    private func revertInventoryForRestockBill(_ bill: RestockBill) async {
        for item in bill.items {
            let lowerName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Revert deduction from source finished good if applicable
            if let gramsPerUnit = item.weightPerUnitGrams, gramsPerUnit > 0,
               let sourceName = item.source?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
               let sourceIndex = products.firstIndex(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == sourceName && $0.isFinishedGood }) {
                
                let deltaGrams = item.quantity * gramsPerUnit
                var sourceProduct = products[sourceIndex]
                sourceProduct.stockQuantity = max(0, sourceProduct.stockQuantity + deltaGrams)
                products[sourceIndex] = sourceProduct
                let sourceKey = getInventoryKey(name: sourceName, isFinishedGood: true)
                inventory[sourceKey] = sourceProduct.stockQuantity
                do { try await database.updateProduct(sourceProduct) } catch { print("❌ Error reverting source product stock: \(error)") }
            }
            // 2. Handle legacy deduction logic (backward compatibility)
            else if let gramsPerUnit = item.weightPerUnitGrams,
                    let pIndex = products.firstIndex(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == lowerName && $0.isFinishedGood }) {
                if gramsPerUnit > 0 {
                    let deltaGrams = item.quantity * gramsPerUnit
                    var p = products[pIndex]
                    p.stockQuantity = max(0, p.stockQuantity + deltaGrams)
                    products[pIndex] = p
                    let invKey = getInventoryKey(name: lowerName, isFinishedGood: true)
                    inventory[invKey] = p.stockQuantity
                    do { try await database.updateProduct(p) } catch { print("❌ Error reverting product stock: \(error)") }
                }
                continue
            }
            
            let invKey = getInventoryKey(name: lowerName, isFinishedGood: item.isFinishedGood)
            let current = inventory[invKey] ?? 0
            let newQuantity = max(0, current - item.quantity)
            inventory[invKey] = newQuantity
            
            if let pIndex = products.firstIndex(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == lowerName && $0.isFinishedGood == item.isFinishedGood }) {
                var p = products[pIndex]
                p.stockQuantity = newQuantity
                products[pIndex] = p
                do {
                    print("📦 [OrderViewModel] Reverting target product stock: \(p.name), type: \(p.isFinishedGood ? "FG" : "Good")")
                    try await database.updateProduct(p)
                } catch {
                    print("❌ Error reverting product stock: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func revertInventoryForBill(_ bill: Bill) async {
        for item in bill.items {
            let lowerName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let product = products.first(where: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == lowerName })
            let isFG = product?.isFinishedGood ?? false
            let invKey = getInventoryKey(name: lowerName, isFinishedGood: isFG)
            
            if let current = inventory[invKey] {
                let newQuantity = current + item.quantity
                inventory[invKey] = newQuantity
                
                if var p = product {
                    p.stockQuantity = newQuantity
                    if let index = products.firstIndex(where: { $0.id == p.id }) {
                        products[index] = p
                    }
                    
                    do {
                        print("📦 [OrderViewModel] Reverting sales order product stock: \(p.name), type: \(p.isFinishedGood ? "FG" : "Good")")
                        try await database.updateProduct(p)
                    } catch {
                        print("❌ Error reverting product stock for sales order: \(error)")
                    }
                }
            }
        }
    }
    
    @MainActor
    private func applyInventoryForRestockItems(_ items: [RestockItem]) async {
        for item in items {
            let key = item.name.lowercased()
            
            // 1. Handle deduction from source finished good if applicable
            if let gramsPerUnit = item.weightPerUnitGrams, gramsPerUnit > 0,
               let sourceName = item.source?.lowercased(),
               let sourceIndex = products.firstIndex(where: { $0.name.lowercased() == sourceName && $0.isFinishedGood }) {
                
                let deltaGrams = item.quantity * gramsPerUnit
                var sourceProduct = products[sourceIndex]
                
                // CRITICAL: Protect the source product from being converted if it has the same name as the target
                sourceProduct.stockQuantity = max(0, sourceProduct.stockQuantity - deltaGrams)
                
                products[sourceIndex] = sourceProduct
                let sourceKey = self.getInventoryKey(name: sourceProduct.name, isFinishedGood: true)
                inventory[sourceKey] = sourceProduct.stockQuantity
                do {
                    print("📦 [OrderViewModel] Deducting source FG stock for: \(sourceProduct.name)")
                    try await database.updateProduct(sourceProduct)
                } catch {
                    print("❌ Error updating source product from restock: \(error)")
                }
            }
            // 2. Handle legacy deduction logic (backward compatibility)
            else if let gramsPerUnit = item.weightPerUnitGrams,
                    let index = products.firstIndex(where: { $0.name.lowercased() == key && $0.isFinishedGood }),
                    products[index].isFinishedGood {
                if gramsPerUnit > 0 {
                    let deltaGrams = item.quantity * gramsPerUnit
                    var product = products[index]
                    product.stockQuantity = max(0, product.stockQuantity - deltaGrams)
                    products[index] = product
                    let fgKey = self.getInventoryKey(name: product.name, isFinishedGood: true)
                    inventory[fgKey] = product.stockQuantity
                    do {
                        print("📦 [OrderViewModel] Deducting legacy FG stock for: \(product.name)")
                        try await database.updateProduct(product)
                    } catch {
                        print("❌ Error updating product from restock: \(error)")
                    }
                }
            }
            
            let currentInvKey = self.getInventoryKey(name: item.name, isFinishedGood: item.isFinishedGood)
            let currentQuantity = inventory[currentInvKey] ?? 0
            let newQuantity = currentQuantity + item.quantity
            inventory[currentInvKey] = newQuantity
            
            if let index = products.firstIndex(where: { $0.name.lowercased() == key && $0.isFinishedGood == item.isFinishedGood }) {
                var product = products[index]
                // Giá vốn = giá nhập gồm chi phí của lần nhập này (finalUnitCost = (unitPrice * qty + additionalCost) / qty)
                product.costPrice = item.finalUnitCost
                product.stockQuantity = newQuantity
                product.hasVAT = item.hasVAT
                
                // Keep the type intended (Normal or FG)
                product.isFinishedGood = item.isFinishedGood
                
                if let suggested = item.suggestedPrice {
                    product.price = suggested
                }
                
                if let newCat = item.category, !newCat.isEmpty, product.category != newCat {
                    product.category = newCat
                    self.productCategories.insert(newCat)
                }
                
                products[index] = product
                do {
                    print("✅ [OrderViewModel] Updating target product: \(product.name), stock: \(product.stockQuantity), type: \(product.isFinishedGood ? "FG" : "Good")")
                    try await database.updateProduct(product)
                } catch {
                    print("❌ Error updating product from restock: \(error)")
                }
            } else {
                let catValue: String = item.category ?? {
                    var cat: Category = .others
                    if key.contains("flower") || key.contains("hoa") || key.contains("hồng") {
                        cat = .flowers
                    } else if key.contains("giấy") || key.contains("nơ") || key.contains("ribbon") {
                        cat = .accessories
                    }
                    return cat.rawValue
                }()
                
                let newProduct = Product(
                    id: UUID(),
                    name: item.name,
                    price: item.suggestedPrice ?? (item.finalUnitCost * 1.3),
                    productPrice: item.finalUnitCost,
                    shippingCost: 0,
                    costPrice: item.finalUnitCost,
                    category: catValue,
                    imageName: "shippingbox.fill",
                    color: "gray",
                    stockQuantity: newQuantity,
                    isFinishedGood: item.isFinishedGood,
                    hasVAT: item.hasVAT
                )
                products.append(newProduct)
                self.productCategories.insert(catValue)
                do {
                    print("🆕 [OrderViewModel] Saving new product from restock: \(newProduct.name)")
                    try await database.saveProduct(newProduct)
                } catch {
                    print("❌ Error saving new product from restock: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func addRestockEditHistory(for original: RestockBill, updated: RestockBill) async -> Bool {
        let entryId = UUID()
        let editorId = AuthManager.shared.currentUserProfile?.id
        let editorName = AuthManager.shared.currentUserProfile?.fullName
        let note = "Đã chỉnh sửa phiếu nhập"
        let details = buildRestockEditDetails(original: original, updated: updated)
        if Int(original.totalCost) == Int(updated.totalCost) && details.isEmpty {
            return false
        }
        let edit = RestockEdit(
            id: entryId,
            restockBillId: original.id,
            createdAt: Date(),
            oldTotal: original.totalCost,
            newTotal: updated.totalCost,
            editorId: editorId,
            editorName: editorName,
            note: note,
            details: details
        )
        do {
            try await database.saveRestockEdit(edit)
            return true
        } catch {
            print("❌ Error saving restock edit history: \(error)")
            return false
        }
    }
    
    private func buildRestockEditDetails(original: RestockBill, updated: RestockBill) -> [String] {
        var lines: [String] = []
        let oldMap = Dictionary(uniqueKeysWithValues: original.items.map { ($0.name.lowercased(), $0) })
        let newMap = Dictionary(uniqueKeysWithValues: updated.items.map { ($0.name.lowercased(), $0) })
        let keys = Set(oldMap.keys).union(newMap.keys)
        
        for k in keys.sorted() {
            let o = oldMap[k]
            let n = newMap[k]
            if o == nil, let n {
                lines.append("Thêm \(n.name)")
                continue
            }
            if n == nil, let o {
                lines.append("Xóa \(o.name)")
                continue
            }
            guard let o, let n else { continue }
            if o.quantity != n.quantity {
                lines.append("\(n.name): SL \(o.quantity) → \(n.quantity)")
            }
            if Int(o.unitPrice) != Int(n.unitPrice) {
                lines.append("\(n.name): Giá \(Int(o.unitPrice)) → \(Int(n.unitPrice))")
            }
            if Int(o.additionalCost) != Int(n.additionalCost) {
                lines.append("\(n.name): Phí \(Int(o.additionalCost)) → \(Int(n.additionalCost))")
            }
            let oldSrc = o.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let newSrc = n.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if oldSrc.lowercased() != newSrc.lowercased(), !(oldSrc.isEmpty && newSrc.isEmpty) {
                lines.append("\(n.name): Nguồn \(oldSrc.isEmpty ? "—" : oldSrc) → \(newSrc.isEmpty ? "—" : newSrc)")
            }
        }
        
        return lines
    }
    
    func fetchRestockEdits(restockBillId: UUID) async throws -> [RestockEdit] {
        try await database.fetchRestockEdits(restockBillId: restockBillId)
    }

    func loadAutoMaterialExportTemplates() async {
        guard let sid = StoreManager.shared.currentStore?.id else { return }
        do {
            let templates = try await database.fetchAutoMaterialExportTemplates(storeId: sid)
            await MainActor.run {
                self.autoMaterialExportTemplates = templates
            }
        } catch {
            print("⚠️ loadAutoMaterialExportTemplates error: \(error)")
        }
    }
    
    func loadEditedProductionTxIds() async {
        guard let sid = StoreManager.shared.currentStore?.id else { return }
        do {
            let ids = try await database.fetchEditedProductionTransactionIds(storeId: sid)
            await MainActor.run {
                self.editedProductionTxIds = Set(ids)
            }
        } catch {
            print("⚠️ loadEditedProductionTxIds error: \(error)")
        }
    }
    
    func upsertAutoMaterialExportTemplate(_ template: AutoMaterialExportTemplate) async -> Bool {
        do {
            try await database.upsertAutoMaterialExportTemplate(template)
            await loadAutoMaterialExportTemplates()
            return true
        } catch {
            print("❌ upsertAutoMaterialExportTemplate error: \(error)")
            return false
        }
    }
    
    func deleteAutoMaterialExportTemplate(id: UUID) async {
        do {
            try await database.deleteAutoMaterialExportTemplate(id: id)
            await loadAutoMaterialExportTemplates()
        } catch {
            print("❌ deleteAutoMaterialExportTemplate error: \(error)")
        }
    }
    
    func fetchAutoMaterialExportLogsForTransaction(transactionId: UUID) async -> [AutoMaterialExportLog] {
        guard let sid = StoreManager.shared.currentStore?.id else { return [] }
        do {
            return try await database.fetchAutoMaterialExportLogsForTransaction(storeId: sid, transactionId: transactionId)
        } catch {
            print("⚠️ fetchAutoMaterialExportLogsForTransaction error: \(error)")
            return []
        }
    }
    
    func fetchAutoMaterialExportLogs(limit: Int) async -> [AutoMaterialExportLog] {
        guard let sid = StoreManager.shared.currentStore?.id else { return [] }
        do {
            return try await database.fetchAutoMaterialExportLogs(storeId: sid, limit: limit)
        } catch {
            print("⚠️ fetchAutoMaterialExportLogs error: \(error)")
            return []
        }
    }
    
    func fetchProductionTransactions(mode: String) async -> [ProductionTransaction] {
        do {
            return try await database.fetchProductionTransactions(mode: mode)
        } catch {
            print("⚠️ fetchProductionTransactions(\(mode)) error: \(error)")
            return []
        }
    }
    
    func fetchMaterials() async -> [MaterialItem] {
        do {
            return try await database.fetchMaterials()
        } catch {
            print("⚠️ fetchMaterials error: \(error)")
            return []
        }
    }
    
    @MainActor
    func performAutoMaterialExport(
        mode: String,
        templateId: UUID?,
        templateName: String,
        headerName: String,
        freshTitle: String,
        afterBoilTitle: String,
        panCountTitle: String,
        panWeightTitle: String,
        autoMaterialsTitle: String,
        freshRows: [AutoMaterialExportLogRow],
        afterBoilGrams: Int,
        panCount: Int,
        standardPanWeightGrams: Int,
        actualPanWeightGrams: Double,
        percentChange: Double,
        autoRows: [AutoMaterialExportLogRow],
        extraPanRows: [AutoMaterialExportLogRow] = [],
        subSheetSlips: [SubSheetSlipForLog] = [],
        resolvedSequenceNumber: String? = nil
    ) async -> Bool {
        var totalsByName: [String: Int] = [:]
        for r in freshRows {
            let g = Int(max(0, r.totalExportGrams.rounded()))
            totalsByName[r.name] = (totalsByName[r.name] ?? 0) + g
        }
        for r in autoRows {
            let g = Int(max(0, r.totalExportGrams.rounded()))
            totalsByName[r.name] = (totalsByName[r.name] ?? 0) + g
        }
        // Cộng thêm phần xào thêm
        for r in extraPanRows {
            let g = Int(max(0, r.totalExportGrams.rounded()))
            totalsByName[r.name] = (totalsByName[r.name] ?? 0) + g
        }
        // Cộng từ sub-sheets nếu có
        for slip in subSheetSlips {
            for r in slip.autoRows {
                let g = Int(max(0, r.totalExportGrams.rounded()))
                totalsByName[r.name] = (totalsByName[r.name] ?? 0) + g
            }
            for r in slip.extraPanRows {
                let g = Int(max(0, r.totalExportGrams.rounded()))
                totalsByName[r.name] = (totalsByName[r.name] ?? 0) + g
            }
        }
        let now = Date()
        let txId = UUID()
        let items: [RestockItem] = totalsByName.keys.sorted().compactMap { nameKey in
            let grams = totalsByName[nameKey] ?? 0
            guard grams > 0 else { return nil }
            let matched = self.materials.first(where: { $0.name.lowercased() == nameKey.lowercased() })
            let unitPrice = matched?.lastUnitPrice ?? 0
            return RestockItem(
                id: UUID(),
                name: matched?.name ?? nameKey,
                quantity: grams,
                unitPrice: unitPrice,
                additionalCost: 0,
                suggestedPrice: nil,
                isConfirmed: true,
                category: matched?.category ?? Category.materials.rawValue,
                source: templateName,
                documentImageURL: nil,
                unit: matched?.unit
            )
        }
        guard !items.isEmpty else { return false }
        
        let totalCost = items.reduce(0) { $0 + $1.totalCost }
        let note = "Xuất tự động: \(templateName)"
        var tx = ProductionTransaction(id: txId, createdAt: now, mode: mode, items: items, totalCost: totalCost, note: note)
        tx.sequenceNumber = resolvedSequenceNumber ?? FormatUtils.generateSequenceNumber()
        tx.creatorId = AuthManager.shared.currentUserProfile?.id
        tx.creatorName = AuthManager.shared.currentUserProfile?.fullName
        
        do {
            try await database.saveProductionTransaction(tx)
            // Gán STT đầy đủ — chỉ fetch N nếu chưa có STT đầy đủ từ trước
            let fullStt: String
            if let resolved = resolvedSequenceNumber {
                fullStt = resolved
            } else {
                let seqType = sequenceType(for: mode)
                let n = await database.nextSequenceNumber(type: seqType)
                fullStt = FormatUtils.buildSequenceNumber(type: seqType, n: n)
            }
            var updatedTx = tx
            updatedTx.sequenceNumber = fullStt
            try? await database.updateProductionTransaction(updatedTx)
            await upsertMaterialsFromTransaction(tx)
            await loadMaterials()
            await loadProductionHistory(mode: mode)
        } catch {
            print("❌ performAutoMaterialExport saveProductionTransaction error: \(error)")
            return false
        }
        
        let data = AutoMaterialExportLogData(
            headerName: headerName,
            freshTitle: freshTitle,
            afterBoilTitle: afterBoilTitle,
            panCountTitle: panCountTitle,
            panWeightTitle: panWeightTitle,
            autoMaterialsTitle: autoMaterialsTitle,
            fresh: freshRows,
            afterBoilGrams: afterBoilGrams,
            panCount: panCount,
            standardPanWeightGrams: standardPanWeightGrams,
            actualPanWeightGrams: actualPanWeightGrams,
            percentChange: percentChange,
            autoMaterials: autoRows,
            subSheetLogs: subSheetSlips.map { slip in
                SubSheetLogData(
                    name: slip.name,
                    afterBoilGrams: slip.afterBoilGrams,
                    panCount: slip.panCount,
                    standardPanWeightGrams: slip.standardPanWeightGrams,
                    actualPanWeightGrams: slip.actualPanWeightGrams,
                    autoMaterials: slip.autoRows,
                    extraPanRows: slip.extraPanRows
                )
            }
        )
        var log = AutoMaterialExportLog(
            id: UUID(),
            createdAt: now,
            templateId: templateId,
            templateName: templateName,
            productionTransactionId: txId,
            data: data
        )
        log.creatorId = AuthManager.shared.currentUserProfile?.id
        log.creatorName = AuthManager.shared.currentUserProfile?.fullName
        do {
            try await database.saveAutoMaterialExportLog(log)
        } catch {
            print("⚠️ performAutoMaterialExport saveAutoMaterialExportLog error: \(error)")
        }
        
        return true
    }
    
    func editRestockBill(_ bill: RestockBill) {
        editingRestockBill = bill
        restockItems = bill.items
        isRestockMode = true
        shouldShowRestockSheet = true
    }

    func cancelRestockEditingIfNeeded() {
        if editingRestockBill != nil {
            editingRestockBill = nil
            restockItems.removeAll()
        }
    }
    
    // MARK: - Production Management
    func completeProductionTransaction(mode: String) {
        print("🔍 [DEBUG] completeProductionTransaction() called! Will save to production_transactions table! mode = '\(mode)'")
        guard !restockItems.isEmpty else { return }
        let total: Double
        if mode == "Xuất Thành Phẩm" {
            total = restockItems.reduce(0) { sum, item in
                let isLegacyGramAsCai = item.unit?.lowercased() == "cái" && item.quantity >= 1000
                let isCai = item.unit?.lowercased() == "cái" && !isLegacyGramAsCai
                let price = item.suggestedPrice ?? item.unitPrice
                if isCai {
                    return sum + Double(item.quantity) * price + item.additionalCost
                } else {
                    return sum + Double(item.quantity) / 1000.0 * price + item.additionalCost
                }
            }
        } else {
            total = restockItems.reduce(0) { $0 + $1.totalCost }
        }
        var tx = ProductionTransaction(id: UUID(), createdAt: Date(), mode: mode, items: restockItems, totalCost: total)
        tx.sequenceNumber = currentSequenceNumber ?? FormatUtils.generateSequenceNumber()
        
        // Reset STT ngay lập tức
        currentSequenceNumber = nil
        
        tx.creatorId = AuthManager.shared.currentUserProfile?.id
        tx.creatorName = AuthManager.shared.currentUserProfile?.fullName
        if let note = pendingExportNote {
            tx.note = note
        }
        // Apply pending export info
        if let info = pendingExportInfo {
            tx.buyerName = info.buyerName
            tx.buyerPhone = info.buyerPhone
            tx.buyerAddress = info.buyerAddress
            tx.buyerTaxCode = info.buyerTaxCode
            tx.grandTotal = info.grandTotal
            tx.paidAmount = info.paidAmount
            tx.debtAmount = info.debtAmount
            tx.vatRate = info.vatRate
            tx.vatAmount = info.vatAmount
            tx.isPaid = info.isPaid
            tx.expectedPayDate = info.expectedPayDate
            tx.paymentReceiptURL = info.paymentReceiptURL
            
            // For material import, also copy to supplier fields (for filter compatibility)
            if mode.contains("Nhập nguyên liệu") {
                tx.supplierName = info.buyerName
                tx.supplierPhone = info.buyerPhone
                tx.supplierAddress = info.buyerAddress
                tx.supplierTaxCode = info.buyerTaxCode
            }
        }
        pendingExportNote = nil
        pendingExportPaymentReceiptURL = nil
        pendingExportInfo = nil
        Task {
            do {
                try await database.saveProductionTransaction(tx)
                // Gán STT đầy đủ — chỉ fetch N nếu STT chưa có suffix type
                let existingSTT = tx.sequenceNumber ?? ""
                let hasFullSTT = existingSTT.components(separatedBy: "-").count >= 4
                let fullStt: String
                if hasFullSTT {
                    fullStt = existingSTT
                } else {
                    let seqType = sequenceType(for: mode)
                    let n = await database.nextSequenceNumber(type: seqType)
                    fullStt = FormatUtils.buildSequenceNumber(type: seqType, n: n)
                }
                var updated = tx
                updated.sequenceNumber = fullStt
                try? await database.updateProductionTransaction(updated)
                if mode.lowercased().contains("thành phẩm") {
                    await upsertProductsFromTransaction(tx)
                    await loadProducts()
                } else {
                    await upsertMaterialsFromTransaction(tx)
                    await loadMaterials()
                }
                await loadProductionHistory(mode: mode)
            } catch {
                print("❌ Error saving production transaction: \(error)")
            }
        }
        restockItems.removeAll()
        isRestockMode = false
    }
    
    func loadMaterialsInventory() async {
        do {
            let inputs = try await database.fetchProductionTransactions(mode: "Nhập nguyên liệu")
            let outputs = try await database.fetchProductionTransactions(mode: "Xuất nguyên liệu")
            var dict: [String: (qty: Int, last: Double, unit: String?)] = [:]
            for tx in inputs {
                for it in tx.items {
                    let key = it.name.lowercased()
                    let cur = dict[key]?.qty ?? 0
                    let isPiece = (it.unit?.lowercased() == "cái")
                    let total = isPiece ? (it.unitPrice * Double(it.quantity) + it.additionalCost) : (it.unitPrice * (Double(it.quantity) / 1000.0) + it.additionalCost)
                    let unitInclusive = isPiece ? (it.quantity > 0 ? total / Double(it.quantity) : it.unitPrice) : (it.quantity > 0 ? total / (Double(it.quantity) / 1000.0) : it.unitPrice)
                    dict[key] = (cur + it.quantity, unitInclusive, it.unit ?? dict[key]?.unit)
                }
            }
            for tx in outputs {
                for it in tx.items {
                    let key = it.name.lowercased()
                    let cur = dict[key]?.qty ?? 0
                    dict[key] = (cur - it.quantity, it.unitPrice, it.unit ?? dict[key]?.unit)
                }
            }
            let items = dict.map { k, v in
                MaterialItem(id: UUID(), name: k, stockQuantity: max(0, v.qty), lastUnitPrice: v.last, unit: v.unit)
            }.sorted { $0.name < $1.name }
            await MainActor.run { self.materialsInventory = items }
        } catch {
            print("⚠️ loadMaterialsInventory error: \(error)")
        }
    }
    
    // Materials DB helpers
    func loadMaterials() async {
        do {
            let rows = try await database.fetchMaterials()
            let cats = Set(rows.map { $0.category })
            await MainActor.run { 
                self.materials = rows
                let base = Set(Category.allCases.filter { $0 != .all }.map { $0.rawValue })
                self.materialCategories = self.materialCategories.union(cats).union(base)
                // Post notification to refresh app notifications (for low stock alerts)
                NotificationCenter.default.post(name: .appNotificationShouldRefresh, object: nil)
            }
        } catch {
            print("⚠️ loadMaterials error: \(error)")
        }
    }
    func databaseSaveMaterial(_ material: MaterialItem) async throws {
        try await database.saveMaterial(material)
    }
    func databaseUpdateMaterial(_ material: MaterialItem) async throws {
        try await database.updateMaterial(material)
    }
    func databaseDeleteMaterial(_ id: UUID) async throws {
        try await database.deleteMaterial(id)
    }
    
    func upsertMaterialsFromTransaction(_ tx: ProductionTransaction) async {
        // naive: sync into materials table
        await loadMaterials()
        var current = self.materials
        let modeLower = tx.mode.lowercased()
        let isImport = modeLower.contains("nhập")
        let isExport = modeLower.contains("xuất")
        for it in tx.items {
            if let idx = current.firstIndex(where: { $0.name.lowercased() == it.name.lowercased() }) {
                var m = current[idx]
                if let u = it.unit, !u.isEmpty {
                    m.unit = u
                }
                if isImport {
                    m.stockQuantity = max(0, m.stockQuantity + it.quantity)
                    let isPiece = (it.unit?.lowercased() == "cái")
                    let total = isPiece ? (it.unitPrice * Double(it.quantity) + it.additionalCost) : (it.unitPrice * (Double(it.quantity) / 1000.0) + it.additionalCost)
                    let unitInclusive = isPiece ? (it.quantity > 0 ? total / Double(it.quantity) : it.unitPrice) : (it.quantity > 0 ? total / (Double(it.quantity) / 1000.0) : it.unitPrice)
                    m.lastUnitPrice = unitInclusive
                    m.hasVAT = it.hasVAT // Cập nhật VAT từ RestockItem
                    if let newCat = it.category, !newCat.isEmpty, m.category != newCat {
                        m.category = newCat
                        self.materialCategories.insert(newCat)
                    }
                } else if isExport {
                    m.stockQuantity = max(0, m.stockQuantity - it.quantity)
                    if let newCat = it.category, !newCat.isEmpty, m.category != newCat {
                        m.category = newCat
                        self.materialCategories.insert(newCat)
                    }
                } else {
                    // Unknown mode, do nothing
                }
                do { try await database.updateMaterial(m) }
                catch { print("❌ updateMaterial error: \(error)") }
                current[idx] = m
            } else {
                if isImport {
                    let total = (it.unitPrice * Double(it.quantity)) + it.additionalCost
                    let unitInclusive = it.quantity > 0 ? (total / Double(it.quantity)) : it.unitPrice
                    let cat = it.category ?? Category.materials.rawValue
                    let m = MaterialItem(id: UUID(), name: it.name, stockQuantity: it.quantity, lastUnitPrice: unitInclusive, category: cat, unit: it.unit, hasVAT: it.hasVAT)
                    do { try await database.saveMaterial(m) }
                    catch { print("❌ saveMaterial error: \(error)") }
                    current.append(m)
                }
            }
        }
        // Final UI update
        await MainActor.run { self.materials = current }
        // Refresh from DB to be sure
        try? await Task.sleep(nanoseconds: 800 * 1_000_000) // Slightly longer delay for DB consistency
        await loadMaterials()
        await loadMaterialsInventory() // Also refresh the inventory calculation
    }
    
    func addMaterialCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        materialCategories.insert(trimmed)
    }
    
    func addProductCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        productCategories.insert(trimmed)
    }
    
    func loadProductionHistory(mode: String) async {
        do {
            let rows = try await database.fetchProductionTransactions(mode: mode)
            await MainActor.run { self.productionHistory = rows }
        } catch {
            print("⚠️ loadProductionHistory error: \(error)")
        }
    }
    
    func loadProducts() async {
        do {
            let rows = try await database.fetchProducts()
            let cats = Set(rows.map { $0.category })
            await MainActor.run {
                self.products = rows
                self.syncInventoryFromProducts()
                // Merge instead of reset so DB categories not tied to products persist
                let base = Set(Category.allCases.filter { $0 != .all }.map { $0.rawValue })
                self.productCategories = self.productCategories.union(cats).union(base)
            }
        } catch {
            print("⚠️ loadProducts error: \(error)")
        }
    }
    
    private func syncInventoryFromProducts() {
        var newInventory: [String: Int] = [:]
        for product in self.products {
            let key = self.getInventoryKey(name: product.name, isFinishedGood: product.isFinishedGood)
            newInventory[key] = product.stockQuantity
        }
        self.inventory = newInventory
    }
    
    func softDeleteProductionTransaction(_ tx: ProductionTransaction, note: String) async -> Bool {
        let now = Date()
        let deletedByName = AuthManager.shared.currentUserProfile?.fullName
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await database.softDeleteProductionTransaction(
                id: tx.id,
                deletedAt: now,
                deletedByName: deletedByName,
                deleteNote: trimmedNote.isEmpty ? nil : trimmedNote
            )
            // Hoàn trả kho: đảo ngược effect của transaction gốc
            await restoreStockFromDeletedTransaction(tx)
            await loadProductionHistory(mode: tx.mode)
            return true
        } catch {
            print("❌ softDeleteProductionTransaction error: \(error)")
            return false
        }
    }

    /// Đảo ngược effect kho của một transaction bị xoá:
    /// - Xuất → cộng lại số lượng đã xuất
    /// - Nhập → trừ lại số lượng đã nhập
    private func restoreStockFromDeletedTransaction(_ tx: ProductionTransaction) async {
        let modeLower = tx.mode.lowercased()
        let isExport = modeLower.contains("xuất")
        let isImport = modeLower.contains("nhập")
        let isFinishedGoods = modeLower.contains("thành phẩm") && !modeLower.contains("nguyên liệu")

        if isFinishedGoods {
            // Hoàn trả sản phẩm thành phẩm
            await loadProducts()
            var current = self.products
            for it in tx.items {
                if let idx = current.firstIndex(where: { $0.name.lowercased() == it.name.lowercased() }) {
                    var p = current[idx]
                    if isExport {
                        p.stockQuantity = p.stockQuantity + it.quantity  // cộng lại
                    } else if isImport {
                        p.stockQuantity = max(0, p.stockQuantity - it.quantity)  // trừ lại
                    }
                    try? await database.updateProduct(p)
                    current[idx] = p
                }
            }
            await MainActor.run { self.products = current; self.syncInventoryFromProducts() }
        } else {
            // Hoàn trả nguyên liệu
            await loadMaterials()
            var current = self.materials
            for it in tx.items {
                if let idx = current.firstIndex(where: { $0.name.lowercased() == it.name.lowercased() }) {
                    var m = current[idx]
                    if isExport {
                        m.stockQuantity = m.stockQuantity + it.quantity  // cộng lại
                    } else if isImport {
                        m.stockQuantity = max(0, m.stockQuantity - it.quantity)  // trừ lại
                    }
                    try? await database.updateMaterial(m)
                    current[idx] = m
                }
            }
            await MainActor.run { self.materials = current }
        }
    }

    func updateProductionTransaction(original: ProductionTransaction, updated: ProductionTransaction) async -> Bool {
        do {
            var updatedTx = updated
            try await database.updateProductionTransaction(updatedTx)
            if updatedTx.mode.lowercased().contains("thành phẩm") {
                await adjustProductsForEditedTransaction(original: original, updated: updatedTx)
                await loadProducts()
            } else {
                await adjustMaterialsForEditedTransaction(original: original, updated: updatedTx)
                await loadMaterials()
            }
            await loadProductionHistory(mode: updatedTx.mode)
            
            let editorId = AuthManager.shared.currentUserProfile?.id
            let editorName = AuthManager.shared.currentUserProfile?.fullName
            let details = buildProductionEditDetails(original: original, updated: updatedTx)
            let edit = ProductionEdit(
                id: UUID(),
                transactionId: original.id,
                createdAt: Date(),
                oldTotal: original.totalCost,
                newTotal: updatedTx.totalCost,
                editorId: editorId,
                editorName: editorName,
                note: nil,
                details: details
            )
            Task {
                do {
                    try await database.saveProductionEdit(edit)
                    await MainActor.run {
                        self.editedProductionTxIds.insert(original.id)
                    }
                } catch {
                    print("❌ Error saving production edit history: \(error)")
                    if let ns = error as NSError?, ns.domain == "StoreMissing" {
                        self.errorMessage = "Không thể lưu lịch sử chỉnh sửa vì chưa chọn cửa hàng."
                        self.showErrorAlert = true
                    }
                }
            }
            return true
        } catch {
            print("❌ updateProductionTransaction error: \(error)")
            return false
        }
    }
    
    func adjustMaterialsForEditedTransaction(original: ProductionTransaction, updated: ProductionTransaction) async {
        let modeLower = updated.mode.lowercased()
        let isImport = modeLower.contains("nhập")
        let isExport = modeLower.contains("xuất")
        var map: [String: (origQty: Int, newQty: Int, newPriceIncl: Double?, unit: String?, hasVAT: Bool)] = [:]
        for it in original.items {
            let k = it.name.lowercased()
            map[k] = (it.quantity, map[k]?.newQty ?? 0, map[k]?.newPriceIncl, it.unit, it.hasVAT)
        }
        for it in updated.items {
            let k = it.name.lowercased()
            let o = map[k]?.origQty ?? 0
            map[k] = (o, it.quantity, it.finalUnitCost, it.unit, it.hasVAT)
        }
        await loadMaterials()
        var current = self.materials
        for (name, info) in map {
            let delta = info.newQty - info.origQty
            if let idx = current.firstIndex(where: { $0.name.lowercased() == name }) {
                var m = current[idx]
                if let u = info.unit { m.unit = u }
                if isImport {
                    m.stockQuantity = max(0, m.stockQuantity + delta)
                    if let p = info.newPriceIncl { m.lastUnitPrice = p }
                    m.hasVAT = info.hasVAT
                } else if isExport {
                    m.stockQuantity = max(0, m.stockQuantity + delta)
                }
                try? await database.updateMaterial(m)
                current[idx] = m
            } else {
                if isImport {
                    let q = max(0, delta)
                    let p = info.newPriceIncl ?? 0
                    let m = MaterialItem(id: UUID(), name: name, stockQuantity: q, lastUnitPrice: p, category: Category.materials.rawValue, unit: info.unit, hasVAT: info.hasVAT)
                    try? await database.saveMaterial(m)
                    current.append(m)
                }
            }
        }
        await MainActor.run { self.materials = current }
    }
    
    func upsertProductsFromTransaction(_ tx: ProductionTransaction) async {
        await loadProducts()
        var current = self.products
        let modeLower = tx.mode.lowercased()
        let isImport = modeLower.contains("nhập")
        let isExport = modeLower.contains("xuất")
        for it in tx.items {
            let key = it.name.lowercased()
            if let idx = current.firstIndex(where: { $0.name.lowercased() == key }) {
                var p = current[idx]
                if isImport {
                    p.stockQuantity = max(0, p.stockQuantity + it.quantity)
                    p.costPrice = it.finalUnitCost
                    // Giá bán = suggestedPrice nếu có, không thì giữ nguyên giá cũ
                    if let suggested = it.suggestedPrice, suggested > 0 {
                        p.price = suggested
                    }
                    if let cat = it.category, !cat.isEmpty, p.category != cat { p.category = cat }
                    p.isFinishedGood = true
                    p.hasVAT = it.hasVAT
                } else if isExport {
                    p.stockQuantity = max(0, p.stockQuantity - it.quantity)
                }
                do { try await database.updateProduct(p) } catch { print("❌ updateProduct error: \(error)") }
                current[idx] = p
            } else {
                if isImport {
                    let costPrice = it.finalUnitCost
                    let salePrice = it.suggestedPrice ?? (costPrice * 1.3)
                    let newProduct = Product(
                        id: UUID(),
                        name: it.name,
                        price: salePrice,
                        productPrice: costPrice,
                        shippingCost: 0,
                        costPrice: costPrice,
                        category: it.category ?? Category.others.rawValue,
                        imageName: "shippingbox.fill",
                        color: "gray",
                        stockQuantity: it.quantity,
                        isFinishedGood: true,
                        hasVAT: it.hasVAT
                    )
                    do { try await database.saveProduct(newProduct) } catch { print("❌ saveProduct error: \(error)") }
                    current.append(newProduct)
                }
            }
        }
        await MainActor.run { self.products = current }
        await loadProducts()
    }
    
    func adjustProductsForEditedTransaction(original: ProductionTransaction, updated: ProductionTransaction) async {
        let modeLower = updated.mode.lowercased()
        let isImport = modeLower.contains("nhập")
        let isExport = modeLower.contains("xuất")
        var map: [String: (origQty: Int, newQty: Int, newPrice: Double?, newCat: String?)] = [:]
        for it in original.items {
            let k = it.name.lowercased()
            map[k] = (it.quantity, map[k]?.newQty ?? 0, map[k]?.newPrice, map[k]?.newCat)
        }
        for it in updated.items {
            let k = it.name.lowercased()
            let o = map[k]?.origQty ?? 0
            map[k] = (o, it.quantity, it.unitPrice, it.category)
        }
        await loadProducts()
        var current = self.products
        for (name, info) in map {
            let delta = info.newQty - info.origQty
            if let idx = current.firstIndex(where: { $0.name.lowercased() == name }) {
                var p = current[idx]
                p.stockQuantity = max(0, p.stockQuantity + delta)
                if isImport {
                    if let pr = info.newPrice, pr > 0 { p.price = pr }
                    if let cat = info.newCat, !cat.isEmpty, p.category != cat { p.category = cat }
                    p.isFinishedGood = true
                }
                try? await database.updateProduct(p)
                current[idx] = p
            } else {
                if isImport {
                    let q = max(0, delta)
                    let pr = max(0, info.newPrice ?? 0)
                    let cat = info.newCat ?? Category.others.rawValue
                    let newProduct = Product(id: UUID(), name: name, price: pr, productPrice: 0, shippingCost: 0, costPrice: 0, category: cat, imageName: "shippingbox.fill", color: "gray", imageData: nil, imageURL: nil, stockQuantity: q, barcode: nil, isFinishedGood: true)
                    try? await database.saveProduct(newProduct)
                    current.append(newProduct)
                }
            }
        }
        await MainActor.run { self.products = current }
    }
    
    func fetchProductionEdits(for transactionId: UUID) async -> [ProductionEdit] {
        do {
            return try await database.fetchProductionEdits(transactionId: transactionId)
        } catch {
            print("⚠️ fetchProductionEdits error: \(error)")
            return []
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.numberStyle = .currency
        f.currencyCode = "VND"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) đ"
    }
    
    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private func buildProductionEditDetails(original: ProductionTransaction, updated: ProductionTransaction) -> [String] {
        var lines: [String] = []
        
        let originalItems = Dictionary(uniqueKeysWithValues: original.items.map { ($0.id, $0) })
        let updatedItems = Dictionary(uniqueKeysWithValues: updated.items.map { ($0.id, $0) })
        
        for item in updated.items {
            if let old = originalItems[item.id] {
                if old.name != item.name {
                    lines.append("Sửa tên: \(old.name)→\(item.name)")
                }
                if old.quantity != item.quantity || old.unit != item.unit {
                    lines.append("Sửa SL \(item.name): \(FormatUtils.formatWeight(old.quantity, unit: old.unit))→\(FormatUtils.formatWeight(item.quantity, unit: item.unit))")
                }
                if old.unitPrice != item.unitPrice {
                    lines.append("Sửa đơn giá \(item.name): \(formatCurrency(old.unitPrice))→\(formatCurrency(item.unitPrice))")
                }
                if old.additionalCost != item.additionalCost {
                    lines.append("Sửa chi phí \(item.name): \(formatCurrency(old.additionalCost))→\(formatCurrency(item.additionalCost))")
                }
                if old.category != item.category {
                    lines.append("Sửa danh mục \(item.name): \(old.category ?? "—")→\(item.category ?? "—")")
                }
                if old.source != item.source {
                    lines.append("Sửa nguồn \(item.name): \(old.source ?? "—")→\(item.source ?? "—")")
                }
            } else {
                lines.append("Thêm mặt hàng: \(item.name)")
            }
        }
        
        for item in original.items where updatedItems[item.id] == nil {
            lines.append("Xóa mặt hàng: \(item.name)")
        }
        
        // Check debt amount changes
        if original.debtAmount != updated.debtAmount {
            let oldStr = formatCurrency(original.debtAmount ?? 0)
            let newStr = formatCurrency(updated.debtAmount ?? 0)
            lines.append("Sửa số nợ: \(oldStr)→\(newStr)")
        }
        
        // Check expected pay date changes
        if original.expectedPayDate != updated.expectedPayDate {
            let oldStr = original.expectedPayDate != nil ? formatDateOnly(original.expectedPayDate!) : "Không đổi"
            let newStr = updated.expectedPayDate != nil ? formatDateOnly(updated.expectedPayDate!) : "Không đổi"
            lines.append("Sửa ngày dự kiến trả: \(oldStr)→\(newStr)")
        }
        
        return lines
    }
    // MARK: - Product Catalog Management
    
    func createProduct(name: String, price: Double, productPrice: Double, shippingCost: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil, barcode: String? = nil, isFinishedGood: Bool = false, additionalInfo: String? = nil) {
        let tempId = UUID()
        var newProduct = Product(
            id: tempId,
            name: name,
            price: price,
            productPrice: productPrice,
            shippingCost: shippingCost,
            costPrice: costPrice,
            category: category.rawValue,
            imageName: imageName,
            color: color,
            imageData: imageData,
            stockQuantity: quantity,
            barcode: barcode,
            isFinishedGood: isFinishedGood,
            additionalInfo: additionalInfo
        )
        products.append(newProduct)
        
        let invKey = getInventoryKey(name: name, isFinishedGood: isFinishedGood)
        inventory[invKey] = quantity
        
        Task {
            var imageURL: String? = nil
            if let data = imageData {
                do {
                    imageURL = try await StorageManager.shared.uploadProductImage(data: data, fileName: tempId.uuidString)
                    print("✅ Image uploaded: \(imageURL ?? "nil")")
                } catch {
                    print("❌ Error uploading image: \(error)")
                }
            }
            
            newProduct.imageURL = imageURL
            
            // Update local model with URL if needed (optional, as imageData is already there)
            if let url = imageURL {
                await MainActor.run {
                    if let index = products.firstIndex(where: { $0.id == tempId }) {
                        products[index].imageURL = url
                    }
                }
            }
            
            do {
                try await database.saveProduct(newProduct)
            } catch {
                print("❌ Error saving new product: \(error)")
            }
        }
    }
    
    func updateProduct(_ product: Product, name: String, price: Double, productPrice: Double, shippingCost: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil, barcode: String? = nil, imageURL: String? = nil, additionalInfo: String? = nil) {
        print("🔄 [OrderViewModel] updateProduct called for: \(product.name), isFinishedGood: \(product.isFinishedGood)")
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            let originalProduct = products[index]
            
            // Handle Name or Type Change for Inventory
            let oldKey = getInventoryKey(name: originalProduct.name, isFinishedGood: originalProduct.isFinishedGood)
            let newKey = getInventoryKey(name: name, isFinishedGood: product.isFinishedGood)
            
            if oldKey != newKey {
                inventory.removeValue(forKey: oldKey)
            }
            
            // Update Inventory
            inventory[newKey] = quantity
            
            var updatedProduct = Product(
                id: product.id,
                name: name,
                price: price,
                productPrice: productPrice,
                shippingCost: shippingCost,
                costPrice: costPrice,
                category: category.rawValue,
                imageName: imageName,
                color: color,
                imageData: imageData,
                imageURL: imageURL,
                stockQuantity: quantity,
                barcode: barcode,
                isFinishedGood: product.isFinishedGood,
                hasVAT: product.hasVAT, // Preserve hasVAT từ product đã được set trước khi gọi hàm này
                additionalInfo: additionalInfo
            )
            print("📦 [OrderViewModel] Updated product: \(updatedProduct.name), isFinishedGood: \(updatedProduct.isFinishedGood)")
            products[index] = updatedProduct
            
            Task {
                // If imageData changed (or is new), upload it
                
                var newImageURL = updatedProduct.imageURL
                
                if let data = imageData {
                     // Only upload if different from original or no URL
                    do {
                        newImageURL = try await StorageManager.shared.uploadProductImage(data: data, fileName: product.id.uuidString)
                         print("✅ Image updated: \(newImageURL ?? "nil")")
                    } catch {
                        print("❌ Error uploading image update: \(error)")
                    }
                }
                
                updatedProduct.imageURL = newImageURL
                
                await MainActor.run {
                    if let idx = products.firstIndex(where: { $0.id == product.id }) {
                        products[idx].imageURL = newImageURL
                    }
                }
                
                do {
                    print("🔄 [OrderViewModel] Attempting to update product in database: \(updatedProduct.name), isFinishedGood: \(updatedProduct.isFinishedGood)")
                    try await database.updateProduct(updatedProduct)
                    print("✅ [OrderViewModel] Database update successful")
                } catch {
                    print("❌ Error updating product: \(error)")
                    print("❌ Error details: \(String(describing: error))")
                }
            }
        }
    }
    
    func deleteProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Remove inventory
            let invKey = getInventoryKey(name: product.name, isFinishedGood: product.isFinishedGood)
            inventory.removeValue(forKey: invKey)
            
            products.remove(at: index)
            
            Task {
                do {
                    try await database.deleteProduct(product.id)
                } catch {
                    print("❌ Error deleting product: \(error)")
                }
            }
        }
    }
    
    func deleteProducts(at offsets: IndexSet) {
        let productsToDelete = offsets.map { products[$0] }
        products.remove(atOffsets: offsets)
        
        Task {
            for product in productsToDelete {
                do {
                    try await database.deleteProduct(product.id)
                } catch {
                    print("❌ Error deleting product batch: \(error)")
                }
            }
        }
    }
    
    // MARK: - Order Editing
    @Published var editingBill: Bill?
    
    func startEditing(_ bill: Bill) {
        editingBill = bill
        items = bill.items
        currentInput = ""
        vatRate = bill.vatRate
        walkInName = bill.customerName ?? "Khách lẻ"
        walkInPhone = bill.customerPhone ?? ""
        walkInAddress = bill.customerAddress ?? ""
        walkInEmail = bill.customerEmail ?? ""
        paymentReceiptImageURL = bill.paymentReceiptURL
        note = bill.note ?? ""
        expectedPayDate = bill.expectedPayDate
        // Load trạng thái thanh toán từ bill gốc
        if let paid = bill.paidAmount, paid < bill.total {
            payFullAmount = false
            partialAmount = paid
        } else {
            payFullAmount = bill.isPaid
            partialAmount = bill.paidAmount ?? bill.total
        }
        editingBillIsPaid = bill.isPaid  // lưu lại isPaid gốc để BillReceiptView load đúng
        newOrderStatus = bill.orderStatus  // load trạng thái đơn hàng gốc
    }
    
    func saveEditedOrder() {
        guard let originalBill = editingBill else { return }
        
        // Create updated bill (keeping original ID and Date)
        let newTotal = totalAmountWithVAT  // dùng total bao gồm VAT để nhất quán với paidAmount
        var updatedBill = Bill(id: originalBill.id, createdAt: originalBill.createdAt, items: items, total: newTotal)
        updatedBill.customerName = walkInName
        updatedBill.customerPhone = walkInPhone.isEmpty ? nil : walkInPhone
        updatedBill.customerAddress = walkInAddress.isEmpty ? nil : walkInAddress
        updatedBill.customerEmail = walkInEmail.isEmpty ? nil : walkInEmail
        updatedBill.paymentReceiptURL = paymentReceiptImageURL ?? originalBill.paymentReceiptURL
        updatedBill.sequenceNumber = originalBill.sequenceNumber
        let currentDebt = debtAmount
        let currentPaid = paidAmount
        updatedBill.isPaid = currentDebt <= 0
        updatedBill.paidAmount = currentPaid
        updatedBill.debtAmount = currentDebt > 0 ? currentDebt : nil
        updatedBill.expectedPayDate = expectedPayDate
        updatedBill.note = note.isEmpty ? nil : note
        updatedBill.vatRate = vatRate
        updatedBill.creatorId = originalBill.creatorId
        updatedBill.creatorName = originalBill.creatorName
        updatedBill.orderStatus = newOrderStatus  // lưu trạng thái đơn hàng
        
        // Calculate VAT amount
        let vatEnabled = StoreManager.shared.currentStoreVATEnabled()
        let rate = vatRate ?? StoreManager.shared.currentStoreVATRate()
        updatedBill.vatAmount = vatEnabled ? (totalAmount * rate / 100.0) : 0

        // Replace in history
        if let index = pastOrders.firstIndex(where: { $0.id == originalBill.id }) {
            pastOrders[index] = updatedBill
            
            Task {
                do {
                    locallyEditedOrderIds.insert(originalBill.id)
                    try await database.updateOrder(updatedBill)
                    addEditHistory(for: originalBill, updated: updatedBill)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    locallyEditedOrderIds.remove(originalBill.id)
                } catch {
                    print("❌ Error updating edited order: \(error)")
                    locallyEditedOrderIds.remove(originalBill.id)
                }
            }
            
            recalculateStats()
        }
        
        // Reset editing state
        reset()
    }
    
    func cancelEditing() {
        reset()
    }
    
    // MARK: - Deleting
    func deleteOrder(_ bill: Bill) {
        Task { @MainActor in
            await softDeleteOrder(bill)
        }
    }
    
    @MainActor
    func softDeleteOrder(_ bill: Bill) async {
        guard !bill.isDeleted else { return }
        
        let deletedAt = Date()
        let deletedBy = AuthManager.shared.currentUserProfile?.id
        
        await revertInventoryForBill(bill)
        
        if let index = pastOrders.firstIndex(where: { $0.id == bill.id }) {
            var updated = pastOrders[index]
            updated.isDeleted = true
            updated.deletedAt = deletedAt
            updated.deletedBy = deletedBy
            pastOrders[index] = updated
        }
        
        do {
            try await database.softDeleteOrder(bill.id, deletedAt: deletedAt, deletedBy: deletedBy)
        } catch {
            print("❌ Error soft deleting order: \(error)")
        }
        
        recalculateStats()
    }
    
    /// Xoá hẳn đơn hàng khỏi DB (dùng cho lịch sử xoá)
    @MainActor
    func hardDeleteOrder(_ bill: Bill) async {
        pastOrders.removeAll { $0.id == bill.id }
        recalculateStats()
        do {
            try await database.deleteOrder(bill.id)
        } catch {
            print("❌ Error hard deleting order: \(error)")
        }
    }

    func deleteOrder(at offsets: IndexSet) {
        let ordersToDelete = offsets.map { pastOrders[$0] }
        Task { @MainActor in
            for order in ordersToDelete {
                await softDeleteOrder(order)
            }
        }
    }
    
    /// Cập nhật pastOrders ngay lập tức (synchronous, trên MainActor) — dùng trước dismiss()
    func applyLocalUpdate(_ bill: Bill) {
        if let index = pastOrders.firstIndex(where: { $0.id == bill.id }) {
            pastOrders[index] = bill
            recalculateStats()
        }
    }

    func updateOrder(_ bill: Bill) async throws {
        // Optimistic update
        if let index = pastOrders.firstIndex(where: { $0.id == bill.id }) {
            pastOrders[index] = bill
            recalculateStats()
        }
        
        // Update DB
        try await database.updateOrder(bill)
    }
    
    func reset() {
        items.removeAll()
        currentInput = ""
        if !suppressPaymentDismissOnReset {
            showPayment = false
        }
        suppressPaymentDismissOnReset = false
        currentSequenceNumber = nil
        editingBill = nil
        walkInName = "Khách lẻ"
        walkInPhone = ""
        walkInAddress = ""
        walkInEmail = ""
        paymentReceiptImageURL = nil
        discountMode = .amount
        discountPercent = 0
        discountAmountValue = 0
        discountFinalPriceTarget = nil
        vatRate = nil
        payFullAmount = true
        partialAmount = 0
        expectedPayDate = nil
        note = ""
        selectedBillNumber = nil
        editingBillIsPaid = false
        isPaidConfirmedByUser = nil
        newOrderStatus = nil
    }
    
    // MARK: - Calendar Stats
    func revenue(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { $0.isPaid && !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.total }
    }
    
    func restockCost(for date: Date) -> Double {
        let calendar = Calendar.current
        return restockHistory
            .filter { !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    func cogs(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { $0.isPaid && !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    func totalExpenses(for date: Date) -> Double {
        let calendar = Calendar.current
        
        // 1. COGS (Cost of Goods Sold)
        let dailyCOGS = cogs(for: date)
        
        // 2. Operating Expenses
        let dailyOpEx = operatingExpenses
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
            
        // 3. Incurred Fees from Restock
        /*
        let dailyIncurredFees = restockHistory
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { billSum, bill in
                billSum + bill.items.reduce(0) { $0 + $1.additionalCost }
            }
        */
            
        return dailyCOGS + dailyOpEx // + dailyIncurredFees (Removed as requested)
    }
    
    func grossProfit(for date: Date) -> Double {
        let calendar = Calendar.current
        let dailyOrders = pastOrders.filter { $0.isPaid && !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
        return dailyOrders.reduce(0) { $0 + $1.profit }
    }
    
    func profit(for date: Date) -> Double {
        let calendar = Calendar.current
        
        // 1. Gross Profit from Orders (Revenue - COGS)
        let grossProfit = self.grossProfit(for: date)
        
        // 2. Operational Costs (OPEX)
        let dailyOpEx = operatingExpenses
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
            
        // 3. Incurred Fees from Restock (Phát sinh)
        // Only additionalCost reduces profit immediately (User requirement)
        /*
        let dailyIncurredFees = restockHistory
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { billSum, bill in
                billSum + bill.items.reduce(0) { $0 + $1.additionalCost }
            }
        */
            
        return grossProfit - dailyOpEx // - dailyIncurredFees (Removed as requested, now part of COGS)
    }
    
    func orders(for date: Date) -> [Bill] {
        let calendar = Calendar.current
        return pastOrders
            .filter { !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    // MARK: - Range Stats (dùng cho trang tổng quan)

    private func dateInterval(for range: ReportDateRange) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .today:
            return (cal.startOfDay(for: now),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .thisWeek:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            let end = cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? now
            return (start, end)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            let end = cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now
            return (start, end)
        case .custom(let s, let e):
            return (cal.startOfDay(for: s),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e)
        }
    }

    func revenue(for range: ReportDateRange) -> Double {
        let (start, end) = dateInterval(for: range)
        return pastOrders
            .filter { $0.isPaid && !$0.isDeleted && $0.createdAt >= start && $0.createdAt <= end }
            .reduce(0) { $0 + $1.total }
    }

    func cogs(for range: ReportDateRange) -> Double {
        let (start, end) = dateInterval(for: range)
        return pastOrders
            .filter { $0.isPaid && !$0.isDeleted && $0.createdAt >= start && $0.createdAt <= end }
            .reduce(0) { $0 + $1.totalCost }
    }

    func grossProfit(for range: ReportDateRange) -> Double {
        let (start, end) = dateInterval(for: range)
        return pastOrders
            .filter { $0.isPaid && !$0.isDeleted && $0.createdAt >= start && $0.createdAt <= end }
            .reduce(0) { $0 + $1.profit }
    }

    func orders(for range: ReportDateRange) -> [Bill] {
        let (start, end) = dateInterval(for: range)
        return pastOrders
            .filter { !$0.isDeleted && $0.createdAt >= start && $0.createdAt <= end }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Sequence Type Helper

    func sequenceType(for mode: String) -> String {
        let m = mode.lowercased()
        if m.contains("nhập") && m.contains("nguyên liệu") { return SequenceType.materialImport }
        if m.contains("xuất") && m.contains("nguyên liệu") { return SequenceType.materialExport }
        if m.contains("nhập") && m.contains("thành phẩm")  { return SequenceType.finishedImport }
        if m.contains("xuất") && m.contains("thành phẩm")  { return SequenceType.finishedExport }
        if m.contains("nhập")                               { return SequenceType.retailRestock }
        return SequenceType.retailSale
    }

    // MARK: - Wholesale / Production Stats

    struct WholesaleStats {
        var revenue: Double       // ∑ grandTotal của Xuất Thành Phẩm có grandTotal > 0
        var paid: Double          // ∑ paidAmount
        var debt: Double          // ∑ debtAmount
        var materialCost: Double  // ∑ (quantity × unitPrice) của các item trong phiếu Nhập Nguyên Liệu
        var materialExportCost: Double // ∑ (quantity × unitPrice) của các item trong phiếu Xuất Nguyên Liệu
        var transactions: [ProductionTransaction]
    }

    func wholesaleStats(for range: ReportDateRange, allTransactions: [ProductionTransaction]) -> WholesaleStats {
        let (start, end) = dateInterval(for: range)
        let inRange = allTransactions.filter { $0.createdAt >= start && $0.createdAt <= end }

        // Doanh thu sỉ: Xuất Thành Phẩm có grandTotal > 0 (bán trực tiếp, không qua POS)
        let exports = inRange.filter {
            $0.mode.lowercased().contains("xuất") &&
            $0.mode.lowercased().contains("thành phẩm") &&
            ($0.grandTotal ?? 0) > 0
        }
        let revenue      = exports.reduce(0) { $0 + ($1.grandTotal ?? 0) }
        let paid         = exports.reduce(0) { $0 + ($1.paidAmount ?? 0) }
        let debt         = exports.reduce(0) { $0 + ($1.debtAmount ?? 0) }

        // Chi phí nguyên liệu: tổng chi phí các phiếu Nhập Nguyên Liệu trong kỳ
        // Tính theo quantity × unitPrice của từng item (grams/1000 × giá/kg cho nguyên liệu)
        let materialImports = inRange.filter {
            $0.mode.lowercased().contains("nhập") &&
            $0.mode.lowercased().contains("nguyên liệu")
        }
        let materialCost = materialImports.reduce(0.0) { txSum, tx in
            txSum + tx.items.reduce(0.0) { itemSum, item in
                // Nguyên liệu: quantity là grams, unitPrice là giá/kg
                let cat = item.category?.lowercased() ?? ""
                let unit = item.unit?.lowercased() ?? ""
                if unit == "cái" {
                    return itemSum + (Double(item.quantity) * item.unitPrice)
                } else if cat == Category.materials.rawValue.lowercased() || unit == "kg" || unit.isEmpty {
                    return itemSum + (item.unitPrice * (Double(item.quantity) / 1000.0))
                } else {
                    return itemSum + (Double(item.quantity) * item.unitPrice)
                }
            }
        }
        
        // Tổng giá trị xuất nguyên liệu: tổng giá trị các phiếu Xuất Nguyên Liệu trong kỳ
        let materialExports = inRange.filter {
            $0.mode.lowercased().contains("xuất") &&
            $0.mode.lowercased().contains("nguyên liệu")
        }
        let materialExportCost = materialExports.reduce(0.0) { txSum, tx in
            txSum + tx.items.reduce(0.0) { itemSum, item in
                // Tính giá trị xuất nguyên liệu theo cùng cách như nhập
                let cat = item.category?.lowercased() ?? ""
                let unit = item.unit?.lowercased() ?? ""
                if unit == "cái" {
                    return itemSum + (Double(item.quantity) * item.unitPrice)
                } else if cat == Category.materials.rawValue.lowercased() || unit == "kg" || unit.isEmpty {
                    return itemSum + (item.unitPrice * (Double(item.quantity) / 1000.0))
                } else {
                    return itemSum + (Double(item.quantity) * item.unitPrice)
                }
            }
        }

        return WholesaleStats(
            revenue: revenue,
            paid: paid,
            debt: debt,
            materialCost: materialCost,
            materialExportCost: materialExportCost,
            transactions: exports.sorted { $0.createdAt > $1.createdAt }
        )
    }

    func makeBill(isPaid: Bool = false) -> Bill? {
        guard !items.isEmpty else { return nil }
        let cost = items.reduce(0) { $0 + $1.totalCost }
        let grandTotal = totalAmountWithVAT
        var bill = Bill(id: UUID(), createdAt: Date(), items: items, total: grandTotal, totalCost: cost)
        // Ưu tiên giá trị user đã toggle trong UI (isPaidConfirmedByUser),
        // nếu không có thì dùng tham số isPaid được truyền vào từ caller.
        let effectiveIsPaid = isPaidConfirmedByUser ?? isPaid
        bill.isPaid = effectiveIsPaid
        bill.customerName = walkInName
        bill.customerPhone = walkInPhone.isEmpty ? nil : walkInPhone
        bill.customerAddress = walkInAddress.isEmpty ? nil : walkInAddress
        bill.customerEmail = walkInEmail.isEmpty ? nil : walkInEmail
        bill.paymentReceiptURL = paymentReceiptImageURL
        bill.sequenceNumber = currentSequenceNumber ?? FormatUtils.generateSequenceNumber()
        bill.vatRate = vatRate
        // Khi chưa thanh toán: paidAmount = 0, debtAmount = tổng tiền
        if !effectiveIsPaid {
            bill.paidAmount = 0
            bill.debtAmount = grandTotal
        } else {
            bill.paidAmount = paidAmount
            bill.debtAmount = debtAmount > 0 ? debtAmount : nil
        }
        bill.expectedPayDate = expectedPayDate
        bill.note = note.isEmpty ? nil : note
        bill.orderStatus = newOrderStatus
        
        // Calculate VAT amount
        let vatEnabled = StoreManager.shared.currentStoreVATEnabled()
        let rate = vatRate ?? StoreManager.shared.currentStoreVATRate()
        let baseTotal = items.reduce(0) { $0 + $1.total }
        bill.vatAmount = vatEnabled ? (baseTotal * rate / 100.0) : 0
        
        // Populate creator info
        if let profile = AuthManager.shared.currentUserProfile {
            bill.creatorId = profile.id
            bill.creatorName = profile.fullName
        }
        
        return bill
    }
    
    func billPayload() -> String? {
        guard let bill = makeBill() else { return nil }
        
        let header = "KNOTE_BILL"
        let idLine = "id=\(bill.id.uuidString)"
        let totalLine = "total=\(Int(bill.total))"
        let dateFormatter = ISO8601DateFormatter()
        let dateLine = "createdAt=\(dateFormatter.string(from: bill.createdAt))"
        
        let itemsLines = bill.items.map { item in
            let unit = Int(item.price)
            let lineTotal = Int(item.total)
            return "\(item.quantity)x \(item.name) @\(unit) = \(lineTotal)"
        }
        let itemsBlock = itemsLines.joined(separator: "|")
        
        return [header, idLine, totalLine, dateLine, "items=\(itemsBlock)"].joined(separator: ";")
    }
    
    func vietQRURL() -> URL? {
        guard let bill = makeBill(), (bill.paidAmount ?? bill.total) > 0 else { return nil }
        guard let rawBankName = StoreManager.shared.currentStore?.bankName, !rawBankName.isEmpty else { return nil }
        guard let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber, !bankAccount.isEmpty else { return nil }
        var bankName = rawBankName
        if let range = bankName.range(of: "\\((.*?)\\)", options: .regularExpression) {
            let code = bankName[range]
            let cleanCode = code.dropFirst().dropLast()
            bankName = String(cleanCode)
        }
        let finalBankAccount = bankAccount
        let amount = Int(bill.paidAmount ?? bill.total)
        let base = "https://img.vietqr.io/image/\(bankName)-\(finalBankAccount)-compact.png"
        let infoBase: String
        let shortId = bill.id.uuidString.prefix(8)
        infoBase = "KNOTE \(shortId)"
        let allowed = CharacterSet.urlQueryAllowed
        let encodedInfo = infoBase.addingPercentEncoding(withAllowedCharacters: allowed) ?? "KNOTE"
        let urlString = "\(base)?amount=\(amount)&addInfo=\(encodedInfo)"
        return URL(string: urlString)
    }
    
    // MARK: - Manual Item Management
    func addItem(_ name: String, price: Double, quantity: Int, discount: Double = 0, imageData: Data? = nil) {
        if let index = items.firstIndex(where: { $0.name == name && $0.price == price && $0.discount == discount && $0.imageData == imageData }) {
            items[index].quantity += quantity
            lastFocusedItemId = items[index].id
        } else {
            // Find cost price
            var cost: Double = 0
            if let product = products.first(where: { $0.name.lowercased() == name.lowercased() }) {
                cost = product.costPrice
            }
            items.append(OrderItem(name: name, quantity: quantity, price: price, costPrice: cost, discount: discount, imageData: imageData, systemImage: "cart.circle.fill"))
            lastFocusedItemId = items.last?.id
        }
    }
    
    func updateItem(_ item: OrderItem, newQuantity: Int) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if newQuantity > 0 {
                items[index].quantity = newQuantity
            } else {
                items.remove(at: index)
            }
        }
    }
    
    func updateItemFull(_ item: OrderItem, name: String, price: Double, quantity: Int, discount: Double, imageData: Data?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].name = name
            items[index].price = price
            items[index].quantity = quantity
            items[index].discount = discount
            items[index].imageData = imageData
            // Preserve existing systemImage
        }
    }
    
    func removeItem(_ item: OrderItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }
    
    func soldProductsTotals(range: ReportDateRange? = nil, search: String? = nil) -> [(name: String, quantity: Int)] {
        var totals: [String: (display: String, qty: Int)] = [:]
        
        let orders: [Bill]
        if let r = range {
            let calendar = Calendar.current
            let now = Date()
            let startDate: Date
            let endDate: Date
            switch r {
            case .today:
                startDate = calendar.startOfDay(for: now)
                endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            case .thisWeek:
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                startDate = calendar.date(from: comps) ?? now
                endDate = calendar.date(byAdding: .day, value: 7, to: startDate)?.addingTimeInterval(-1) ?? now
            case .thisMonth:
                let comps = calendar.dateComponents([.year, .month], from: now)
                startDate = calendar.date(from: comps) ?? now
                endDate = calendar.date(byAdding: .month, value: 1, to: startDate)?.addingTimeInterval(-1) ?? now
            case .custom(let start, let end):
                startDate = start
                endDate = end
            }
            orders = pastOrders.filter { $0.isPaid && $0.createdAt >= startDate && $0.createdAt <= endDate }
        } else {
            orders = pastOrders.filter { $0.isPaid }
        }
        
        for bill in orders {
            for item in bill.items {
                let key = item.name.lowercased()
                var entry = totals[key] ?? (display: item.name, qty: 0)
                entry.qty += item.quantity
                totals[key] = entry
            }
        }
        var result = totals.values.map { (name: $0.display, quantity: $0.qty) }
        if let s = search, !s.isEmpty {
            let q = s.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) }
        }
        result.sort { $0.quantity > $1.quantity }
        return result
    }
}
