import Foundation
import Combine
import SwiftUI

class OrderViewModel: ObservableObject {
    @Published var currentInput: String = ""
    @Published var items: [OrderItem] = []
    @Published var showPayment: Bool = false
    
    @Published var priceHistory: [String: Double] = [:]
    @Published var inventory: [String: Int] = [:]
    @Published var pastOrders: [Bill] = []
    
    // Navigation Triggers
    @Published var shouldShowRestockSheet = false
    @Published var shouldShowOrderSheet = false

    // Dashboard Stats
    @Published var revenue: Double = 0
    @Published var orderCount: Int = 0
    @Published var totalRestockCost: Double = 0
    @Published var showOrderSuccessToast: Bool = false
    @Published var lastCreatedBill: Bill? = nil
    
    var netProfit: Double {
        revenue - totalRestockCost
    }
    
    // Restock
    @Published var isRestockMode: Bool = false
    @Published var restockItems: [RestockItem] = []
    @Published var restockHistory: [RestockBill] = []
    
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
            $0.category.lowercased().contains(lowerText)
        }
    }
    
    func addProduct(_ product: Product) {
        if let index = items.firstIndex(where: { $0.name == product.name && $0.price == product.price && $0.systemImage == product.imageName }) {
            items[index].quantity += 1
        } else {
            items.append(OrderItem(name: product.name, quantity: 1, price: product.price, costPrice: product.costPrice, imageData: product.imageData, systemImage: product.imageName))
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
    
    init() {
        // Load data from Database
        Task {
            await loadData()
        }
        
        // Recalculate stats
        recalculateStats()
        
        // Listen to transcript changes
        speechRecognizer.$transcript
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main) // Reduced debounce for responsiveness
            .sink { [weak self] newText in
                // Only update if we have new text (even if recording just stopped)
                if !newText.isEmpty {
                    self?.currentInput = newText
                }
            }
            .store(in: &cancellables)
            
        // Listen for recording state changes to auto-process
        speechRecognizer.$isRecording
            .dropFirst()
            .sink { [weak self] isRecording in
                if !isRecording {
                    // Recording stopped (manual or auto)
                    // Wait slightly for final transcript
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self?.processInput()
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
    
    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedProducts = database.fetchProducts()
            async let fetchedOrders = database.fetchOrders()
            async let fetchedRestock = database.fetchRestockHistory()
            async let fetchedPriceHistory = database.fetchPriceHistory()
            
            let (prods, orders, restocks, prices) = try await (fetchedProducts, fetchedOrders, fetchedRestock, fetchedPriceHistory)
            
            self.products = prods
            self.pastOrders = orders
            self.restockHistory = restocks
            self.priceHistory = prices
            
            // Sync inventory dictionary from products
            self.inventory = [:]
            for product in prods {
                self.inventory[product.name.lowercased()] = product.stockQuantity
            }
            
            recalculateStats()
            
            if database.isMock {
                print("⚠️ Running in Mock Mode (Supabase not installed)")
                self.isDatabaseConnected = false
                self.databaseError = "Chưa cài đặt Supabase Package"
            } else {
                self.isDatabaseConnected = true
                self.databaseError = nil
            }
        } catch {
            print("Error loading data: \(error)")
            self.isDatabaseConnected = false
            self.databaseError = error.localizedDescription
        }
    }
    
    var suggestedItems: [String] {
        return priceHistory.keys.sorted()
    }
    
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.total }
    }
    
    func processInput() {
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
    
    private func handleOrderParsed(_ parsed: (name: String, quantity: Int, price: Double, discount: Double, discountIsPercent: Bool, isTotal: Bool?, intent: SmartIntent?)) {
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
        if let index = items.firstIndex(where: { $0.name == item.name && $0.price == item.price && $0.discount == item.discount && $0.systemImage == item.systemImage }) {
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
    
    private func handleRestockParsed(_ parsed: (name: String, quantity: Int, price: Double, discount: Double, discountIsPercent: Bool, isTotal: Bool?, intent: SmartIntent?)) {
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
        
        let additionalCost = -discountValue
        
        restockItems.append(RestockItem(name: finalName, quantity: quantity, unitPrice: unitPrice, additionalCost: additionalCost))
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
    
    func completeOrder() {
        // Create bill
        if let bill = makeBill() {
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
        revenue = pastOrders.reduce(0) { $0 + $1.total }
        orderCount = pastOrders.count
        totalRestockCost = restockHistory.reduce(0) { $0 + $1.totalCost }
    }
    
    // MARK: - Restock Actions
    
    func addRestockItem(_ name: String, unitPrice: Double, quantity: Int, additionalCost: Double = 0, suggestedPrice: Double? = nil) {
        restockItems.append(RestockItem(name: name, quantity: quantity, unitPrice: unitPrice, additionalCost: additionalCost, suggestedPrice: suggestedPrice))
    }
    
    func removeRestockItem(at offsets: IndexSet) {
        restockItems.remove(atOffsets: offsets)
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
                
                // Latest Purchase Price Logic (User Requirement)
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
                    price: item.suggestedPrice ?? (item.finalUnitCost * 1.3), // Use suggested or default 30% markup
                    costPrice: item.finalUnitCost, // Initial Cost
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
    }
    
    // MARK: - Product Catalog Management
    
    func createProduct(name: String, price: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil) {
        let newProduct = Product(
            id: UUID(),
            name: name,
            price: price,
            costPrice: costPrice,
            category: category.rawValue,
            imageName: imageName,
            color: color,
            imageData: imageData,
            stockQuantity: quantity
        )
        products.append(newProduct)
        
        Task {
            do {
                try await database.saveProduct(newProduct)
            } catch {
                print("❌ Error saving new product: \(error)")
            }
        }
        
        // Initialize inventory
        inventory[name.lowercased()] = quantity
    }
    
    func updateProduct(_ product: Product, name: String, price: Double, costPrice: Double, category: Category, imageName: String, color: String, quantity: Int, imageData: Data? = nil) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Handle Name Change for Inventory
            let oldKey = product.name.lowercased()
            let newKey = name.lowercased()
            
            if oldKey != newKey {
                inventory.removeValue(forKey: oldKey)
            }
            
            // Update Inventory
            inventory[newKey] = quantity
            
            let updatedProduct = Product(
                id: product.id,
                name: name,
                price: price,
                costPrice: costPrice,
                category: category.rawValue,
                imageName: imageName,
                color: color,
                imageData: imageData,
                stockQuantity: quantity
            )
            products[index] = updatedProduct
            
            Task {
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
        let updatedBill = Bill(id: originalBill.id, createdAt: originalBill.createdAt, items: items, total: newTotal)
        
        // Replace in history
        if let index = pastOrders.firstIndex(where: { $0.id == originalBill.id }) {
            pastOrders[index] = updatedBill
            
            Task {
                // Delete old and save new
                do {
                    try await database.deleteOrder(originalBill.id)
                    try await database.saveOrder(updatedBill)
                } catch {
                    print("❌ Error saving edited order: \(error)")
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
    
    func reset() {
        items.removeAll()
        currentInput = ""
        showPayment = false
        editingBill = nil
    }
    
    // MARK: - Calendar Stats
    func revenue(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.total }
    }
    
    func restockCost(for date: Date) -> Double {
        let calendar = Calendar.current
        return restockHistory
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.totalCost }
    }
    
    func profit(for date: Date) -> Double {
        let calendar = Calendar.current
        return pastOrders
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.profit }
    }
    
    func orders(for date: Date) -> [Bill] {
        let calendar = Calendar.current
        return pastOrders
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }
    
    func makeBill() -> Bill? {
        guard !items.isEmpty else { return nil }
        let cost = items.reduce(0) { $0 + $1.totalCost }
        return Bill(id: UUID(), createdAt: Date(), items: items, total: totalAmount, totalCost: cost)
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
        let amount = Int(bill.total)
        let base = "https://img.vietqr.io/image/VCB-9967861809-compact.png"
        
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
        } else {
            // Find cost price
            var cost: Double = 0
            if let product = products.first(where: { $0.name.lowercased() == name.lowercased() }) {
                cost = product.costPrice
            }
            items.append(OrderItem(name: name, quantity: quantity, price: price, costPrice: cost, discount: discount, imageData: imageData, systemImage: "cart.circle.fill"))
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
}
