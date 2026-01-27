import Foundation

struct OrderItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var price: Double
    var imageData: Data?
    var systemImage: String?
    
    var total: Double {
        return Double(quantity) * price
    }
}

struct Bill: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let items: [OrderItem]
    let total: Double
    
    static func == (lhs: Bill, rhs: Bill) -> Bool {
        return lhs.id == rhs.id
    }
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
    case flowers = "Flowers"
    case bouquets = "Bouquets"
    case accessories = "Accessories"
}
