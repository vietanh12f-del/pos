import Foundation
import Supabase

// MARK: - Database Service Interface
protocol DatabaseService {
    var isMock: Bool { get }
    
    func fetchProducts() async throws -> [Product]
    func saveProduct(_ product: Product) async throws
    func updateProduct(_ product: Product) async throws
    func deleteProduct(_ id: UUID) async throws
    
    func fetchOrders() async throws -> [Bill]
    func saveOrder(_ bill: Bill) async throws
    func deleteOrder(_ id: UUID) async throws
    
    func fetchRestockHistory() async throws -> [RestockBill]
    func saveRestockBill(_ bill: RestockBill) async throws
    func deleteRestockBill(_ id: UUID) async throws
    
    func fetchPriceHistory() async throws -> [String: Double]
    func upsertPriceHistory(name: String, price: Double) async throws
    
    func fetchOperatingExpenses() async throws -> [OperatingExpense]
    func saveOperatingExpense(_ expense: OperatingExpense) async throws
    func updateOperatingExpense(_ expense: OperatingExpense) async throws
    func deleteOperatingExpense(_ id: UUID) async throws
    
    func fetchProfile(id: UUID) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    
    func deleteStore(_ id: UUID) async throws
}

// MARK: - Supabase Implementation
// Note: Add 'Supabase' package via File > Add Packages... -> https://github.com/supabase/supabase-swift.git

#if canImport(Supabase)
class SupabaseDatabaseService: DatabaseService {
    var isMock: Bool { false }
    let client: SupabaseClient
    
    init() {
        self.client = SupabaseConfig.client
    }
    
    // MARK: - Products
    func fetchProducts() async throws -> [Product] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let response: [ProductDTO] = try await client
            .from("products")
            .select()
            .eq("store_id", value: storeId)
            .execute()
            .value
        
