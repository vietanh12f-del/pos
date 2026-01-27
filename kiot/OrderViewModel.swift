import Foundation
import Combine
import SwiftUI

class OrderViewModel: ObservableObject {
    @Published var currentInput: String = ""
    @Published var items: [OrderItem] = []
    @Published var showPayment: Bool = false
    
    @Published var priceHistory: [String: Double] = [:]
    @Published var pastOrders: [Bill] = []
    
    // Dashboard Stats
    @Published var revenue: Double = 2500000 // Demo starting value
    @Published var orderCount: Int = 24       // Demo starting value
    
    // Catalog & Dashboard
    @Published var selectedCategory: Category = .all
    @Published var products: [Product] = [
        Product(name: "Red Rose", price: 20000, category: "Flowers", imageName: "rosette", color: "red"),
        Product(name: "Sunflower", price: 30000, category: "Flowers", imageName: "sun.max.fill", color: "yellow"),
        Product(name: "Tulip", price: 25000, category: "Flowers", imageName: "camera.macro", color: "purple"),
        Product(name: "Mixed Bouquet", price: 350000, category: "Bouquets", imageName: "gift.fill", color: "pink"),
        Product(name: "Birthday Bouquet", price: 500000, category: "Bouquets", imageName: "birthday.cake.fill", color: "blue"),
        Product(name: "Vase", price: 150000, category: "Accessories", imageName: "cylinder.split.1x2.fill", color: "gray"),
        Product(name: "Ribbon", price: 10000, category: "Accessories", imageName: "scribble.variable", color: "red"),
        Product(name: "Greeting Card", price: 15000, category: "Accessories", imageName: "envelope.fill", color: "orange")
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
        
        if let savedOrdersData = UserDefaults.standard.data(forKey: "PastOrders"),
           let decodedOrders = try? JSONDecoder().decode([Bill].self, from: savedOrdersData) {
            pastOrders = decodedOrders
            // Recalculate stats based on history
            revenue = pastOrders.reduce(0) { $0 + $1.total }
            orderCount = pastOrders.count
        }
        
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
    
    private func saveHistory() {
        UserDefaults.standard.set(priceHistory, forKey: "PriceHistory")
    }
    
    private func parseItem(from text: String) -> OrderItem? {
        // Use SmartParser for flexible "AI-like" parsing
        if let parsed = SmartParser.parse(text: text) {
            var price = parsed.price
            
            // Auto-fill price from history if missing
            if price == 0 {
                if let historyPrice = priceHistory[parsed.name.lowercased()] {
                    price = historyPrice
                }
            }
            
            return OrderItem(name: parsed.name, quantity: parsed.quantity, price: price)
        }
        return nil
    }
    
    func removeItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func completeOrder() {
        // Create bill
        if let bill = makeBill() {
            pastOrders.insert(bill, at: 0) // Newest first
            saveOrders()
            
            // Update stats
            recalculateStats()
        }
        
        // Clear order
        reset()
    }
    
    func recalculateStats() {
        revenue = pastOrders.reduce(0) { $0 + $1.total }
        orderCount = pastOrders.count
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
