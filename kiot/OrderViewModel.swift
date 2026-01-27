import Foundation
import Combine
import SwiftUI

class OrderViewModel: ObservableObject {
    @Published var currentInput: String = ""
    @Published var items: [OrderItem] = []
    @Published var showPayment: Bool = false
    
    @Published var priceHistory: [String: Double] = [:]
    
    // Dashboard Stats
    @Published var revenue: Double = 2500000 // Demo starting value
    @Published var orderCount: Int = 24       // Demo starting value
    
    // Catalog & Dashboard
    @Published var selectedCategory: Category = .all
    @Published var products: [Product] = [
        Product(name: "Iced Latte", price: 45000, category: "Coffee", imageName: "cup.and.saucer.fill", color: "brown"),
        Product(name: "Croissant", price: 35000, category: "Food", imageName: "birthday.cake", color: "orange"),
        Product(name: "Espresso", price: 30000, category: "Coffee", imageName: "mug", color: "black"),
        Product(name: "Blueberry Muffin", price: 35000, category: "Food", imageName: "birthday.cake.fill", color: "purple"),
        Product(name: "Cold Brew", price: 50000, category: "Coffee", imageName: "mug.fill", color: "blue"),
        Product(name: "Bagel", price: 40000, category: "Food", imageName: "circle.fill", color: "yellow"),
        Product(name: "Green Tea", price: 40000, category: "Drinks", imageName: "leaf.fill", color: "green"),
        Product(name: "Lemonade", price: 45000, category: "Drinks", imageName: "drop.fill", color: "yellow")
    ]
    
    var filteredProducts: [Product] {
        if selectedCategory == .all {
            return products
        }
        return products.filter { $0.category == selectedCategory.rawValue }
    }
    
    func addProduct(_ product: Product) {
        if let index = items.firstIndex(where: { $0.name == product.name && $0.price == product.price }) {
            items[index].quantity += 1
        } else {
            items.append(OrderItem(name: product.name, quantity: 1, price: product.price))
        }
    }
    
    // Speech integration
    @Published var speechRecognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "PriceHistory") as? [String: Double] {
            priceHistory = saved
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
        // Update stats
        revenue += totalAmount
        orderCount += 1
        
        // Clear order
        reset()
    }
    
    func reset() {
        items.removeAll()
        currentInput = ""
        showPayment = false
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
}