        return response.map { $0.toDomain() }
    }
    
    func saveProduct(_ product: Product) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = ProductDTO(from: product).withStore(storeId)
        try await client
            .from("products")
            .insert(dto)
            .execute()
    }
    
    func updateProduct(_ product: Product) async throws {
        let dto = ProductDTO(from: product)
        try await client
            .from("products")
            .update(dto)
            .eq("id", value: product.id)
            .execute()
    }
    
    func deleteProduct(_ id: UUID) async throws {
        try await client
            .from("products")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Orders
    func fetchOrders() async throws -> [Bill] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        // This is complex because we need to join order_items
        // For simplicity, we might need two queries or a view
        let orders: [OrderDTO] = try await client.database
            .from("orders")
            .select("*, order_items(*)")
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
            
        return orders.map { $0.toDomain() }
    }
    
    func saveOrder(_ bill: Bill) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let orderDTO = OrderDTO(from: bill)
        try await client.database.from("orders").insert(orderDTO.withStore(storeId)).execute()
        
        let itemsDTOs = bill.items.map { OrderItemDTO(from: $0, orderId: bill.id) }
        try await client.database.from("order_items").insert(itemsDTOs).execute()
    }
    
    func deleteOrder(_ id: UUID) async throws {
        try await client.database
            .from("orders")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Restock
    func fetchRestockHistory() async throws -> [RestockBill] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let bills: [RestockBillDTO] = try await client.database
            .from("restock_bills")
            .select("*, restock_items(*)")
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
            
        return bills.map { $0.toDomain() }
    }
    
    func saveRestockBill(_ bill: RestockBill) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let billDTO = RestockBillDTO(from: bill)
        try await client.database.from("restock_bills").insert(billDTO.withStore(storeId)).execute()
        
        let itemsDTOs = bill.items.map { RestockItemDTO(from: $0, billId: bill.id) }
        try await client.database.from("restock_items").insert(itemsDTOs).execute()
    }
    
    func deleteRestockBill(_ id: UUID) async throws {
        try await client.database
            .from("restock_bills")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Price History
    func fetchPriceHistory() async throws -> [String: Double] {
        let history: [PriceHistoryDTO] = try await client
            .from("price_history")
            .select()
            .execute()
            .value
            
        return history.reduce(into: [String: Double]()) { dict, item in
            dict[item.product_name] = item.price
        }
    }
    
    func upsertPriceHistory(name: String, price: Double) async throws {
        let dto = PriceHistoryDTO(product_name: name, price: price)
        try await client
            .from("price_history")
            .upsert(dto)
            .execute()
    }
    
    // MARK: - Operating Expenses
    func fetchOperatingExpenses() async throws -> [OperatingExpense] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let response: [OperatingExpenseDTO] = try await client
            .from("operating_expenses")
            .select()
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { $0.toDomain() }
    }
    
    func saveOperatingExpense(_ expense: OperatingExpense) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = OperatingExpenseDTO(from: expense).withStore(storeId)
        try await client
            .from("operating_expenses")
            .insert(dto)
            .execute()
    }

    func updateOperatingExpense(_ expense: OperatingExpense) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = OperatingExpenseDTO(from: expense).withStore(storeId)
        try await client
            .from("operating_expenses")
            .update(dto)
            .eq("id", value: expense.id)
            .execute()
    }
    
    func deleteOperatingExpense(_ id: UUID) async throws {
        try await client
            .from("operating_expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func deleteStore(_ id: UUID) async throws {
        try await client
            .from("stores")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Profiles
    func fetchProfile(id: UUID) async throws -> UserProfile? {
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        
        return response.first
    }
    
    func saveProfile(_ profile: UserProfile) async throws {
        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }
}
#else
// Mock implementation when Supabase is not available
class SupabaseDatabaseService: DatabaseService {
    var isMock: Bool { true }
    
    init() {
        print("⚠️ [SupabaseDatabaseService] Supabase module is missing. Database operations will be mocked or fail safely.")
    }
    
    func fetchProducts() async throws -> [Product] {
        print("⚠️ fetchProducts: Mocking empty response")
        return []
    }
    func saveProduct(_ product: Product) async throws { print("⚠️ saveProduct: Mocked success") }
    func updateProduct(_ product: Product) async throws { print("⚠️ updateProduct: Mocked success") }
    func deleteProduct(_ id: UUID) async throws { print("⚠️ deleteProduct: Mocked success") }
    
    func fetchOrders() async throws -> [Bill] { return [] }
    func saveOrder(_ bill: Bill) async throws { print("⚠️ saveOrder: Mocked success") }
    func deleteOrder(_ id: UUID) async throws { print("⚠️ deleteOrder: Mocked success") }
    
    func fetchRestockHistory() async throws -> [RestockBill] { return [] }
    func saveRestockBill(_ bill: RestockBill) async throws { print("⚠️ saveRestockBill: Mocked success") }
    func deleteRestockBill(_ id: UUID) async throws { print("⚠️ deleteRestockBill: Mocked success") }
    
    func fetchPriceHistory() async throws -> [String: Double] { return [:] }
    func upsertPriceHistory(name: String, price: Double) async throws { print("⚠️ upsertPriceHistory: Mocked success") }
    
    func fetchProfile(id: UUID) async throws -> UserProfile? { return nil }
    func saveProfile(_ profile: UserProfile) async throws { print("⚠️ saveProfile: Mocked success") }
    
    func fetchOperatingExpenses() async throws -> [OperatingExpense] { return [] }
    func saveOperatingExpense(_ expense: OperatingExpense) async throws { print("⚠️ saveOperatingExpense: Mocked success") }
    func deleteOperatingExpense(_ id: UUID) async throws { print("⚠️ deleteOperatingExpense: Mocked success") }
    func updateOperatingExpense(_ expense: OperatingExpense) async throws { print("⚠️ updateOperatingExpense: Mocked success") }
    func deleteStore(_ id: UUID) async throws { print("⚠️ deleteStore: Mocked success") }
}
#endif

// MARK: - DTOs (Data Transfer Objects) to match SQL Schema
struct OperatingExpenseDTO: Codable {
    let id: UUID
    let title: String
    let amount: Double
    let note: String?
    let created_at: Date
    let store_id: UUID?
    
    init(id: UUID, title: String, amount: Double, note: String?, created_at: Date, store_id: UUID?) {
        self.id = id
        self.title = title
        self.amount = amount
        self.note = note
        self.created_at = created_at
        self.store_id = store_id
    }
    
    init(from domain: OperatingExpense) {
        self.id = domain.id
        self.title = domain.title
        self.amount = domain.amount
        self.note = domain.note
        self.created_at = domain.createdAt
        self.store_id = nil
    }
    
    func toDomain() -> OperatingExpense {
        return OperatingExpense(id: id, title: title, amount: amount, note: note, createdAt: created_at)
    }
    
    func withStore(_ storeId: UUID) -> OperatingExpenseDTO {
        var copy = self
        copy = OperatingExpenseDTO(id: id, title: title, amount: amount, note: note, created_at: created_at, store_id: storeId)
        return copy
    }
}

struct PriceHistoryDTO: Codable {
    let product_name: String
    let price: Double
}

struct ProductDTO: Codable {
    let id: UUID
    let name: String
    let price: Double
    let category: String
    let image_name: String?
    let color: String?
    let stock_quantity: Int
    let cost_price: Double?
    let store_id: UUID?
    
    init(id: UUID, name: String, price: Double, category: String, image_name: String?, color: String?, stock_quantity: Int, cost_price: Double?, store_id: UUID?) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.image_name = image_name
        self.color = color
        self.stock_quantity = stock_quantity
        self.cost_price = cost_price
        self.store_id = store_id
    }
    
    init(from domain: Product, inventory: [String: Int] = [:]) {
        self.id = domain.id
        self.name = domain.name
        self.price = domain.price
        self.category = domain.category
        self.image_name = domain.imageName
        self.color = domain.color
        self.stock_quantity = domain.stockQuantity
        self.cost_price = domain.costPrice
        self.store_id = nil
    }
    
    func toDomain() -> Product {
        return Product(id: id, name: name, price: price, costPrice: cost_price ?? 0, category: category, imageName: image_name ?? "shippingbox", color: color ?? "gray", imageData: nil, stockQuantity: stock_quantity)
    }
    
    func withStore(_ storeId: UUID) -> ProductDTO {
        return ProductDTO(id: id, name: name, price: price, category: category, image_name: image_name, color: color, stock_quantity: stock_quantity, cost_price: cost_price, store_id: storeId)
    }
}

