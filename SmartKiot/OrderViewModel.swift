import Foundation
import Combine
import SwiftUI
import Supabase

class OrderViewModel: ObservableObject {
    @Published var currentInput: String = ""
    @Published var items: [OrderItem] = []
    @Published var lastFocusedItemId: UUID?
    @Published var showPayment: Bool = false
    @Published var walkInName: String = "Khách lẻ"
    @Published var paymentReceiptImageURL: String? = nil
    
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
    
    // Cache control
    private var loadedStoreId: UUID?

    // Voice & AI
    @Published var isProcessingVoice: Bool = false
    @Published var useGPT: Bool = true // Toggle for AI parser
    @Published var isRecordingCustomerName: Bool = false
    @Published var isRecordingManualProductName: Bool = false
    @Published var manualRecordedName: String = ""


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
        let globalIncurredFees = restockHistory.reduce(0) { billSum, bill in
            billSum + bill.items.reduce(0) { $0 + $1.additionalCost }
        }
        
        return globalRevenue - globalCOGS - globalOpEx - globalIncurredFees
    }
    
    // Restock
    @Published var isRestockMode: Bool = false
    @Published var restockItems: [RestockItem] = []
    @Published var restockHistory: [RestockBill] = []
    @Published var operatingExpenses: [OperatingExpense] = []
    @Published var materialsInventory: [MaterialItem] = []
    @Published var materials: [MaterialItem] = []
    
    // Catalog & Dashboard
    @Published var selectedCategory: Category = .all
    @Published var products: [Product] = [
        Product(name: "Hoa hồng đỏ", price: 20000, category: "Hoa tươi", imageName: "rosette", color: "red"),
        Product(name: "Hoa hướng dương", price: 30000, category: "Hoa tươi", imageName: "sun.max.fill", color: "yellow"),
        Product(name: "Hoa tulip", price: 25000, category: "Hoa tươi", imageName: "camera.macro", color: "purple"),
        Product(name: "Bó hoa hỗn hợp", price: 350000, category: "Bó hoa", imageName: "gift.fill", color: "pink"),
        Product(name: "Bó hoa sinh nhật", price: 500000, category: "Bó hoa", imageName: "birthday.cake.fill", color: "blue"),
        Product(name: "Bình hoa", price: 150000, category: "Phụ kiện", imageName: "cylinder.split.1x2.fill", color: "gray"),
        Product(name: "Ruy băng", price: 10000, category: "Phụ kiện", imageName: "scribble.variable", color: "red"),
        Product(name: "Thiệp chúc mừng", price: 15000, category: "Phụ kiện", imageName: "envelope.fill", color: "orange")
    ]
    
    var filteredProducts: [Product] {
        if selectedCategory == .all {
            return products
        }
        return products.filter { $0.category == selectedCategory.rawValue }
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
    
    // Connection Status
    @Published var isDatabaseConnected: Bool = false
    @Published var databaseError: String? = nil
    @Published var isLoading: Bool = false
    
    private var realtimeChannel: RealtimeChannelV2?
    
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
    
    private func buildEditDetails(original: Bill, updated: Bill) -> [String] {
        var lines: [String] = []
        if (original.customerName ?? "") != (updated.customerName ?? "") {
            let o = (original.customerName ?? "").isEmpty ? "—" : (original.customerName ?? "")
            let n = (updated.customerName ?? "").isEmpty ? "—" : (updated.customerName ?? "")
            lines.append("Khách: \(o) → \(n)")
        }
        if (original.paymentReceiptURL ?? "") != (updated.paymentReceiptURL ?? "") {
            lines.append("Ảnh thanh toán: đã cập nhật")
        }
        var origMap: [String: OrderItem] = [:]
        var updMap: [String: OrderItem] = [:]
        for it in original.items { origMap[it.name] = it }
        for it in updated.items { updMap[it.name] = it }
        for name in Set(origMap.keys).union(updMap.keys) {
            let o = origMap[name]
            let n = updMap[name]
            if o == nil, let n {
                lines.append("Thêm \(name): SL \(n.quantity), giá \(Int(n.price))")
            } else if let o, n == nil {
                lines.append("Xoá \(name): SL \(o.quantity)")
            } else if let o, let n {
                var parts: [String] = []
                if o.quantity != n.quantity { parts.append("SL \(o.quantity)→\(n.quantity)") }
                if Int(o.price) != Int(n.price) { parts.append("Giá \(Int(o.price))→\(Int(n.price))") }
                if Int(o.discount) != Int(n.discount) { parts.append("Giảm \(Int(o.discount))→\(Int(n.discount))") }
                if !parts.isEmpty {
                    lines.append("Sửa \(name): " + parts.joined(separator: ", "))
                }
            }
        }
        if original.total != updated.total {
            lines.append("Tổng tiền: \(Int(original.total)) → \(Int(updated.total))")
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
        let newTotal = totalAmount
        var updatedBill = Bill(id: original.id, createdAt: original.createdAt, items: items, total: newTotal)
        updatedBill.customerName = walkInName
        updatedBill.paymentReceiptURL = paymentReceiptImageURL ?? original.paymentReceiptURL
        if let index = pastOrders.firstIndex(where: { $0.id == original.id }) {
            pastOrders[index] = updatedBill
        }
        Task {
            do {
                try await database.updateOrder(updatedBill)
                addEditHistory(for: original, updated: updatedBill)
            } catch {
                print("❌ Error updating edited payment: \(error)")
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
        self.priceHistory = [:]
        self.operatingExpenses = []
        self.inventory = [:]
        self.revenue = 0
        self.orderCount = 0
        self.totalRestockCost = 0
        self.totalOperatingCost = 0
        self.todayStats = nil
        self.walkInName = "Khách lẻ"
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
        
        let (rProds, rOrders, rRestock, rPrices, rExpenses) = await (productsResult, ordersResult, restockResult, pricesResult, expensesResult)
        
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
        
        // Sync inventory dictionary from products
        self.inventory = [:]
        for product in self.products {
            self.inventory[product.name.lowercased()] = product.stockQuantity
        }
        
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
                        self.inventory[product.name.lowercased()] = product.stockQuantity
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
                        self.inventory[product.name.lowercased()] = product.stockQuantity
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
    
    func stockLevel(for name: String) -> Int {
        return inventory[name.lowercased()] ?? 0
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
            let key = item.name.lowercased()
            let currentStock = inventory[key] ?? 0
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
            
            // Save Order to DB
            Task {
                do {
                    try await database.saveOrder(bill)
                } catch {
                    print("❌ Error saving order: \(error)")
                }
            }
            
            // Deduct from Inventory
            for item in bill.items {
                let key = item.name.lowercased()
                if let current = inventory[key] {
                    let newQuantity = max(0, current - item.quantity)
                    inventory[key] = newQuantity
                    
                    // Update Product in DB
                    if let index = products.firstIndex(where: { $0.name.lowercased() == key }) {
                        var product = products[index]
                        product.stockQuantity = newQuantity
                        products[index] = product
                        
                        Task {
                            do {
                                try await database.updateProduct(product)
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
    
    func recalculateStats() {
        // Global Stats
        revenue = pastOrders.filter { $0.isPaid }.reduce(0) { $0 + $1.total }
        orderCount = pastOrders.count
        
        // Total Restock Cost (Import Price + Fees)
        totalRestockCost = restockHistory.reduce(0) { $0 + $1.totalCost }
        
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
    
    func exportFinancialReport(range: ReportDateRange) -> URL? {
        let service = FinancialReportService.shared
        let stats = service.generateReport(
            orders: pastOrders,
            expenses: operatingExpenses,
            restocks: restockHistory,
            range: range
        )
        return service.exportToCSV(stats: stats)
    }
    
    // MARK: - Operating Expenses
    func addOperatingExpense(title: String, amount: Double, note: String?) {
        let expense = OperatingExpense(id: UUID(), title: title, amount: amount, note: note, createdAt: Date())
        
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
    
    func addRestockItem(_ name: String, unitPrice: Double, quantity: Int, additionalCost: Double = 0, suggestedPrice: Double? = nil) {
        restockItems.append(RestockItem(name: name, quantity: quantity, unitPrice: unitPrice, additionalCost: additionalCost, suggestedPrice: suggestedPrice))
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
        guard !restockItems.isEmpty else { return }
        
        let total = restockItems.reduce(0) { $0 + $1.totalCost }
        let bill = RestockBill(id: UUID(), createdAt: Date(), items: restockItems, totalCost: total)
        
        restockHistory.insert(bill, at: 0)
        
        Task {
            do {
                try await database.saveRestockBill(bill)
            } catch {
                print("❌ Error saving restock bill: \(error)")
            }
        }
        
        // Update Inventory & Catalog (Moving Average Cost Logic)
        for item in restockItems {
            let key = item.name.lowercased()
            let currentQuantity = inventory[key] ?? 0
            let newQuantity = currentQuantity + item.quantity
            inventory[key] = newQuantity
            
            // Auto-add to products if not exists OR update if needed
            // Check case-insensitive
            if let index = products.firstIndex(where: { $0.name.lowercased() == key }) {
                // Product exists. Update stock and Calculate Moving Average Cost
                var product = products[index]
                
                // Update: Capitalize additionalCost (incurred fees) into costPrice as requested.
                // finalUnitCost = (quantity * unitPrice + additionalCost) / quantity
                let newUnitCost = item.finalUnitCost
                product.costPrice = newUnitCost
                
                // AVCO Calculation (Alternative - Commented out)
                /*
                let oldCost = product.costPrice
                let effectiveOldQty = max(0, Double(currentQuantity))
                
                let oldTotalValue = effectiveOldQty * oldCost
                let newTotalValue = Double(item.quantity) * newUnitCost
                
                let newAverageCost = (oldTotalValue + newTotalValue) / (effectiveOldQty + Double(item.quantity))
                product.costPrice = newAverageCost
                */
                
                product.stockQuantity = newQuantity
                
                // Update selling price if suggested
                if let suggested = item.suggestedPrice {
                    product.price = suggested
                }
                
                products[index] = product
                
                Task {
                    do {
                        try await database.updateProduct(product)
                    } catch {
                        print("❌ Error updating product from restock: \(error)")
                    }
                }
            } else {
                // New Product
                // Determine category? Default to Others or Flowers if name contains flower keywords
                var cat: Category = .others
                if key.contains("flower") || key.contains("hoa") || key.contains("hồng") {
                    cat = .flowers
                } else if key.contains("giấy") || key.contains("nơ") || key.contains("ribbon") {
                    cat = .accessories
                }
                
                let newProduct = Product(
                    id: UUID(), // Explicit ID
                    name: item.name, // Use original casing
                    price: item.suggestedPrice ?? (item.finalUnitCost * 1.3), // Use suggested or default 30% markup (on total cost is fine for suggestion)
                    costPrice: item.finalUnitCost, // Initial Cost includes incurred fees
                    category: cat.rawValue,
                    imageName: "shippingbox.fill", // Default icon
                    color: "gray",
                    stockQuantity: newQuantity
                )
                products.append(newProduct)
                
                Task {
                    do {
                        try await database.saveProduct(newProduct)
                    } catch {
                        print("❌ Error saving new product from restock: \(error)")
                    }
                }
            }
        }
        
        recalculateStats()
        
        restockItems.removeAll()
        isRestockMode = false
    }
    
    // MARK: - Restock Editing/Deleting
    func deleteRestockBill(_ bill: RestockBill) {
        if let index = restockHistory.firstIndex(where: { $0.id == bill.id }) {
            // Revert Inventory
            for item in bill.items {
                let key = item.name.lowercased()
                if let current = inventory[key] {
                    let newQuantity = max(0, current - item.quantity)
                    inventory[key] = newQuantity
                    
                    // Update Product
                    if let pIndex = products.firstIndex(where: { $0.name.lowercased() == key }) {
                        var p = products[pIndex]
                        p.stockQuantity = newQuantity
                        products[pIndex] = p
                        Task { 
                            do { try await database.updateProduct(p) } catch { print("❌ Error reverting product stock: \(error)") }
                        }
                    }
                }
            }
            
            restockHistory.remove(at: index)
            
            Task {
                do {
                    try await database.deleteRestockBill(bill.id)
                } catch {
                    print("❌ Error deleting restock bill: \(error)")
                }
            }
            
            recalculateStats()
        }
    }
    
    func editRestockBill(_ bill: RestockBill) {
        // Revert inventory and remove bill (similar to delete)
        deleteRestockBill(bill)
        
        // Load items into current session
        restockItems = bill.items
        isRestockMode = true
        shouldShowRestockSheet = true
    }
    
    // MARK: - Production Management
    func completeProductionTransaction(mode: String) {
        guard !restockItems.isEmpty else { return }
        let total = restockItems.reduce(0) { $0 + $1.totalCost }
        let tx = ProductionTransaction(id: UUID(), createdAt: Date(), mode: mode, items: restockItems, totalCost: total)
        Task {
            do {
                try await database.saveProductionTransaction(tx)
                await upsertMaterialsFromTransaction(tx)
                await loadMaterials()
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
            var dict: [String: (qty: Int, last: Double)] = [:]
            for tx in inputs {
                for it in tx.items {
                    let key = it.name.lowercased()
                    let cur = dict[key]?.qty ?? 0
                    dict[key] = (cur + it.quantity, it.unitPrice)
                }
            }
            for tx in outputs {
                for it in tx.items {
                    let key = it.name.lowercased()
                    let cur = dict[key]?.qty ?? 0
                    dict[key] = (cur - it.quantity, it.unitPrice)
                }
            }
            let items = dict.map { k, v in
                MaterialItem(id: UUID(), name: k, stockQuantity: max(0, v.qty), lastUnitPrice: v.last)
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
            await MainActor.run { self.materials = rows }
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
        for it in tx.items {
            if let idx = current.firstIndex(where: { $0.name.lowercased() == it.name.lowercased() }) {
                var m = current[idx]
                m.stockQuantity = max(0, m.stockQuantity + it.quantity)
                m.lastUnitPrice = it.unitPrice
                try? await database.updateMaterial(m)
                current[idx] = m
            } else {
                let m = MaterialItem(id: UUID(), name: it.name, stockQuantity: it.quantity, lastUnitPrice: it.unitPrice)
                try? await database.saveMaterial(m)
                current.append(m)
            }
        }
        await loadMaterials()
    }
    // MARK: - Product Catalog Management
    
    func createProduct(name: String, price: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil, barcode: String? = nil) {
        let tempId = UUID()
        var newProduct = Product(
            id: tempId,
            name: name,
            price: price,
            costPrice: costPrice,
            category: category.rawValue,
            imageName: imageName,
            color: color,
            imageData: imageData,
            stockQuantity: quantity,
            barcode: barcode
        )
        products.append(newProduct)
        inventory[name.lowercased()] = quantity
        
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
    
    func updateProduct(_ product: Product, name: String, price: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil, barcode: String? = nil, imageURL: String? = nil) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Handle Name Change for Inventory
            let oldKey = product.name.lowercased()
            let newKey = name.lowercased()
            
            if oldKey != newKey {
                inventory.removeValue(forKey: oldKey)
            }
            
            // Update Inventory
            inventory[newKey] = quantity
            
            var updatedProduct = Product(
                id: product.id,
                name: name,
                price: price,
                costPrice: costPrice,
                category: category.rawValue,
                imageName: imageName,
                color: color,
                imageData: imageData,
                imageURL: imageURL, // Use passed URL (handles deletion if nil)
                stockQuantity: quantity,
                barcode: barcode
            )
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
                    try await database.updateProduct(updatedProduct)
                } catch {
                    print("❌ Error updating product: \(error)")
                }
            }
        }
    }
    
    func deleteProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Remove inventory
            inventory.removeValue(forKey: product.name.lowercased())
            
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
    }
    
    func saveEditedOrder() {
        guard let originalBill = editingBill else { return }
        
        // Create updated bill (keeping original ID and Date)
        // We use the current items to calculate total
        let newTotal = totalAmount
        var updatedBill = Bill(id: originalBill.id, createdAt: originalBill.createdAt, items: items, total: newTotal)
        updatedBill.customerName = walkInName
        updatedBill.paymentReceiptURL = paymentReceiptImageURL ?? originalBill.paymentReceiptURL

        // Replace in history
        if let index = pastOrders.firstIndex(where: { $0.id == originalBill.id }) {
            pastOrders[index] = updatedBill
            
            Task {
                do {
                    try await database.updateOrder(updatedBill)
                    addEditHistory(for: originalBill, updated: updatedBill)
                } catch {
                    print("❌ Error updating edited order: \(error)")
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
        if let index = pastOrders.firstIndex(where: { $0.id == bill.id }) {
            pastOrders.remove(at: index)
            
            Task {
                try? await database.deleteOrder(bill.id)
            }
            
            recalculateStats()
        }
    }
    
    func deleteOrder(at offsets: IndexSet) {
        let ordersToDelete = offsets.map { pastOrders[$0] }
        pastOrders.remove(atOffsets: offsets)
        
        Task {
            for order in ordersToDelete {
                try? await database.deleteOrder(order.id)
            }
        }
        
        recalculateStats()
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
        showPayment = false
        editingBill = nil
        walkInName = "Khách lẻ"
        paymentReceiptImageURL = nil
        discountMode = .amount
        discountPercent = 0
        discountAmountValue = 0
        discountFinalPriceTarget = nil
    }
    
    // MARK: - Calendar Stats
    func revenue(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { $0.isPaid && calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.total }
    }
    
    func restockCost(for date: Date) -> Double {
        let calendar = Calendar.current
        return restockHistory
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    func cogs(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { $0.isPaid && calendar.isDate($0.createdAt, inSameDayAs: date) }
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
        let dailyOrders = pastOrders.filter { $0.isPaid && calendar.isDate($0.createdAt, inSameDayAs: date) }
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
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }
    
    func makeBill(isPaid: Bool = false) -> Bill? {
        guard !items.isEmpty else { return nil }
        let cost = items.reduce(0) { $0 + $1.totalCost }
        var bill = Bill(id: UUID(), createdAt: Date(), items: items, total: totalAmount, totalCost: cost)
        bill.isPaid = isPaid
        bill.customerName = walkInName
        bill.paymentReceiptURL = paymentReceiptImageURL
        
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
        guard let bill = makeBill(), bill.total > 0 else { return nil }
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
