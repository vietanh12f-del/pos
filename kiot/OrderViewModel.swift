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
    
    // Dashboard Stats
    @Published var revenue: Double = 0
    @Published var orderCount: Int = 0
    @Published var totalRestockCost: Double = 0
    @Published var showOrderSuccessToast: Bool = false
    
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
    
    func addProduct(_ product: Product) {
        if let index = items.firstIndex(where: { $0.name == product.name && $0.price == product.price && $0.systemImage == product.imageName }) {
            items[index].quantity += 1
        } else {
            items.append(OrderItem(name: product.name, quantity: 1, price: product.price, systemImage: product.imageName))
        }
    }
    
    // Speech integration
    @Published var speechRecognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "PriceHistory") as? [String: Double] {
            priceHistory = saved
        }
        
        if let savedInventory = UserDefaults.standard.dictionary(forKey: "Inventory") as? [String: Int] {
            inventory = savedInventory
        }
        
        if let savedProductsData = UserDefaults.standard.data(forKey: "Products"),
           let decodedProducts = try? JSONDecoder().decode([Product].self, from: savedProductsData) {
            products = decodedProducts
        }
        
        // Ensure inventory keys exist for all products
        for product in products {
            let key = product.name.lowercased()
            if inventory[key] == nil {
                inventory[key] = 0
            }
        }
        
        if let savedOrdersData = UserDefaults.standard.data(forKey: "PastOrders"),
           let decodedOrders = try? JSONDecoder().decode([Bill].self, from: savedOrdersData) {
            pastOrders = decodedOrders
        }
        
        if let savedRestockData = UserDefaults.standard.data(forKey: "RestockHistory"),
           let decodedRestock = try? JSONDecoder().decode([RestockBill].self, from: savedRestockData) {
            restockHistory = decodedRestock
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
    
    var suggestedItems: [String] {
        return priceHistory.keys.sorted()
    }
    
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.total }
    }
    
    func processInput() {
        if isRestockMode {
            processRestockInput()
            return
        }
        
        let rawText = currentInput
        let lines = rawText.components(separatedBy: CharacterSet(charactersIn: ",\n"))
        
        for line in lines {
            if let item = parseItem(from: line) {
                items.append(item)
                // Update history if price is valid
                if item.price > 0 {
                    priceHistory[item.name.lowercased()] = item.price
                    saveHistory()
                }
            }
        }
        
        currentInput = ""
    }
    
    func processRestockInput() {
        let rawText = currentInput
        let lines = rawText.components(separatedBy: CharacterSet(charactersIn: ",\n"))
        
        for line in lines {
            if let parsed = SmartParser.parse(text: line) {
                var finalName = parsed.name
                
                // Intelligent Mapping: Match with existing catalog to ensure inventory consistency
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
                        // Heuristic fallback
                        // If price is very large (e.g. > 500k), it's likely Total Cost.
                        // UNLESS quantity is 1, then Unit = Total.
                        if quantity == 1 {
                             unitPrice = rawPrice
                        } else if rawPrice > 500_000 {
                            // Assume Total Cost
                            unitPrice = rawPrice / Double(quantity)
                        } else {
                            // Assume Unit Price
                            unitPrice = rawPrice
                        }
                    }
                }
                
                restockItems.append(RestockItem(name: finalName, quantity: quantity, unitPrice: unitPrice))
            }
        }
        currentInput = ""
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(priceHistory, forKey: "PriceHistory")
    }
    
    private func saveInventory() {
        UserDefaults.standard.set(inventory, forKey: "Inventory")
    }
    
    func stockLevel(for name: String) -> Int {
        return inventory[name.lowercased()] ?? 0
    }
    
    private func parseItem(from text: String) -> OrderItem? {
        // Use SmartParser for flexible "AI-like" parsing
        if let parsed = SmartParser.parse(text: text) {
            var finalName = parsed.name
            var price = parsed.price
            var systemImage: String? = nil
            
            // 1. Try to find matching product in catalog (Intelligent Mapping)
            if let match = SmartParser.findBestMatch(name: parsed.name, in: products) {
                finalName = match.name
                systemImage = match.imageName
                
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
            
            return OrderItem(name: finalName, quantity: parsed.quantity, price: price, systemImage: systemImage)
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
            saveOrders()
            
            // Deduct from Inventory
            for item in bill.items {
                let key = item.name.lowercased()
                if let current = inventory[key] {
                    inventory[key] = max(0, current - item.quantity)
                }
            }
            saveInventory()
            
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
    
    func addRestockItem(_ name: String, unitPrice: Double, quantity: Int) {
        restockItems.append(RestockItem(name: name, quantity: quantity, unitPrice: unitPrice))
    }
    
    func removeRestockItem(at offsets: IndexSet) {
        restockItems.remove(atOffsets: offsets)
    }
    
    func completeRestockSession() {
        guard !restockItems.isEmpty else { return }
        
        let total = restockItems.reduce(0) { $0 + $1.totalCost }
        let bill = RestockBill(id: UUID(), createdAt: Date(), items: restockItems, totalCost: total)
        
        restockHistory.insert(bill, at: 0)
        
        // Update Inventory & Catalog
        for item in restockItems {
            let key = item.name.lowercased()
            let current = inventory[key] ?? 0
            inventory[key] = current + item.quantity
            
            // Auto-add to products if not exists OR update if needed
            // Check case-insensitive
            if let index = products.firstIndex(where: { $0.name.lowercased() == key }) {
                // Product exists. Do we update anything?
                // User asked: "update items in stock is not update in new order items"
                // Maybe they want the price to update?
                // But sales price != cost price.
                // However, often users want to see the item "Available" or refreshed.
                // If the inventory was 0 and now is > 0, it should just work via stockLevel check.
                // But let's trigger a refresh by ensuring persistence.
                
                // OPTIONAL: If the sales price is 0 (placeholder), maybe update it?
                // Let's NOT overwrite sales price with cost price unless explicitly requested, 
                // as that ruins profit margins.
                // BUT, we must ensure the product is "active".
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
                    price: item.unitPrice * 1.3, // Suggest a markup? Or just use unitPrice? Let's use unitPrice for now as baseline.
                    category: cat.rawValue,
                    imageName: "shippingbox.fill", // Default icon
                    color: "gray"
                )
                products.append(newProduct)
            }
        }
        
        saveRestockHistory()
        saveInventory()
        saveProducts()
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
                    inventory[key] = max(0, current - item.quantity)
                }
            }
            
            restockHistory.remove(at: index)
            saveRestockHistory()
            saveInventory()
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
    
    private func saveRestockHistory() {
        if let encoded = try? JSONEncoder().encode(restockHistory) {
            UserDefaults.standard.set(encoded, forKey: "RestockHistory")
        }
    }
    
    // MARK: - Product Catalog Management
    
    func createProduct(name: String, price: Double, category: Category, imageName: String, color: String, quantity: Int) {
        let newProduct = Product(
            id: UUID(),
            name: name,
            price: price,
            category: category.rawValue,
            imageName: imageName,
            color: color
        )
        products.append(newProduct)
        saveProducts()
        
        // Initialize inventory
        inventory[name.lowercased()] = quantity
        saveInventory()
    }
    
    func updateProduct(_ product: Product, name: String, price: Double, category: Category, imageName: String, color: String, quantity: Int) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Handle Name Change for Inventory
            let oldKey = product.name.lowercased()
            let newKey = name.lowercased()
            
            if oldKey != newKey {
                inventory.removeValue(forKey: oldKey)
            }
            
            // Update Inventory
            inventory[newKey] = quantity
            saveInventory()
            
            let updatedProduct = Product(
                id: product.id,
                name: name,
                price: price,
                category: category.rawValue,
                imageName: imageName,
                color: color
            )
            products[index] = updatedProduct
            saveProducts()
        }
    }
    
    func deleteProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            // Remove inventory
            inventory.removeValue(forKey: product.name.lowercased())
            saveInventory()
            
            products.remove(at: index)
            saveProducts()
        }
    }
    
    func deleteProducts(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
        saveProducts()
    }

    private func saveProducts() {
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: "Products")
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
            saveOrders()
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
            saveOrders()
            recalculateStats()
        }
    }
    
    func deleteOrder(at offsets: IndexSet) {
        pastOrders.remove(atOffsets: offsets)
        saveOrders()
        recalculateStats()
    }

    private func saveOrders() {
        if let encoded = try? JSONEncoder().encode(pastOrders) {
            UserDefaults.standard.set(encoded, forKey: "PastOrders")
        }
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
        revenue(for: date) - restockCost(for: date)
    }
    
    func orders(for date: Date) -> [Bill] {
        let calendar = Calendar.current
        return pastOrders
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }
    
    func makeBill() -> Bill? {
        guard !items.isEmpty else { return nil }
        return Bill(id: UUID(), createdAt: Date(), items: items, total: totalAmount)
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
    func addItem(_ name: String, price: Double, quantity: Int, imageData: Data? = nil) {
        if let index = items.firstIndex(where: { $0.name == name && $0.price == price && $0.imageData == imageData }) {
            items[index].quantity += quantity
        } else {
            items.append(OrderItem(name: name, quantity: quantity, price: price, imageData: imageData, systemImage: "cart.circle.fill"))
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
    
    func updateItemFull(_ item: OrderItem, name: String, price: Double, quantity: Int, imageData: Data?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].name = name
            items[index].price = price
            items[index].quantity = quantity
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
