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
    var category: String? = nil
    var source: String? = nil
    var documentImageURL: String? = nil
    
    var totalCost: Double {
        if let cat = category, cat.lowercased() == Category.materials.rawValue.lowercased() {
            // quantity is in grams for materials; unitPrice is per kg
            return (unitPrice * (Double(quantity) / 1000.0)) + additionalCost
        } else {
            return (Double(quantity) * unitPrice) + additionalCost
        }
    }
    
    var finalUnitCost: Double {
        if let cat = category, cat.lowercased() == Category.materials.rawValue.lowercased() {
            // unit cost per kg
            let kg = Double(quantity) / 1000.0
            return kg > 0 ? totalCost / kg : 0
        } else {
            return quantity > 0 ? totalCost / Double(quantity) : 0
        }
    }
}

struct Bill: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let items: [OrderItem]
    let total: Double
    var totalCost: Double = 0 // Total COGS
    var isPaid: Bool = true // Payment status
    var creatorId: UUID? = nil // ID of the user who created the order
    var creatorName: String? = nil // Name of the user who created the order
    var customerName: String? = nil // Walk-in customer name (edited in order)
    var paymentReceiptURL: String? = nil // URL to payment receipt image
    
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
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
    var deletedBy: UUID? = nil
    var creatorId: UUID? = nil
    var creatorName: String? = nil
    
    static func == (lhs: RestockBill, rhs: RestockBill) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ProductionTransaction: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let mode: String
    let items: [RestockItem]
    var creatorId: UUID? = nil
    var creatorName: String? = nil
    let totalCost: Double
    var note: String? = nil
    static func == (lhs: ProductionTransaction, rhs: ProductionTransaction) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MaterialItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var stockQuantity: Int
    var lastUnitPrice: Double
    var category: String = Category.materials.rawValue
}

struct OperatingExpense: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var amount: Double
    var note: String?
    var createdAt: Date
    var creatorId: UUID? = nil
    var creatorName: String? = nil
}

struct UserFeedback: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var createdAt: Date
    var userId: UUID?
    var storeId: UUID?
}

struct OrderEdit: Identifiable, Codable, Equatable {
    let id: UUID
    let orderId: UUID
    let createdAt: Date
    let oldTotal: Double
    let newTotal: Double
    let editorId: UUID?
    let editorName: String?
    let note: String?
    let details: [String]?
}

struct ProductionEdit: Identifiable, Codable, Equatable {
    let id: UUID
    let transactionId: UUID
    let createdAt: Date
    let oldTotal: Double
    let newTotal: Double
    let editorId: UUID?
    let editorName: String?
    let note: String?
    let details: [String]?
}

struct RestockEdit: Identifiable, Codable, Equatable {
    let id: UUID
    let restockBillId: UUID
    let createdAt: Date
    let oldTotal: Double
    let newTotal: Double
    let editorId: UUID?
    let editorName: String?
    let note: String?
    let details: [String]?
}

struct AutoMaterialExportTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    var data: AutoMaterialExportTemplateData
    let createdAt: Date
    var updatedAt: Date
}

struct AutoMaterialExportTemplateData: Codable, Equatable {
    var headerName: String
    
    var freshTitle: String
    var afterBoilTitle: String
    var panCountTitle: String
    var panWeightTitle: String
    var autoMaterialsTitle: String
    
    var freshSelectedMaterialIds: [UUID]
    var freshExportGramsByMaterialId: [String: Int]
    
    var afterBoilGrams: Int
    var panCount: Int
    var standardPanWeightGrams: Int
    
    var autoSelectedMaterialIds: [UUID]
    var autoStandardPerPanGramsByMaterialId: [String: Int]
}

struct AutoMaterialExportLog: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let templateId: UUID?
    let templateName: String
    let productionTransactionId: UUID
    let data: AutoMaterialExportLogData
    var creatorId: UUID? = nil
    var creatorName: String? = nil
}

struct AutoMaterialExportLogData: Codable, Equatable {
    let headerName: String
    
    let freshTitle: String
    let afterBoilTitle: String
    let panCountTitle: String
    let panWeightTitle: String
    let autoMaterialsTitle: String
    
    let fresh: [AutoMaterialExportLogRow]
    let afterBoilGrams: Int
    let panCount: Int
    let standardPanWeightGrams: Int
    let actualPanWeightGrams: Double
    let percentChange: Double
    
    let autoMaterials: [AutoMaterialExportLogRow]
}

struct AutoMaterialExportLogRow: Codable, Equatable, Identifiable {
    let id: UUID
    let materialId: UUID?
    let name: String
    let stockGrams: Int
    let standardPerPanGrams: Double?
    let actualPerPanGrams: Double?
    let totalExportGrams: Double
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
    var imageURL: String? // URL for remote image
    var stockQuantity: Int = 0
    var barcode: String? // New barcode field
    var isFinishedGood: Bool = false
    
    init(id: UUID = UUID(), name: String, price: Double, costPrice: Double = 0, category: String, imageName: String, color: String, imageData: Data? = nil, imageURL: String? = nil, stockQuantity: Int = 0, barcode: String? = nil, isFinishedGood: Bool = false) {
        self.id = id
        self.name = name
        self.price = price
        self.costPrice = costPrice
        self.category = category
        self.imageName = imageName
        self.color = color
        self.imageData = imageData
        self.imageURL = imageURL
        self.stockQuantity = stockQuantity
        self.barcode = barcode
        self.isFinishedGood = isFinishedGood
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

enum AccountRole: String, Codable, CaseIterable, Hashable {
    case owner
    case employee
    
    var displayName: String {
        switch self {
        case .owner: return "Chủ cửa hàng"
        case .employee: return "Nhân viên"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .owner: return "crown.fill"
        case .employee: return "person.2.fill"
        }
    }
    
    var subtitle: String {
        switch self {
        case .owner: return "Quản lý mọi tính năng"
        case .employee: return "Bán hàng, kho, chat"
        }
    }
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
    var accountRole: AccountRole?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phoneNumber = "phone_number"
        case address
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case currentStoreId = "current_store_id"
        case accountRole = "account_role"
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
    case viewCustomization = "view_customization"
    case manageEmployees = "manage_employees"
    case deleteEmployee = "delete_employee"
    
    var displayName: String {
        switch self {
        case .viewHome: return "Xem Trang chủ"
        case .viewOrders: return "Xem Đơn hàng"
        case .viewInventory: return "Xem Kho hàng"
        case .viewExpenses: return "Xem Chi phí"
        case .viewReports: return "Xem Báo cáo"
        case .viewCustomization: return "Xem Tuỳ chỉnh"
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
    var positionTitle: String?
    var status: MemberStatus?
    var joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case userId = "user_id"
        case role
        case permissions
        case positionTitle = "position_title"
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

struct ChatGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String?
    let ownerId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerId = "owner_id"
        case createdAt = "created_at"
    }
}

struct ChatGroupMember: Identifiable, Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case addedAt = "added_at"
    }
}

struct GroupMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let groupId: UUID
    let senderId: UUID
    let text: String
    let timestamp: Date
    var messageType: String?
    var orderId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case senderId = "sender_id"
        case text = "content"
        case timestamp = "created_at"
        case messageType = "message_type"
        case orderId = "order_id"
    }
}
