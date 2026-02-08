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
    func fetchOrder(id: UUID) async throws -> Bill?
    func saveOrder(_ bill: Bill) async throws
    func updateOrder(_ bill: Bill) async throws
    func deleteOrder(_ id: UUID) async throws
    
    func fetchRestockHistory() async throws -> [RestockBill]
    func fetchRestockBill(id: UUID) async throws -> RestockBill?
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
        print("🔄 [DatabaseManager] Fetching products for store: \(storeId)")
        
        // Debug: Fetch raw JSON to see available columns
        do {
            let rawData = try await client.from("products").select().eq("store_id", value: storeId).limit(1).execute().data
            if let jsonString = String(data: rawData, encoding: .utf8) {
                print("🔍 [DatabaseManager] Raw Product JSON: \(jsonString)")
            }
        } catch {
            print("⚠️ [DatabaseManager] Failed to fetch raw product debug data: \(error)")
        }
        
        let response: [ProductDTO] = try await client
            .from("products")
            .select()
            .eq("store_id", value: storeId)
            .execute()
            .value
        
        if let first = response.first {
            print("🔍 [DatabaseManager] Sample product cost_price from DB: \(String(describing: first.cost_price))")
        }
        
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
        print("🔄 [DatabaseManager] Updating product: \(product.name), costPrice: \(product.costPrice)")
        guard let storeId = StoreManager.shared.currentStore?.id else {
            print("❌ [DatabaseManager] Store ID missing for updateProduct")
            throw NSError(domain: "StoreMissing", code: 1)
        }
        
        let dto = ProductDTO(from: product).withStore(storeId)
        
        // Debug DTO
        if let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8) {
             print("📦 [DatabaseManager] ProductDTO JSON: \(json)")
        }

        try await client
            .from("products")
            .update(dto)
            .eq("id", value: product.id)
            .execute()
        print("✅ [DatabaseManager] Update success")
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
    
    func fetchOrder(id: UUID) async throws -> Bill? {
        let orders: [OrderDTO] = try await client.database
            .from("orders")
            .select("*, order_items(*)")
            .eq("id", value: id)
            .execute()
            .value
            
        return orders.first?.toDomain()
    }

    func saveOrder(_ bill: Bill) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let orderDTO = OrderDTO(from: bill)
        try await client.database.from("orders").insert(orderDTO.withStore(storeId)).execute()
        
        let itemsDTOs = bill.items.map { OrderItemDTO(from: $0, orderId: bill.id) }
        try await client.database.from("order_items").insert(itemsDTOs).execute()
    }
    
    func updateOrder(_ bill: Bill) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let orderDTO = OrderDTO(from: bill).withStore(storeId)
        
        // Update main order (including payment status)
        try await client.database
            .from("orders")
            .update(orderDTO)
            .eq("id", value: bill.id)
            .execute()
        
        // Note: We are not updating items here for simplicity, assuming only status changes
        // If we need to update items, we'd need to delete and re-insert or upsert
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
    
    func fetchRestockBill(id: UUID) async throws -> RestockBill? {
        let bills: [RestockBillDTO] = try await client.database
            .from("restock_bills")
            .select("*, restock_items(*)")
            .eq("id", value: id)
            .execute()
            .value
            
        return bills.first?.toDomain()
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
    func fetchOrder(id: UUID) async throws -> Bill? { return nil }
    func saveOrder(_ bill: Bill) async throws { print("⚠️ saveOrder: Mocked success") }
    func updateOrder(_ bill: Bill) async throws { print("⚠️ updateOrder: Mocked success") }
    func deleteOrder(_ id: UUID) async throws { print("⚠️ deleteOrder: Mocked success") }
    
    func fetchRestockHistory() async throws -> [RestockBill] { return [] }
    func fetchRestockBill(id: UUID) async throws -> RestockBill? { return nil }
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
    let barcode: String?
    let image_url: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, category, image_name, color, stock_quantity, cost_price, store_id, barcode, image_url
        case costPrice // Fallback for camelCase
    }
    
    init(id: UUID, name: String, price: Double, category: String, image_name: String?, color: String?, stock_quantity: Int, cost_price: Double?, store_id: UUID?, barcode: String?, image_url: String?) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.image_name = image_name
        self.color = color
        self.stock_quantity = stock_quantity
        self.cost_price = cost_price
        self.store_id = store_id
        self.barcode = barcode
        self.image_url = image_url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        price = try container.decode(Double.self, forKey: .price)
        category = try container.decode(String.self, forKey: .category)
        image_name = try container.decodeIfPresent(String.self, forKey: .image_name)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        stock_quantity = try container.decode(Int.self, forKey: .stock_quantity)
        store_id = try container.decodeIfPresent(UUID.self, forKey: .store_id)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        image_url = try container.decodeIfPresent(String.self, forKey: .image_url)
        
        // Robust decoding: Try cost_price (snake_case) first, then costPrice (camelCase)
        if let cp = try container.decodeIfPresent(Double.self, forKey: .cost_price) {
            cost_price = cp
        } else {
            cost_price = try container.decodeIfPresent(Double.self, forKey: .costPrice)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(price, forKey: .price)
        try container.encode(category, forKey: .category)
        try container.encode(image_name, forKey: .image_name)
        try container.encode(color, forKey: .color)
        try container.encode(stock_quantity, forKey: .stock_quantity)
        try container.encode(cost_price, forKey: .cost_price) // Always persist as snake_case
        try container.encode(store_id, forKey: .store_id)
        try container.encode(barcode, forKey: .barcode)
        try container.encode(image_url, forKey: .image_url)
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
        self.barcode = domain.barcode
        self.image_url = domain.imageURL
    }
    
    func toDomain() -> Product {
        return Product(id: id, name: name, price: price, costPrice: cost_price ?? 0, category: category, imageName: image_name ?? "shippingbox", color: color ?? "gray", imageData: nil, imageURL: image_url, stockQuantity: stock_quantity, barcode: barcode)
    }
    
    func withStore(_ storeId: UUID) -> ProductDTO {
        return ProductDTO(id: id, name: name, price: price, category: category, image_name: image_name, color: color, stock_quantity: stock_quantity, cost_price: cost_price, store_id: storeId, barcode: barcode, image_url: image_url)
    }
}

