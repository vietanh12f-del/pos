import Foundation

struct OrderItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var price: Double
    var costPrice: Double = 0 // Cost of Goods Sold (Unit Cost at time of sale)
    var imageData: Data?
    var systemImage: String?
    
    var total: Double {
        return Double(quantity) * price
    }
    
    var totalCost: Double {
        return Double(quantity) * costPrice
    }
}

struct RestockItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var unitPrice: Double
    var additionalCost: Double = 0 // Shipping, packaging, etc.
    var suggestedPrice: Double? = nil // User-defined or auto-calculated selling price
    
    var totalCost: Double {
        return (Double(quantity) * unitPrice) + additionalCost
    }
    
    var finalUnitCost: Double {
        return quantity > 0 ? totalCost / Double(quantity) : 0
    }
}

struct Bill: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let items: [OrderItem]
    let total: Double
    var totalCost: Double = 0 // Total COGS
    
    var profit: Double {
        total - totalCost
    }
    
    static func == (lhs: Bill, rhs: Bill) -> Bool {
        return lhs.id == rhs.id
    }
}

struct RestockBill: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let items: [RestockItem]
    let totalCost: Double
    
    static func == (lhs: RestockBill, rhs: RestockBill) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Product: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var price: Double
    var costPrice: Double = 0 // Moving Average Unit Cost
    var category: String
    var imageName: String
    var color: String
    var imageData: Data?
    var stockQuantity: Int = 0
}

enum Category: String, CaseIterable, Codable {
    case all = "Tất cả"
    case flowers = "Hoa tươi"
    case bouquets = "Bó hoa"
    case accessories = "Phụ kiện"
    case gifts = "Quà tặng"
    case materials = "Vật liệu"
    case decorations = "Trang trí"
    case others = "Khác"
    
    var displayName: String {
        return self.rawValue
    }
}

struct Employee: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phoneNumber: String
    var avatar: String // URL or image name
    var isOnline: Bool
    var role: String
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var senderId: UUID
    var text: String
    var timestamp: Date
    var isRead: Bool
}

struct ChatConversation: Identifiable, Codable, Hashable {
    var id = UUID()
    var employeeId: UUID
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
}

struct UserProfile: Identifiable, Codable {
    var id: UUID // Matches auth.users.id
    var fullName: String
    var email: String?
    var phoneNumber: String?
    var address: String?
    var avatarUrl: String?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phoneNumber = "phone_number"
        case address
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
