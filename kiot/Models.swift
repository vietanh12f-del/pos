import Foundation

struct OrderItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var price: Double
    var costPrice: Double = 0 // Cost of Goods Sold (Unit Cost at time of sale)
    var discount: Double = 0 // Discount amount (absolute value)
    var imageData: Data?
    var systemImage: String?
    
    var total: Double {
        return (Double(quantity) * price) - discount
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
    var isConfirmed: Bool = false // Check/Verify status
    
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

struct OperatingExpense: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var amount: Double
    var note: String?
    var createdAt: Date
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
    
    init(id: UUID = UUID(), name: String, price: Double, costPrice: Double = 0, category: String, imageName: String, color: String, imageData: Data? = nil, stockQuantity: Int = 0) {
        self.id = id
        self.name = name
        self.price = price
        self.costPrice = costPrice
        self.category = category
        self.imageName = imageName
        self.color = color
        self.imageData = imageData
        self.stockQuantity = stockQuantity
    }
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

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var fullName: String
    var email: String?
    var phoneNumber: String?
    var address: String?
    var avatarUrl: String?
    var createdAt: Date
    var currentStoreId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phoneNumber = "phone_number"
        case address
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case currentStoreId = "current_store_id"
    }
}

// MARK: - Multi-Store Models

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var address: String?
    var ownerId: UUID
    var createdAt: Date
    var bankAccountNumber: String?
    var bankName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case bankAccountNumber = "bank_account_number"
        case bankName = "bank_name"
    }
}

enum StoreRole: String, Codable, CaseIterable {
    case owner
    case manager
    case employee
    
    var displayName: String {
        switch self {
        case .owner: return "Chủ cửa hàng"
        case .manager: return "Quản lý"
        case .employee: return "Nhân viên"
        }
    }
}

enum StorePermission: String, Codable, CaseIterable, Hashable {
    case viewHome = "view_home"
    case viewOrders = "view_orders"
    case viewInventory = "view_inventory"
    case viewExpenses = "view_expenses"
    case viewReports = "view_reports"
    case manageEmployees = "manage_employees"
    case deleteEmployee = "delete_employee"
    
    var displayName: String {
        switch self {
        case .viewHome: return "Xem Trang chủ"
        case .viewOrders: return "Xem Đơn hàng"
        case .viewInventory: return "Xem Kho hàng"
        case .viewExpenses: return "Xem Chi phí"
        case .viewReports: return "Xem Báo cáo"
        case .manageEmployees: return "Quản lý Nhân viên"
        case .deleteEmployee: return "Xóa Nhân viên"
        }
    }
}

enum MemberStatus: String, Codable {
    case active
    case invited
    case declined
}

struct StoreMember: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID
    let userId: UUID
    var role: StoreRole
    var permissions: [StorePermission]?
    var status: MemberStatus?
    var joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case userId = "user_id"
        case role
        case permissions
        case status
        case joinedAt = "joined_at"
    }
}

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let senderId: UUID
    let receiverId: UUID
    let text: String
    let timestamp: Date
    var isRead: Bool
    var messageType: String?
    var orderId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case text = "content"
        case timestamp = "created_at"
        case isRead = "is_read"
        case messageType = "message_type"
        case orderId = "order_id"
    }
}

struct ChatConversation: Identifiable, Hashable {
    var id: UUID { participantId }
    let participantId: UUID
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
}