struct OrderDTO: Codable {
    let id: UUID
    let total_amount: Double
    let created_at: Date
    let order_items: [OrderItemDTO]?
    let store_id: UUID?
    let is_paid: Bool?
    let creator_id: UUID?
    let creator_name: String?
    
    init(id: UUID, total_amount: Double, created_at: Date, order_items: [OrderItemDTO]?, store_id: UUID?, is_paid: Bool?, creator_id: UUID?, creator_name: String?) {
        self.id = id
        self.total_amount = total_amount
        self.created_at = created_at
        self.order_items = order_items
        self.store_id = store_id
        self.is_paid = is_paid
        self.creator_id = creator_id
        self.creator_name = creator_name
    }
    
    init(from domain: Bill) {
        self.id = domain.id
        self.total_amount = domain.total
        self.created_at = domain.createdAt
        self.order_items = nil
        self.store_id = nil
        self.is_paid = domain.isPaid
        self.creator_id = domain.creatorId
        self.creator_name = domain.creatorName
    }
    
    func toDomain() -> Bill {
        let items = order_items?.map { $0.toDomain() } ?? []
        // Recalculate totalCost from items because it's not stored in OrderDTO
        let calculatedTotalCost = items.reduce(0) { $0 + $1.totalCost }
        var bill = Bill(id: id, createdAt: created_at, items: items, total: total_amount, totalCost: calculatedTotalCost)
        bill.isPaid = is_paid ?? true
        bill.creatorId = creator_id
        bill.creatorName = creator_name
        return bill
    }
    
    func withStore(_ storeId: UUID) -> OrderDTO {
        return OrderDTO(id: id, total_amount: total_amount, created_at: created_at, order_items: order_items, store_id: storeId, is_paid: is_paid, creator_id: creator_id, creator_name: creator_name)
    }
}

struct OrderItemDTO: Codable {
    let id: UUID
    let order_id: UUID
    let product_name: String
    let quantity: Int
    let price: Double
    let cost_price: Double?
    let discount: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, order_id, product_name, quantity, price, cost_price, discount
        case costPrice // Fallback
    }
    
    init(from domain: OrderItem, orderId: UUID) {
        self.id = UUID()
        self.order_id = orderId
        self.product_name = domain.name
        self.quantity = domain.quantity
        self.price = domain.price
        self.cost_price = domain.costPrice
        self.discount = domain.discount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        order_id = try container.decode(UUID.self, forKey: .order_id)
        product_name = try container.decode(String.self, forKey: .product_name)
        quantity = try container.decode(Int.self, forKey: .quantity)
        price = try container.decode(Double.self, forKey: .price)
        discount = try container.decodeIfPresent(Double.self, forKey: .discount)
        
        if let cp = try container.decodeIfPresent(Double.self, forKey: .cost_price) {
            cost_price = cp
        } else {
            cost_price = try container.decodeIfPresent(Double.self, forKey: .costPrice)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(order_id, forKey: .order_id)
        try container.encode(product_name, forKey: .product_name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(price, forKey: .price)
        try container.encode(cost_price, forKey: .cost_price)
        try container.encode(discount, forKey: .discount)
    }
    
    func toDomain() -> OrderItem {
        return OrderItem(id: UUID(), name: product_name, quantity: quantity, price: price, costPrice: cost_price ?? 0, discount: discount ?? 0)
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
