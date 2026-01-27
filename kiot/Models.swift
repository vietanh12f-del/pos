import Foundation

struct OrderItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: Int
    var price: Double
    
    var total: Double {
        return Double(quantity) * price
    }
}

struct Bill: Identifiable {
    let id: UUID
    let createdAt: Date
    let items: [OrderItem]
    let total: Double
}

struct Product: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Double
    let category: String
    let imageName: String
    let color: String
}

enum Category: String, CaseIterable {
    case all = "All Items"
    case coffee = "Coffee"
    case food = "Food"
    case drinks = "Drinks"
}
