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
    var weightPerUnitGrams: Int? = nil
    var isFinishedGood: Bool = false // Contextual flag for target product type
    var importFromFinishedGood: Bool = false
    var sourceFinishedGoodId: UUID? = nil
    var unit: String? = nil
    var hasVAT: Bool = false // Hàng hoá nhập có VAT hay không
    
    var totalCost: Double {
        if let u = unit, u.lowercased() == "cái" {
            return (Double(quantity) * unitPrice) + additionalCost
        }
        if let grams = weightPerUnitGrams, grams > 0 {
            let totalGrams = Double(quantity) * Double(grams)
            return (unitPrice * (totalGrams / 1000.0)) + additionalCost
        }
        if let cat = category, cat.lowercased() == Category.materials.rawValue.lowercased() {
            // quantity is in grams for materials; unitPrice is per kg
            return (unitPrice * (Double(quantity) / 1000.0)) + additionalCost
        } else {
            return (Double(quantity) * unitPrice) + additionalCost
        }
    }
    
    var finalUnitCost: Double {
        if let u = unit, u.lowercased() == "cái" {
            return quantity > 0 ? totalCost / Double(quantity) : 0
        }
        if let grams = weightPerUnitGrams, grams > 0 {
            return quantity > 0 ? totalCost / Double(quantity) : 0
        }
        if let cat = category, cat.lowercased() == Category.materials.rawValue.lowercased() {
            // quantity là gram, unitPrice là per kg
            // totalCost = unitPrice * (quantity/1000) + additionalCost
            // finalUnitCost per kg = totalCost / (quantity/1000)
            // Nhưng additionalCost là chi phí tổng lô hàng, phân bổ theo kg:
            // finalUnitCost per kg = unitPrice + (additionalCost / (quantity/1000))
            let kg = Double(quantity) / 1000.0
            guard kg > 0 else { return 0 }
            return unitPrice + (additionalCost / kg)
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
    var customerPhone: String? = nil // Walk-in customer phone
    var customerAddress: String? = nil // Walk-in customer address
    var customerEmail: String? = nil // Walk-in customer email
    var paymentReceiptURL: String? = nil // URL to payment receipt image
    var sequenceNumber: String? = nil // Unique order number
    var vatRate: Double? = nil // VAT rate percentage (e.g., 10 for 10%)
    var vatAmount: Double = 0 // VAT amount
    var paidAmount: Double? = nil // Amount paid
    var debtAmount: Double? = nil // Remaining debt
    var expectedPayDate: Date? = nil // Expected payment date
    var note: String? = nil // Notes for the order
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
    var deletedBy: UUID? = nil
    
    var profit: Double {
        total - totalCost
    }
    
    static func == (lhs: Bill, rhs: Bill) -> Bool {
        return lhs.id == rhs.id
            && lhs.total == rhs.total
            && lhs.items == rhs.items
            && lhs.isPaid == rhs.isPaid
            && lhs.isDeleted == rhs.isDeleted
            && lhs.paidAmount == rhs.paidAmount
            && lhs.debtAmount == rhs.debtAmount
            && lhs.customerName == rhs.customerName
            && lhs.sequenceNumber == rhs.sequenceNumber
            && lhs.note == rhs.note
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
    var sequenceNumber: String? = nil
    var supplierName: String? = nil
    var supplierPhone: String? = nil
    var supplierAddress: String? = nil
    var note: String? = nil
    
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
    // Import supplier info (for material import)
    var supplierName: String? = nil
    var supplierPhone: String? = nil
    var supplierAddress: String? = nil
    var supplierTaxCode: String? = nil
    // Export buyer & payment info
    var buyerName: String? = nil
    var buyerPhone: String? = nil
    var buyerAddress: String? = nil
    var buyerTaxCode: String? = nil
    var grandTotal: Double? = nil
    var paidAmount: Double? = nil
    var debtAmount: Double? = nil
    var vatRate: Double? = nil
    var vatAmount: Double? = nil
    var isPaid: Bool = false
    var expectedPayDate: Date? = nil
    var paymentReceiptURL: String? = nil
    var sequenceNumber: String? = nil
    // Soft delete
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
    var deletedByName: String? = nil
    var deleteNote: String? = nil
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
    var barcode: String? = nil
    var unit: String? = nil
    var hasVAT: Bool = false
    var minStockAlertThreshold: Int? = nil
    var expiryDate: Date? = nil
    var expiryAlertDays: Int? = nil
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
    var surplusThresholdKg: Int
    
    var autoSelectedMaterialIds: [UUID]
    var autoStandardPerPanGramsByMaterialId: [String: Int]
    
    var subSheets: [String]
    var subSheetData: [SubSheetTemplateData]
    
    // Backward compat: surplusThresholdKg defaults to 0 if missing
    enum CodingKeys: String, CodingKey {
        case headerName, freshTitle, afterBoilTitle, panCountTitle, panWeightTitle, autoMaterialsTitle
        case freshSelectedMaterialIds, freshExportGramsByMaterialId
        case afterBoilGrams, panCount, standardPanWeightGrams, surplusThresholdKg
        case autoSelectedMaterialIds, autoStandardPerPanGramsByMaterialId
        case subSheets, subSheetData
    }
    
    init(headerName: String, freshTitle: String, afterBoilTitle: String, panCountTitle: String, panWeightTitle: String, autoMaterialsTitle: String, freshSelectedMaterialIds: [UUID], freshExportGramsByMaterialId: [String: Int], afterBoilGrams: Int, panCount: Int, standardPanWeightGrams: Int, surplusThresholdKg: Int = 0, autoSelectedMaterialIds: [UUID], autoStandardPerPanGramsByMaterialId: [String: Int], subSheets: [String] = [], subSheetData: [SubSheetTemplateData] = []) {
        self.headerName = headerName
        self.freshTitle = freshTitle
        self.afterBoilTitle = afterBoilTitle
        self.panCountTitle = panCountTitle
        self.panWeightTitle = panWeightTitle
        self.autoMaterialsTitle = autoMaterialsTitle
        self.freshSelectedMaterialIds = freshSelectedMaterialIds
        self.freshExportGramsByMaterialId = freshExportGramsByMaterialId
        self.afterBoilGrams = afterBoilGrams
        self.panCount = panCount
        self.standardPanWeightGrams = standardPanWeightGrams
        self.surplusThresholdKg = surplusThresholdKg
        self.autoSelectedMaterialIds = autoSelectedMaterialIds
        self.autoStandardPerPanGramsByMaterialId = autoStandardPerPanGramsByMaterialId
        self.subSheets = subSheets
        self.subSheetData = subSheetData
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headerName = try c.decode(String.self, forKey: .headerName)
        freshTitle = try c.decode(String.self, forKey: .freshTitle)
        afterBoilTitle = try c.decode(String.self, forKey: .afterBoilTitle)
        panCountTitle = try c.decode(String.self, forKey: .panCountTitle)
        panWeightTitle = try c.decode(String.self, forKey: .panWeightTitle)
        autoMaterialsTitle = try c.decode(String.self, forKey: .autoMaterialsTitle)
        freshSelectedMaterialIds = try c.decode([UUID].self, forKey: .freshSelectedMaterialIds)
        freshExportGramsByMaterialId = try c.decode([String: Int].self, forKey: .freshExportGramsByMaterialId)
        afterBoilGrams = try c.decode(Int.self, forKey: .afterBoilGrams)
        panCount = try c.decode(Int.self, forKey: .panCount)
        standardPanWeightGrams = try c.decode(Int.self, forKey: .standardPanWeightGrams)
        surplusThresholdKg = (try? c.decodeIfPresent(Int.self, forKey: .surplusThresholdKg)) ?? 0
        autoSelectedMaterialIds = try c.decode([UUID].self, forKey: .autoSelectedMaterialIds)
        autoStandardPerPanGramsByMaterialId = try c.decode([String: Int].self, forKey: .autoStandardPerPanGramsByMaterialId)
        subSheets = (try? c.decodeIfPresent([String].self, forKey: .subSheets)) ?? []
        subSheetData = (try? c.decodeIfPresent([SubSheetTemplateData].self, forKey: .subSheetData)) ?? []
    }
}

/// Dữ liệu lưu trữ cho một sub-sheet trong template
struct SubSheetTemplateData: Codable, Equatable {
    var name: String
    var afterBoilGrams: Int
    var panCount: Int
    var standardPanWeightGrams: Int
    var surplusThresholdKg: Int
    var autoStandardPerPanGramsByMaterialId: [String: Int]

    init(name: String, afterBoilGrams: Int = 0, panCount: Int = 1, standardPanWeightGrams: Int = 0, surplusThresholdKg: Int = 0, autoStandardPerPanGramsByMaterialId: [String: Int] = [:]) {
        self.name = name
        self.afterBoilGrams = afterBoilGrams
        self.panCount = panCount
        self.standardPanWeightGrams = standardPanWeightGrams
        self.surplusThresholdKg = surplusThresholdKg
        self.autoStandardPerPanGramsByMaterialId = autoStandardPerPanGramsByMaterialId
    }
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
    var subSheetLogs: [SubSheetLogData]

    enum CodingKeys: String, CodingKey {
        case headerName, freshTitle, afterBoilTitle, panCountTitle, panWeightTitle, autoMaterialsTitle
        case fresh, afterBoilGrams, panCount, standardPanWeightGrams, actualPanWeightGrams, percentChange
        case autoMaterials, subSheetLogs
    }

    init(headerName: String, freshTitle: String, afterBoilTitle: String, panCountTitle: String, panWeightTitle: String, autoMaterialsTitle: String, fresh: [AutoMaterialExportLogRow], afterBoilGrams: Int, panCount: Int, standardPanWeightGrams: Int, actualPanWeightGrams: Double, percentChange: Double, autoMaterials: [AutoMaterialExportLogRow], subSheetLogs: [SubSheetLogData] = []) {
        self.headerName = headerName
        self.freshTitle = freshTitle
        self.afterBoilTitle = afterBoilTitle
        self.panCountTitle = panCountTitle
        self.panWeightTitle = panWeightTitle
        self.autoMaterialsTitle = autoMaterialsTitle
        self.fresh = fresh
        self.afterBoilGrams = afterBoilGrams
        self.panCount = panCount
        self.standardPanWeightGrams = standardPanWeightGrams
        self.actualPanWeightGrams = actualPanWeightGrams
        self.percentChange = percentChange
        self.autoMaterials = autoMaterials
        self.subSheetLogs = subSheetLogs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        headerName = try c.decode(String.self, forKey: .headerName)
        freshTitle = try c.decode(String.self, forKey: .freshTitle)
        afterBoilTitle = try c.decode(String.self, forKey: .afterBoilTitle)
        panCountTitle = try c.decode(String.self, forKey: .panCountTitle)
        panWeightTitle = try c.decode(String.self, forKey: .panWeightTitle)
        autoMaterialsTitle = try c.decode(String.self, forKey: .autoMaterialsTitle)
        fresh = try c.decode([AutoMaterialExportLogRow].self, forKey: .fresh)
        afterBoilGrams = try c.decode(Int.self, forKey: .afterBoilGrams)
        panCount = try c.decode(Int.self, forKey: .panCount)
        standardPanWeightGrams = try c.decode(Int.self, forKey: .standardPanWeightGrams)
        actualPanWeightGrams = try c.decode(Double.self, forKey: .actualPanWeightGrams)
        percentChange = try c.decode(Double.self, forKey: .percentChange)
        autoMaterials = try c.decode([AutoMaterialExportLogRow].self, forKey: .autoMaterials)
        subSheetLogs = (try? c.decodeIfPresent([SubSheetLogData].self, forKey: .subSheetLogs)) ?? []
    }
}

/// Dữ liệu log của một sub-sheet
struct SubSheetLogData: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let afterBoilGrams: Int
    let panCount: Int
    let standardPanWeightGrams: Int
    let actualPanWeightGrams: Double
    let autoMaterials: [AutoMaterialExportLogRow]
    let extraPanRows: [AutoMaterialExportLogRow]

    init(id: UUID = UUID(), name: String, afterBoilGrams: Int, panCount: Int, standardPanWeightGrams: Int, actualPanWeightGrams: Double, autoMaterials: [AutoMaterialExportLogRow], extraPanRows: [AutoMaterialExportLogRow] = []) {
        self.id = id
        self.name = name
        self.afterBoilGrams = afterBoilGrams
        self.panCount = panCount
        self.standardPanWeightGrams = standardPanWeightGrams
        self.actualPanWeightGrams = actualPanWeightGrams
        self.autoMaterials = autoMaterials
        self.extraPanRows = extraPanRows
    }
}

/// Lightweight struct để truyền sub-sheet data vào performAutoMaterialExport
struct SubSheetSlipForLog {
    let name: String
    let afterBoilGrams: Int
    let panCount: Int
    let standardPanWeightGrams: Int
    let actualPanWeightGrams: Double
    let autoRows: [AutoMaterialExportLogRow]
    let extraPanRows: [AutoMaterialExportLogRow]
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
    var productPrice: Double = 0 // Giá sản phẩm
    var shippingCost: Double = 0 // Chi phí vận chuyển
    var costPrice: Double = 0 // Moving Average Unit Cost (giá sản phẩm + chi phí vận chuyển)
    var category: String
    var imageName: String
    var color: String
    var imageData: Data?
    var imageURL: String? // URL for remote image
    var stockQuantity: Int = 0
    var barcode: String? // New barcode field
    var isFinishedGood: Bool = false
    var hasVAT: Bool = false // Hàng hoá nhập có VAT hay không
    var additionalInfo: String? // Thông tin thêm

    init(id: UUID = UUID(), name: String, price: Double, productPrice: Double = 0, shippingCost: Double = 0, costPrice: Double = 0, category: String, imageName: String, color: String, imageData: Data? = nil, imageURL: String? = nil, stockQuantity: Int = 0, barcode: String? = nil, isFinishedGood: Bool = false, hasVAT: Bool = false, additionalInfo: String? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.productPrice = productPrice
        self.shippingCost = shippingCost
        self.costPrice = costPrice
        self.category = category
        self.imageName = imageName
        self.color = color
        self.imageData = imageData
        self.imageURL = imageURL
        self.stockQuantity = stockQuantity
        self.barcode = barcode
        self.isFinishedGood = isFinishedGood
        self.hasVAT = hasVAT
        self.additionalInfo = additionalInfo
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
    case viewStatistics = "view_statistics"
    case viewInventoryReports = "view_inventory_reports"
    case viewProduction = "view_production"
    case manageProduction = "manage_production"
    case manageCustomers = "manage_customers"
    case manageProducts = "manage_products"
    
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
        case .viewStatistics: return "Xem Thống kê & Doanh thu lợi nhuận"
        case .viewInventoryReports: return "Xem Báo cáo kho"
        case .viewProduction: return "Xem Báo cáo sản xuất"
        case .manageProduction: return "Quản lý sản xuất (Tạo/Sửa/Xóa)"
        case .manageCustomers: return "Quản lý khách hàng"
        case .manageProducts: return "Quản lý sản phẩm"
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
    let userId: UUID?
    var email: String?
    var role: StoreRole
    var permissions: [StorePermission]?
    var positionTitle: String?
    var status: MemberStatus?
    var joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case userId = "user_id"
        case email
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