struct OrderDTO: Codable {
    let id: UUID
    let total_amount: Double
    let created_at: Date
    let order_items: [OrderItemDTO]?
    let store_id: UUID?
    
    init(id: UUID, total_amount: Double, created_at: Date, order_items: [OrderItemDTO]?, store_id: UUID?) {
        self.id = id
        self.total_amount = total_amount
        self.created_at = created_at
        self.order_items = order_items
        self.store_id = store_id
    }
    
    init(from domain: Bill) {
        self.id = domain.id
        self.total_amount = domain.total
        self.created_at = domain.createdAt
        self.order_items = nil
        self.store_id = nil
    }
    
    func toDomain() -> Bill {
        let items = order_items?.map { $0.toDomain() } ?? []
        return Bill(id: id, createdAt: created_at, items: items, total: total_amount)
    }
    
    func withStore(_ storeId: UUID) -> OrderDTO {
        return OrderDTO(id: id, total_amount: total_amount, created_at: created_at, order_items: order_items, store_id: storeId)
    }
}

struct OrderItemDTO: Codable {
    let id: UUID
    let order_id: UUID
    let product_name: String
    let quantity: Int
    let price: Double
    let cost_price: Double?
    // let discount: Double? // TODO: Uncomment after migration: ALTER TABLE order_items ADD COLUMN discount DOUBLE PRECISION DEFAULT 0;
    
    init(from domain: OrderItem, orderId: UUID) {
        self.id = UUID()
        self.order_id = orderId
        self.product_name = domain.name
        self.quantity = domain.quantity
        self.price = domain.price
        self.cost_price = domain.costPrice
        // self.discount = domain.discount
    }
    
    func toDomain() -> OrderItem {
        return OrderItem(id: UUID(), name: product_name, quantity: quantity, price: price, costPrice: cost_price ?? 0, discount: 0 /* discount ?? 0 */)
    }
}

struct RestockBillDTO: Codable {
    let id: UUID
    let total_cost: Double
    let created_at: Date
    let restock_items: [RestockItemDTO]?
    let store_id: UUID?
    
    init(id: UUID, total_cost: Double, created_at: Date, restock_items: [RestockItemDTO]?, store_id: UUID?) {
        self.id = id
        self.total_cost = total_cost
        self.created_at = created_at
        self.restock_items = restock_items
        self.store_id = store_id
    }
    
    init(from domain: RestockBill) {
        self.id = domain.id
        self.total_cost = domain.totalCost
        self.created_at = domain.createdAt
        self.restock_items = nil
        self.store_id = nil
    }
    
    func toDomain() -> RestockBill {
        let items = restock_items?.map { $0.toDomain() } ?? []
        return RestockBill(id: id, createdAt: created_at, items: items, totalCost: total_cost)
    }
    
    func withStore(_ storeId: UUID) -> RestockBillDTO {
        return RestockBillDTO(id: id, total_cost: total_cost, created_at: created_at, restock_items: restock_items, store_id: storeId)
    }
}

struct RestockItemDTO: Codable {
    let id: UUID
    let bill_id: UUID
    let product_name: String
    let quantity: Int
    let unit_price: Double
    
    init(from domain: RestockItem, billId: UUID) {
        self.id = UUID()
        self.bill_id = billId
        self.product_name = domain.name
        self.quantity = domain.quantity
        self.unit_price = domain.unitPrice
    }
    
    func toDomain() -> RestockItem {
        return RestockItem(id: UUID(), name: product_name, quantity: quantity, unitPrice: unit_price)
    }
}
