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
    func fetchOrdersByCustomerName(_ name: String) async throws -> [Bill]
    func fetchOrder(id: UUID) async throws -> Bill?
    func saveOrder(_ bill: Bill) async throws
    func updateOrder(_ bill: Bill) async throws
    func deleteOrder(_ id: UUID) async throws
    
    func fetchRestockHistory() async throws -> [RestockBill]
    func fetchRestockBill(id: UUID) async throws -> RestockBill?
    func saveRestockBill(_ bill: RestockBill) async throws
    func deleteRestockBill(_ id: UUID) async throws
    func softDeleteRestockBill(_ id: UUID, deletedAt: Date, deletedBy: UUID?) async throws
    func updateRestockBill(_ bill: RestockBill) async throws
    
    func fetchRestockEdits(restockBillId: UUID) async throws -> [RestockEdit]
    func saveRestockEdit(_ edit: RestockEdit) async throws
    func fetchEditedRestockBillIds(storeId: UUID) async throws -> [UUID]
    
    // Production management
    func saveProductionTransaction(_ tx: ProductionTransaction) async throws
    func updateProductionTransaction(_ tx: ProductionTransaction) async throws
    func softDeleteProductionTransaction(id: UUID, deletedAt: Date, deletedByName: String?, deleteNote: String?) async throws
    func fetchProductionTransactions(mode: String?) async throws -> [ProductionTransaction]
    
    func fetchPriceHistory() async throws -> [String: Double]
    func upsertPriceHistory(name: String, price: Double) async throws
    
    func fetchOperatingExpenses() async throws -> [OperatingExpense]
    func saveOperatingExpense(_ expense: OperatingExpense) async throws
    func updateOperatingExpense(_ expense: OperatingExpense) async throws
    func deleteOperatingExpense(_ id: UUID) async throws
    
    func fetchProfile(id: UUID) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    
    func deleteStore(_ id: UUID) async throws
    
    func saveUserFeedback(_ feedback: UserFeedback) async throws
    
    // Order edit history
    func fetchOrderEdits(orderId: UUID) async throws -> [OrderEdit]
    func saveOrderEdit(_ edit: OrderEdit) async throws
    func fetchEditedOrderIds(storeId: UUID) async throws -> [UUID]
    
    // Production edit history
    func fetchProductionEdits(transactionId: UUID) async throws -> [ProductionEdit]
    func saveProductionEdit(_ edit: ProductionEdit) async throws
    func fetchEditedProductionTransactionIds(storeId: UUID) async throws -> [UUID]
    
    // Auto material export templates/logs
    func fetchAutoMaterialExportTemplates(storeId: UUID) async throws -> [AutoMaterialExportTemplate]
    func upsertAutoMaterialExportTemplate(_ template: AutoMaterialExportTemplate) async throws
    func deleteAutoMaterialExportTemplate(id: UUID) async throws
    func fetchAutoMaterialExportLogs(storeId: UUID, limit: Int) async throws -> [AutoMaterialExportLog]
    func fetchAutoMaterialExportLogsForTransaction(storeId: UUID, transactionId: UUID) async throws -> [AutoMaterialExportLog]
    func saveAutoMaterialExportLog(_ log: AutoMaterialExportLog) async throws
    
    // Device tokens for push
    func saveDeviceToken(_ token: String) async throws
    func deleteDeviceToken(_ token: String) async throws
    
    // Materials
    func fetchMaterials() async throws -> [MaterialItem]
    func saveMaterial(_ material: MaterialItem) async throws
    func updateMaterial(_ material: MaterialItem) async throws
    func deleteMaterial(_ id: UUID) async throws
    
    // Categories
    func saveCategory(_ name: String, kind: String) async throws
    func fetchCategories(kind: String) async throws -> [String]

    // Trading Parties (buyers & suppliers)
    func fetchTradingParties(type: String) async throws -> [TradingParty]
    func upsertTradingParty(_ party: TradingParty) async throws
    func deleteTradingParty(id: UUID) async throws
    func fetchTradingPartyByName(_ name: String, type: String) async throws -> TradingParty?

    // Website leads
    func fetchWebsiteLeads() async throws -> [WebsiteLead]
    func updateWebsiteLeadStatus(id: UUID, status: String, note: String?) async throws

    // Attendance
    func upsertAttendanceRecord(_ record: AttendanceRecordDB) async throws
    func fetchAttendanceRecords(userId: UUID, from: Date, to: Date) async throws -> [AttendanceRecordDB]
    func fetchTodayAttendance(userId: UUID) async throws -> AttendanceRecordDB?

    // Leave requests
    func saveLeaveRequest(_ request: LeaveRequest) async throws
    func fetchLeaveRequests(userId: UUID) async throws -> [LeaveRequest]
    func fetchAllLeaveRequests() async throws -> [LeaveRequest]
    func updateLeaveRequestStatus(id: UUID, status: String, reviewNote: String?) async throws

    // Sequence counters
    func nextSequenceNumber(type: String) async -> Int
}

// MARK: - Sequence Counter Types
enum SequenceType {
    static let retailSale      = "XBL"  // Xuất Bán Lẻ
    static let retailRestock   = "NBL"  // Nhập Bán Lẻ (nhận hàng hoá)
    static let materialImport  = "NNL"  // Nhập Nguyên Liệu
    static let materialExport  = "XNL"  // Xuất Nguyên Liệu
    static let finishedImport  = "NTP"  // Nhập Thành Phẩm
    static let finishedExport  = "XTP"  // Xuất Thành Phẩm
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
    
    // MARK: - Categories
    struct CategoryRow: Codable {
        let id: UUID
        let name: String
        let kind: String
        let store_id: UUID?
        let created_at: Date?
    }
    
    func saveCategory(_ name: String, kind: String) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let row = CategoryRow(id: UUID(), name: name, kind: kind, store_id: storeId, created_at: nil)
        do {
            try await client.database.from("categories").insert(row).execute()
        } catch {
            let msg = String(describing: error).lowercased()
            if msg.contains("duplicate") {
                // ignore duplicate insert
                return
            } else {
                throw error
            }
        }
    }
    
    func fetchCategories(kind: String) async throws -> [String] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let rows: [CategoryRow] = try await client.database
            .from("categories")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("kind", value: kind)
            .execute()
            .value
        return rows.map { $0.name }
    }

    // MARK: - Trading Parties
    func fetchTradingParties(type: String) async throws -> [TradingParty] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let rows: [TradingPartyDTO] = try await client.database
            .from("trading_parties")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("party_type", value: type)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func upsertTradingParty(_ party: TradingParty) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = TradingPartyDTO(from: party, storeId: storeId)
        try await client.database
            .from("trading_parties")
            .upsert(dto)
            .execute()
    }

    func deleteTradingParty(id: UUID) async throws {
        try await client.database
            .from("trading_parties")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func fetchTradingPartyByName(_ name: String, type: String) async throws -> TradingParty? {
        guard let storeId = StoreManager.shared.currentStore?.id else { return nil }
        let rows: [TradingPartyDTO] = try await client.database
            .from("trading_parties")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("party_type", value: type)
            .ilike("name", value: name)
            .limit(1)
            .execute()
            .value
        return rows.first?.toDomain()
    }

    func fetchWebsiteLeads() async throws -> [WebsiteLead] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        // Fetch leads matching this store OR leads with no store_id (submitted before store was configured)
        let rows: [WebsiteLeadDTO] = try await client.database
            .from("website_leads")
            .select("*")
            .or("store_id.eq.\(storeId.uuidString),store_id.is.null")
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func updateWebsiteLeadStatus(id: UUID, status: String, note: String?) async throws {
        struct UpdatePayload: Encodable {
            let status: String
            let note: String?
        }
        try await client.database
            .from("website_leads")
            .update(UpdatePayload(status: status, note: note))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Attendance

    func upsertAttendanceRecord(_ record: AttendanceRecordDB) async throws {
        let dto = AttendanceRecordDTO(from: record)
        try await client.database
            .from("attendance_records")
            .upsert(dto, onConflict: "store_id,user_id,date,shift")
            .execute()
    }

    func fetchAttendanceRecords(userId: UUID, from: Date, to: Date) async throws -> [AttendanceRecordDB] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let fromStr = df.string(from: from)
        let toStr   = df.string(from: to)
        let rows: [AttendanceRecordDTO] = try await client.database
            .from("attendance_records")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("user_id", value: userId)
            .gte("date", value: fromStr)
            .lte("date", value: toStr)
            .order("date", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func fetchTodayAttendance(userId: UUID) async throws -> AttendanceRecordDB? {
        guard let storeId = StoreManager.shared.currentStore?.id else { return nil }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        let rows: [AttendanceRecordDTO] = try await client.database
            .from("attendance_records")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("user_id", value: userId)
            .eq("date", value: today)
            .order("shift", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.toDomain()
    }

    // MARK: - Leave Requests

    func saveLeaveRequest(_ request: LeaveRequest) async throws {
        let dto = LeaveRequestDTO(from: request)
        try await client.database
            .from("leave_requests")
            .insert(dto)
            .execute()
    }

    func fetchLeaveRequests(userId: UUID) async throws -> [LeaveRequest] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let rows: [LeaveRequestDTO] = try await client.database
            .from("leave_requests")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("user_id", value: userId)
            .order("leave_date", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func fetchAllLeaveRequests() async throws -> [LeaveRequest] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let rows: [LeaveRequestDTO] = try await client.database
            .from("leave_requests")
            .select("*")
            .eq("store_id", value: storeId)
            .order("leave_date", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func updateLeaveRequestStatus(id: UUID, status: String, reviewNote: String?) async throws {
        struct Payload: Encodable {
            let status: String
            let review_note: String?
            let reviewed_at: Date
        }
        try await client.database
            .from("leave_requests")
            .update(Payload(status: status, review_note: reviewNote, reviewed_at: Date()))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Sequence Counters

    func nextSequenceNumber(type: String) async -> Int {
        guard let storeId = StoreManager.shared.currentStore?.id else { return 0 }
        do {
            // Supabase RPC trả về số nguyên trực tiếp
            let result: Int = try await client
                .rpc("increment_sequence_counter", params: [
                    "p_store_id": storeId.uuidString,
                    "p_type": type
                ])
                .execute()
                .value
            return result
        } catch {
            print("❌ nextSequenceNumber error: \(error)")
            return 0
        }
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
        print("🔄 [DatabaseManager] Updating product: \(product.name), costPrice: \(product.costPrice), isFinishedGood: \(product.isFinishedGood)")
        guard let storeId = StoreManager.shared.currentStore?.id else {
            print("❌ [DatabaseManager] Store ID missing for updateProduct")
            throw NSError(domain: "StoreMissing", code: 1)
        }
        
        let dto = ProductDTO(from: product).withStore(storeId)
        
        // Debug DTO
        if let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8) {
             print("📦 [DatabaseManager] ProductDTO JSON: \(json)")
        }

        do {
            let result = try await client
                .from("products")
                .update(dto)
                .eq("id", value: product.id)
                .execute()
            print("✅ [DatabaseManager] Update success for product: \(product.id), rows affected: \(result.count)")
        } catch {
            print("❌ [DatabaseManager] Database update failed: \(error)")
            print("❌ [DatabaseManager] Error details: \(String(describing: error))")
            throw error
        }
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

    func fetchOrdersByCustomerName(_ name: String) async throws -> [Bill] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let orders: [OrderDTO] = try await client.database
            .from("orders")
            .select("*, order_items(*)")
            .eq("store_id", value: storeId)
            .ilike("customer_name", value: name)
            .order("created_at", ascending: false)
            .limit(100)
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
    
    // MARK: - Order Edits
    func fetchOrderEdits(orderId: UUID) async throws -> [OrderEdit] {
        let rows: [OrderEditDTO] = try await client
            .from("order_edits")
            .select()
            .eq("order_id", value: orderId)
            .order("created_at", ascending: false)
            .execute()
            .value
        let edits = rows.map { $0.toDomain() }
        print("✅ [OrderEdit] Fetched \(edits.count) edits for order \(orderId)")
        return edits
    }
    
    func saveOrderEdit(_ edit: OrderEdit) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else {
            throw NSError(domain: "StoreMissing", code: 1, userInfo: [NSLocalizedDescriptionKey: "currentStore is nil when saving OrderEdit"])
        }
        let dto = OrderEditDTO(from: edit, storeId: storeId)
        let uidStr = SupabaseConfig.client.auth.currentUser?.id.uuidString ?? "nil"
        print("🔐 [OrderEdit] auth.uid=\(uidStr), store_id=\(storeId)")
        if let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8) {
            print("📦 [DatabaseManager] OrderEditDTO JSON: \(json)")
        }
        do {
            print("🔧 [OrderEdit] Upsert begin")
            try await client
                .from("order_edits")
                .upsert(dto)
                .execute()
            print("✅ [OrderEdit] Upsert success")
        } catch {
            print("❌ [OrderEdit] Upsert failed: \(error)")
            throw error
        }
    }
    
    func fetchEditedOrderIds(storeId: UUID) async throws -> [UUID] {
        struct Row: Decodable { let order_id: UUID }
        let rows: [Row] = try await client
            .from("order_edits")
            .select("order_id")
            .eq("store_id", value: storeId)
            .execute()
            .value
        // Distinct
        var set = Set<UUID>()
        for r in rows { set.insert(r.order_id) }
        let ids = Array(set)
        print("✅ [OrderEdit] Fetched \(ids.count) edited order ids for store \(storeId)")
        return ids
    }
    
    // MARK: - Production Edits
    func fetchProductionEdits(transactionId: UUID) async throws -> [ProductionEdit] {
        let rows: [ProductionEditDTO] = try await client
            .from("production_edits")
            .select()
            .eq("transaction_id", value: transactionId)
            .order("created_at", ascending: false)
            .execute()
            .value
        let edits = rows.map { $0.toDomain() }
        print("✅ [ProductionEdit] Fetched \(edits.count) edits for tx \(transactionId)")
        return edits
    }
    
    func saveProductionEdit(_ edit: ProductionEdit) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else {
            throw NSError(domain: "StoreMissing", code: 1, userInfo: [NSLocalizedDescriptionKey: "currentStore is nil when saving ProductionEdit"])
        }
        let dto = ProductionEditDTO(from: edit, storeId: storeId)
        let uidStr = SupabaseConfig.client.auth.currentUser?.id.uuidString ?? "nil"
        print("🔐 [ProductionEdit] auth.uid=\(uidStr), store_id=\(storeId)")
        if let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8) {
            print("📦 [DatabaseManager] ProductionEditDTO JSON: \(json)")
        }
        do {
            print("🔧 [ProductionEdit] Upsert begin")
            try await client
                .from("production_edits")
                .upsert(dto)
                .execute()
            print("✅ [ProductionEdit] Upsert success")
        } catch {
            print("❌ [ProductionEdit] Upsert failed: \(error)")
            throw error
        }
    }
    
    func fetchEditedProductionTransactionIds(storeId: UUID) async throws -> [UUID] {
        struct Row: Decodable { let transaction_id: UUID }
        let rows: [Row] = try await client
            .from("production_edits")
            .select("transaction_id")
            .eq("store_id", value: storeId)
            .execute()
            .value
        var set = Set<UUID>()
        for r in rows { set.insert(r.transaction_id) }
        let ids = Array(set)
        print("✅ [ProductionEdit] Fetched \(ids.count) edited tx ids for store \(storeId)")
        return ids
    }
    
    func fetchAutoMaterialExportTemplates(storeId: UUID) async throws -> [AutoMaterialExportTemplate] {
        let rows: [AutoMaterialExportTemplateDTO] = try await client
            .from("auto_material_export_templates")
            .select()
            .eq("store_id", value: storeId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }
    
    func upsertAutoMaterialExportTemplate(_ template: AutoMaterialExportTemplate) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = AutoMaterialExportTemplateDTO(from: template, storeId: storeId)
        try await client
            .from("auto_material_export_templates")
            .upsert(dto)
            .execute()
    }
    
    func deleteAutoMaterialExportTemplate(id: UUID) async throws {
        try await client
            .from("auto_material_export_templates")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func fetchAutoMaterialExportLogs(storeId: UUID, limit: Int) async throws -> [AutoMaterialExportLog] {
        let rows: [AutoMaterialExportLogDTO] = try await client
            .from("auto_material_export_logs")
            .select()
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }
    
    func fetchAutoMaterialExportLogsForTransaction(storeId: UUID, transactionId: UUID) async throws -> [AutoMaterialExportLog] {
        let rows: [AutoMaterialExportLogDTO] = try await client
            .from("auto_material_export_logs")
            .select()
            .eq("store_id", value: storeId)
            .eq("production_transaction_id", value: transactionId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }
    
    func saveAutoMaterialExportLog(_ log: AutoMaterialExportLog) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = AutoMaterialExportLogDTO(from: log, storeId: storeId)
        try await client
            .from("auto_material_export_logs")
            .insert(dto)
            .execute()
    }
    
    // MARK: - Feedback
    func saveUserFeedback(_ feedback: UserFeedback) async throws {
        let storeId = StoreManager.shared.currentStore?.id
        let userId = SupabaseConfig.client.auth.currentUser?.id
        let dto = UserFeedbackDTO(
            id: feedback.id,
            content: feedback.content,
            created_at: feedback.createdAt,
            user_id: userId,
            store_id: storeId
        )
        try await client
            .from("user_feedback")
            .insert(dto)
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
    
    func softDeleteRestockBill(_ id: UUID, deletedAt: Date, deletedBy: UUID?) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        
        struct Payload: Encodable {
            let is_deleted: Bool
            let deleted_at: Date
            let deleted_by: UUID?
        }
        
        try await client.database
            .from("restock_bills")
            .update(Payload(is_deleted: true, deleted_at: deletedAt, deleted_by: deletedBy))
            .eq("id", value: id)
            .eq("store_id", value: storeId)
            .execute()
    }
    
    func updateRestockBill(_ bill: RestockBill) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let billDTO = RestockBillDTO(from: bill).withStore(storeId)
        
        try await client.database
            .from("restock_bills")
            .update(billDTO)
            .eq("id", value: bill.id)
            .eq("store_id", value: storeId)
            .execute()
        
        try await client.database
            .from("restock_items")
            .delete()
            .eq("bill_id", value: bill.id)
            .execute()
        
        let itemsDTOs = bill.items.map { RestockItemDTO(from: $0, billId: bill.id) }
        if !itemsDTOs.isEmpty {
            try await client.database
                .from("restock_items")
                .insert(itemsDTOs)
                .execute()
        }
    }
    
    func fetchRestockEdits(restockBillId: UUID) async throws -> [RestockEdit] {
        let rows: [RestockEditDTO] = try await client
            .from("restock_edits")
            .select()
            .eq("restock_bill_id", value: restockBillId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }
    
    func saveRestockEdit(_ edit: RestockEdit) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else {
            throw NSError(domain: "StoreMissing", code: 1, userInfo: [NSLocalizedDescriptionKey: "currentStore is nil when saving RestockEdit"])
        }
        let dto = RestockEditDTO(from: edit, storeId: storeId)
        try await client
            .from("restock_edits")
            .upsert(dto)
            .execute()
    }
    
    func fetchEditedRestockBillIds(storeId: UUID) async throws -> [UUID] {
        struct Row: Decodable { let restock_bill_id: UUID }
        let rows: [Row] = try await client
            .from("restock_edits")
            .select("restock_bill_id")
            .eq("store_id", value: storeId)
            .execute()
            .value
        var set = Set<UUID>()
        for r in rows { set.insert(r.restock_bill_id) }
        return Array(set)
    }
    
    // MARK: - Production Management
    func saveProductionTransaction(_ tx: ProductionTransaction) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let header = ProductionTransactionDTO(from: tx).withStore(storeId)
        try await client.database.from("production_transactions").insert(header).execute()
        let itemsDTOs = tx.items.map { ProductionTransactionItemDTO(from: $0, transactionId: tx.id) }
        do {
            try await client.database.from("production_transaction_items").insert(itemsDTOs).execute()
        } catch {
            let msg = String(describing: error).lowercased()
            if msg.contains("unit") {
                // Fallback for missing unit column
                let fallbackItems = tx.items.map { ProductionTransactionItemNoUnitDTO(from: $0, transactionId: tx.id) }
                try await client.database.from("production_transaction_items").insert(fallbackItems).execute()
            } else {
                throw error
            }
        }
    }
    
    func updateProductionTransaction(_ tx: ProductionTransaction) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let header = ProductionTransactionDTO(from: tx).withStore(storeId)
        try await client.database
            .from("production_transactions")
            .update(header)
            .eq("id", value: tx.id)
            .eq("store_id", value: storeId)
            .execute()
        
        try await client.database
            .from("production_transaction_items")
            .delete()
            .eq("transaction_id", value: tx.id)
            .execute()
        
        let itemsDTOs = tx.items.map { ProductionTransactionItemDTO(from: $0, transactionId: tx.id) }
        if !itemsDTOs.isEmpty {
            do {
                try await client.database
                    .from("production_transaction_items")
                    .insert(itemsDTOs)
                    .execute()
            } catch {
                let msg = String(describing: error).lowercased()
                if msg.contains("unit") {
                    let fallbackItems = tx.items.map { ProductionTransactionItemNoUnitDTO(from: $0, transactionId: tx.id) }
                    try await client.database.from("production_transaction_items").insert(fallbackItems).execute()
                } else {
                    throw error
                }
            }
        }
    }

    func softDeleteProductionTransaction(id: UUID, deletedAt: Date, deletedByName: String?, deleteNote: String?) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        struct Payload: Encodable {
            let is_deleted: Bool
            let deleted_at: Date
            let deleted_by_name: String?
            let delete_note: String?
        }
        try await client.database
            .from("production_transactions")
            .update(Payload(is_deleted: true, deleted_at: deletedAt, deleted_by_name: deletedByName, delete_note: deleteNote))
            .eq("id", value: id)
            .eq("store_id", value: storeId)
            .execute()
    }

    func fetchProductionTransactions(mode: String?) async throws -> [ProductionTransaction] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        // Fetch all for store, then filter by mode (case-insensitive) in Swift to tolerate legacy values
        let rows: [ProductionTransactionDTO] = try await client
            .from("production_transactions")
            .select("*, production_transaction_items(*)")
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
        var txs = rows.map { $0.toDomain() }
        if let m = mode {
            let target = m.lowercased()
            txs = txs.filter { $0.mode.lowercased() == target }
        }
        return txs
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
            .match(["store_id": storeId])
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
    
    // MARK: - Materials
    func fetchMaterials() async throws -> [MaterialItem] {
        guard let storeId = StoreManager.shared.currentStore?.id else { return [] }
        let rows: [MaterialDTO] = try await client
            .from("materials")
            .select()
            .eq("store_id", value: storeId)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }
    
    func saveMaterial(_ material: MaterialItem) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = MaterialDTO(from: material, storeId: storeId)
        do {
            try await client.from("materials").insert(dto).execute()
        } catch {
            let msg = String(describing: error)
            print("⚠️ [materials.insert] error: \(msg)")
            if msg.lowercased().contains("category") || msg.lowercased().contains("unit") {
                let fallback = MaterialNoUnitDTO(from: material, storeId: storeId)
                try await client.from("materials").insert(fallback).execute()
            } else {
                throw error
            }
        }
    }
    
    func updateMaterial(_ material: MaterialItem) async throws {
        guard let storeId = StoreManager.shared.currentStore?.id else { throw NSError(domain: "StoreMissing", code: 1) }
        let dto = MaterialDTO(from: material, storeId: storeId)
        do {
            try await client.from("materials").update(dto).eq("id", value: material.id).execute()
        } catch {
            let msg = String(describing: error)
            print("⚠️ [materials.update] error: \(msg)")
            if msg.lowercased().contains("category") || msg.lowercased().contains("unit") {
                let fallback = MaterialNoUnitDTO(from: material, storeId: storeId)
                try await client.from("materials").update(fallback).eq("id", value: material.id).execute()
            } else {
                throw error
            }
        }
    }
    
    func deleteMaterial(_ id: UUID) async throws {
        try await client.from("materials").delete().eq("id", value: id).execute()
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
    
    // MARK: - Device Tokens
    func saveDeviceToken(_ token: String) async throws {
        let userId = SupabaseConfig.client.auth.currentUser?.id
        let dto = DeviceTokenDTO(token: token, user_id: userId, created_at: Date(), platform: "ios")
        try await client
            .from("device_tokens")
            .upsert(dto)
            .execute()
    }
    
    func deleteDeviceToken(_ token: String) async throws {
        try await client
            .from("device_tokens")
            .delete()
            .eq("token", value: token)
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
    func fetchOrdersByCustomerName(_ name: String) async throws -> [Bill] { return [] }
    func fetchOrder(id: UUID) async throws -> Bill? { return nil }
    func saveOrder(_ bill: Bill) async throws { print("⚠️ saveOrder: Mocked success") }
    func updateOrder(_ bill: Bill) async throws { print("⚠️ updateOrder: Mocked success") }
    func deleteOrder(_ id: UUID) async throws { print("⚠️ deleteOrder: Mocked success") }
    func saveUserFeedback(_ feedback: UserFeedback) async throws { print("⚠️ saveUserFeedback: Mocked success") }
    
    func fetchRestockHistory() async throws -> [RestockBill] { return [] }
    func fetchRestockBill(id: UUID) async throws -> RestockBill? { return nil }
    func saveRestockBill(_ bill: RestockBill) async throws { print("⚠️ saveRestockBill: Mocked success") }
    func deleteRestockBill(_ id: UUID) async throws { print("⚠️ deleteRestockBill: Mocked success") }
    func softDeleteRestockBill(_ id: UUID, deletedAt: Date, deletedBy: UUID?) async throws { print("⚠️ softDeleteRestockBill: Mocked success") }
    func updateRestockBill(_ bill: RestockBill) async throws { print("⚠️ updateRestockBill: Mocked success") }
    func fetchRestockEdits(restockBillId: UUID) async throws -> [RestockEdit] { return [] }
    func saveRestockEdit(_ edit: RestockEdit) async throws { print("⚠️ saveRestockEdit: Mocked success") }
    func fetchEditedRestockBillIds(storeId: UUID) async throws -> [UUID] { return [] }
    
    func fetchPriceHistory() async throws -> [String: Double] { return [:] }
    func upsertPriceHistory(name: String, price: Double) async throws { print("⚠️ upsertPriceHistory: Mocked success") }
    
    func fetchProfile(id: UUID) async throws -> UserProfile? { return nil }
    func saveProfile(_ profile: UserProfile) async throws { print("⚠️ saveProfile: Mocked success") }
    
    func fetchOperatingExpenses() async throws -> [OperatingExpense] { return [] }
    func saveOperatingExpense(_ expense: OperatingExpense) async throws { print("⚠️ saveOperatingExpense: Mocked success") }
    func deleteOperatingExpense(_ id: UUID) async throws { print("⚠️ deleteOperatingExpense: Mocked success") }
    func updateOperatingExpense(_ expense: OperatingExpense) async throws { print("⚠️ updateOperatingExpense: Mocked success") }
    func deleteStore(_ id: UUID) async throws { print("⚠️ deleteStore: Mocked success") }
    
    func fetchOrderEdits(orderId: UUID) async throws -> [OrderEdit] { return [] }
    func saveOrderEdit(_ edit: OrderEdit) async throws { print("⚠️ saveOrderEdit: Mocked success") }
    func fetchEditedOrderIds(storeId: UUID) async throws -> [UUID] { return [] }
    func fetchProductionEdits(transactionId: UUID) async throws -> [ProductionEdit] { return [] }
    func saveProductionEdit(_ edit: ProductionEdit) async throws { print("⚠️ saveProductionEdit: Mocked success") }
    func fetchEditedProductionTransactionIds(storeId: UUID) async throws -> [UUID] { return [] }
    
    func fetchAutoMaterialExportTemplates(storeId: UUID) async throws -> [AutoMaterialExportTemplate] { return [] }
    func upsertAutoMaterialExportTemplate(_ template: AutoMaterialExportTemplate) async throws { print("⚠️ upsertAutoMaterialExportTemplate: Mocked success") }
    func deleteAutoMaterialExportTemplate(id: UUID) async throws { print("⚠️ deleteAutoMaterialExportTemplate: Mocked success") }
    func fetchAutoMaterialExportLogs(storeId: UUID, limit: Int) async throws -> [AutoMaterialExportLog] { return [] }
    func fetchAutoMaterialExportLogsForTransaction(storeId: UUID, transactionId: UUID) async throws -> [AutoMaterialExportLog] { return [] }
    func saveAutoMaterialExportLog(_ log: AutoMaterialExportLog) async throws { print("⚠️ saveAutoMaterialExportLog: Mocked success") }
    
    func saveProductionTransaction(_ tx: ProductionTransaction) async throws { print("⚠️ saveProductionTransaction: Mocked success") }
    func fetchProductionTransactions(mode: String?) async throws -> [ProductionTransaction] { return [] }
    func softDeleteProductionTransaction(id: UUID, deletedAt: Date, deletedByName: String?, deleteNote: String?) async throws { print("⚠️ softDeleteProductionTransaction: Mocked success") }
    
    func fetchMaterials() async throws -> [MaterialItem] { return [] }
    func saveMaterial(_ material: MaterialItem) async throws { print("⚠️ saveMaterial: Mocked success") }
    func updateMaterial(_ material: MaterialItem) async throws { print("⚠️ updateMaterial: Mocked success") }
    func deleteMaterial(_ id: UUID) async throws { print("⚠️ deleteMaterial: Mocked success") }
    func saveCategory(_ name: String, kind: String) async throws { print("⚠️ saveCategory(\(name), \(kind)): Mocked success") }
    func fetchCategories(kind: String) async throws -> [String] { return [] }
    func fetchTradingParties(type: String) async throws -> [TradingParty] { return [] }
    func upsertTradingParty(_ party: TradingParty) async throws { print("⚠️ upsertTradingParty: Mocked success") }
    func deleteTradingParty(id: UUID) async throws { print("⚠️ deleteTradingParty: Mocked success") }
    func fetchTradingPartyByName(_ name: String, type: String) async throws -> TradingParty? { return nil }
    func fetchWebsiteLeads() async throws -> [WebsiteLead] { return [] }
    func updateWebsiteLeadStatus(id: UUID, status: String, note: String?) async throws { print("⚠️ updateWebsiteLeadStatus: Mocked success") }
    func upsertAttendanceRecord(_ record: AttendanceRecordDB) async throws { print("⚠️ upsertAttendanceRecord: Mocked success") }
    func fetchAttendanceRecords(userId: UUID, from: Date, to: Date) async throws -> [AttendanceRecordDB] { return [] }
    func fetchTodayAttendance(userId: UUID) async throws -> AttendanceRecordDB? { return nil }
    func saveLeaveRequest(_ request: LeaveRequest) async throws { print("⚠️ saveLeaveRequest: Mocked success") }
    func fetchLeaveRequests(userId: UUID) async throws -> [LeaveRequest] { return [] }
    func fetchAllLeaveRequests() async throws -> [LeaveRequest] { return [] }
    func updateLeaveRequestStatus(id: UUID, status: String, reviewNote: String?) async throws { print("⚠️ updateLeaveRequestStatus: Mocked success") }
    func nextSequenceNumber(type: String) async -> Int { return 0 }
}
#endif


// MARK: - DTOs (Data Transfer Objects) to match SQL Schema
struct OperatingExpenseDTO: Codable {
    let id: UUID
    let title: String
    let amount: Double
    let note: String?
    let created_at: Date
    let creator_id: UUID?
    let creator_name: String?
    let store_id: UUID?
    
    init(id: UUID, title: String, amount: Double, note: String?, created_at: Date, creator_id: UUID?, creator_name: String?, store_id: UUID?) {
        self.id = id
        self.title = title
        self.amount = amount
        self.note = note
        self.created_at = created_at
        self.creator_id = creator_id
        self.creator_name = creator_name
        self.store_id = store_id
    }
    
    init(from domain: OperatingExpense) {
        self.id = domain.id
        self.title = domain.title
        self.amount = domain.amount
        self.note = domain.note
        self.created_at = domain.createdAt
        self.creator_id = domain.creatorId
        self.creator_name = domain.creatorName
        self.store_id = nil
    }
    
    func toDomain() -> OperatingExpense {
        var e = OperatingExpense(id: id, title: title, amount: amount, note: note, createdAt: created_at)
        e.creatorId = creator_id
        e.creatorName = creator_name
        return e
    }
    
    func withStore(_ storeId: UUID) -> OperatingExpenseDTO {
        var copy = self
        copy = OperatingExpenseDTO(id: id, title: title, amount: amount, note: note, created_at: created_at, creator_id: creator_id, creator_name: creator_name, store_id: storeId)
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
    let stock_weight_kg: Double?
    let cost_price: Double?
    let store_id: UUID?
    let barcode: String?
    let image_url: String?
    let is_finished_good: Bool?
    let has_vat: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, category, image_name, color, stock_quantity, stock_weight_kg, cost_price, store_id, barcode, image_url, is_finished_good, has_vat
        case costPrice // Fallback for camelCase
    }
    
    init(id: UUID, name: String, price: Double, category: String, image_name: String?, color: String?, stock_quantity: Int, stock_weight_kg: Double?, cost_price: Double?, store_id: UUID?, barcode: String?, image_url: String?, is_finished_good: Bool? = nil, has_vat: Bool? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.image_name = image_name
        self.color = color
        self.stock_quantity = stock_quantity
        self.stock_weight_kg = stock_weight_kg
        self.cost_price = cost_price
        self.store_id = store_id
        self.barcode = barcode
        self.image_url = image_url
        self.is_finished_good = is_finished_good
        self.has_vat = has_vat
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
        stock_weight_kg = try container.decodeIfPresent(Double.self, forKey: .stock_weight_kg)
        store_id = try container.decodeIfPresent(UUID.self, forKey: .store_id)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        image_url = try container.decodeIfPresent(String.self, forKey: .image_url)
        is_finished_good = try container.decodeIfPresent(Bool.self, forKey: .is_finished_good)
        has_vat = try container.decodeIfPresent(Bool.self, forKey: .has_vat)
        
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
        try container.encode(stock_weight_kg, forKey: .stock_weight_kg)
        try container.encode(cost_price, forKey: .cost_price)
        try container.encode(store_id, forKey: .store_id)
        try container.encode(barcode, forKey: .barcode)
        try container.encode(image_url, forKey: .image_url)
        try container.encode(is_finished_good ?? false, forKey: .is_finished_good)
        try container.encodeIfPresent(has_vat, forKey: .has_vat)
    }
    
    init(from domain: Product, inventory: [String: Int] = [:]) {
        self.id = domain.id
        self.name = domain.name
        self.price = domain.price
        self.category = domain.category
        self.image_name = domain.imageName
        self.color = domain.color
        self.stock_quantity = domain.stockQuantity
        self.stock_weight_kg = Double(domain.stockQuantity) / 1000.0
        self.cost_price = domain.costPrice
        self.store_id = nil
        self.barcode = domain.barcode
        self.image_url = domain.imageURL
        self.is_finished_good = domain.isFinishedGood
        self.has_vat = domain.hasVAT
    }
    
    func toDomain() -> Product {
        return Product(id: id, name: name, price: price, costPrice: cost_price ?? 0, category: category, imageName: image_name ?? "shippingbox", color: color ?? "gray", imageData: nil, imageURL: image_url, stockQuantity: stock_quantity, barcode: barcode, isFinishedGood: is_finished_good ?? false, hasVAT: has_vat ?? false)
    }
    
    func withStore(_ storeId: UUID) -> ProductDTO {
        return ProductDTO(id: id, name: name, price: price, category: category, image_name: image_name, color: color, stock_quantity: stock_quantity, stock_weight_kg: stock_weight_kg, cost_price: cost_price, store_id: storeId, barcode: barcode, image_url: image_url, is_finished_good: is_finished_good, has_vat: has_vat)
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
    let customer_name: String?
    let receipt_image_url: String?
    let sequence_number: String?
    let vat_rate: Double?
    let vat_amount: Double?
    
    init(id: UUID, total_amount: Double, created_at: Date, order_items: [OrderItemDTO]?, store_id: UUID?, is_paid: Bool?, creator_id: UUID?, creator_name: String?, customer_name: String?, receipt_image_url: String?, sequence_number: String?, vat_rate: Double?, vat_amount: Double?) {
        self.id = id
        self.total_amount = total_amount
        self.created_at = created_at
        self.order_items = order_items
        self.store_id = store_id
        self.is_paid = is_paid
        self.creator_id = creator_id
        self.creator_name = creator_name
        self.customer_name = customer_name
        self.receipt_image_url = receipt_image_url
        self.sequence_number = sequence_number
        self.vat_rate = vat_rate
        self.vat_amount = vat_amount
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
        self.customer_name = domain.customerName
        self.receipt_image_url = domain.paymentReceiptURL
        self.sequence_number = domain.sequenceNumber
        self.vat_rate = domain.vatRate
        self.vat_amount = domain.vatAmount
    }
    
    func toDomain() -> Bill {
        let items = order_items?.map { $0.toDomain() } ?? []
        // Recalculate totalCost from items because it's not stored in OrderDTO
        let calculatedTotalCost = items.reduce(0) { $0 + $1.totalCost }
        var bill = Bill(id: id, createdAt: created_at, items: items, total: total_amount, totalCost: calculatedTotalCost)
        bill.isPaid = is_paid ?? true
        bill.creatorId = creator_id
        bill.creatorName = creator_name
        bill.customerName = customer_name
        bill.paymentReceiptURL = receipt_image_url
        bill.sequenceNumber = sequence_number
        bill.vatRate = vat_rate
        bill.vatAmount = vat_amount ?? 0
        return bill
    }
    
    func withStore(_ storeId: UUID) -> OrderDTO {
        return OrderDTO(id: id, total_amount: total_amount, created_at: created_at, order_items: order_items, store_id: storeId, is_paid: is_paid, creator_id: creator_id, creator_name: creator_name, customer_name: customer_name, receipt_image_url: receipt_image_url, sequence_number: sequence_number, vat_rate: vat_rate, vat_amount: vat_amount)
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
    let creator_id: UUID?
    let creator_name: String?
    let restock_items: [RestockItemDTO]?
    let store_id: UUID?
    let is_deleted: Bool?
    let deleted_at: Date?
    let deleted_by: UUID?
    let sequence_number: String?
    let supplier_name: String?
    let supplier_phone: String?
    let supplier_address: String?
    
    init(id: UUID, total_cost: Double, created_at: Date, creator_id: UUID?, creator_name: String?, restock_items: [RestockItemDTO]?, store_id: UUID?, is_deleted: Bool?, deleted_at: Date?, deleted_by: UUID?, sequence_number: String?, supplier_name: String?, supplier_phone: String?, supplier_address: String?) {
        self.id = id
        self.total_cost = total_cost
        self.created_at = created_at
        self.creator_id = creator_id
        self.creator_name = creator_name
        self.restock_items = restock_items
        self.store_id = store_id
        self.is_deleted = is_deleted
        self.deleted_at = deleted_at
        self.deleted_by = deleted_by
        self.sequence_number = sequence_number
        self.supplier_name = supplier_name
        self.supplier_phone = supplier_phone
        self.supplier_address = supplier_address
    }
    
    init(from domain: RestockBill) {
        self.id = domain.id
        self.total_cost = domain.totalCost
        self.created_at = domain.createdAt
        self.creator_id = domain.creatorId
        self.creator_name = domain.creatorName
        self.restock_items = nil
        self.store_id = nil
        self.is_deleted = domain.isDeleted
        self.deleted_at = domain.deletedAt
        self.deleted_by = domain.deletedBy
        self.sequence_number = domain.sequenceNumber
        self.supplier_name = domain.supplierName
        self.supplier_phone = domain.supplierPhone
        self.supplier_address = domain.supplierAddress
    }
    
    func toDomain() -> RestockBill {
        let items = restock_items?.map { $0.toDomain() } ?? []
        var bill = RestockBill(id: id, createdAt: created_at, items: items, totalCost: total_cost)
        bill.isDeleted = is_deleted ?? false
        bill.deletedAt = deleted_at
        bill.deletedBy = deleted_by
        bill.creatorId = creator_id
        bill.creatorName = creator_name
        bill.sequenceNumber = sequence_number
        bill.supplierName = supplier_name
        bill.supplierPhone = supplier_phone
        bill.supplierAddress = supplier_address
        return bill
    }
    
    func withStore(_ storeId: UUID) -> RestockBillDTO {
        return RestockBillDTO(id: id, total_cost: total_cost, created_at: created_at, creator_id: creator_id, creator_name: creator_name, restock_items: restock_items, store_id: storeId, is_deleted: is_deleted, deleted_at: deleted_at, deleted_by: deleted_by, sequence_number: sequence_number, supplier_name: supplier_name, supplier_phone: supplier_phone, supplier_address: supplier_address)
    }
}

struct RestockItemDTO: Codable {
    let id: UUID
    let bill_id: UUID
    let product_name: String
    let quantity: Int
    let unit_price: Double
    let additional_cost: Double?
    let suggested_price: Double?
    let category: String?
    let source: String?
    let document_image_url: String?
    let weight_per_unit_grams: Int?
    let is_finished_good: Bool?
    let unit: String?
    let has_vat: Bool?
    // import_from_finished_good và source_finished_good_id không có trong DB schema — chỉ decode, không encode
    let import_from_finished_good: Bool?
    let source_finished_good_id: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, bill_id, product_name, quantity, unit_price
        case additional_cost, suggested_price, category, source
        case document_image_url, weight_per_unit_grams, is_finished_good, unit, has_vat
        // Không include import_from_finished_good và source_finished_good_id khi encode
    }
    
    // Custom decode để đọc các cột optional không có trong DB
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bill_id = try c.decode(UUID.self, forKey: .bill_id)
        product_name = try c.decode(String.self, forKey: .product_name)
        quantity = try c.decode(Int.self, forKey: .quantity)
        unit_price = try c.decode(Double.self, forKey: .unit_price)
        additional_cost = try c.decodeIfPresent(Double.self, forKey: .additional_cost)
        suggested_price = try c.decodeIfPresent(Double.self, forKey: .suggested_price)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        document_image_url = try c.decodeIfPresent(String.self, forKey: .document_image_url)
        weight_per_unit_grams = try c.decodeIfPresent(Int.self, forKey: .weight_per_unit_grams)
        is_finished_good = try c.decodeIfPresent(Bool.self, forKey: .is_finished_good)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        has_vat = try c.decodeIfPresent(Bool.self, forKey: .has_vat)
        // Các cột không có trong DB — set nil
        import_from_finished_good = nil
        source_finished_good_id = nil
    }
    
    init(from domain: RestockItem, billId: UUID) {
        self.id = domain.id
        self.bill_id = billId
        self.product_name = domain.name
        self.quantity = domain.quantity
        self.unit_price = domain.unitPrice
        self.additional_cost = domain.additionalCost
        self.suggested_price = domain.suggestedPrice
        self.category = domain.category
        self.source = domain.source
        self.document_image_url = domain.documentImageURL
        self.weight_per_unit_grams = domain.weightPerUnitGrams
        self.is_finished_good = domain.isFinishedGood
        self.unit = domain.unit
        self.has_vat = domain.hasVAT
        self.import_from_finished_good = nil  // không lưu vào DB
        self.source_finished_good_id = nil    // không lưu vào DB
    }
    
    func toDomain() -> RestockItem {
        return RestockItem(
            id: id,
            name: product_name,
            quantity: quantity,
            unitPrice: unit_price,
            additionalCost: additional_cost ?? 0,
            suggestedPrice: suggested_price,
            isConfirmed: true,
            category: category,
            source: source,
            documentImageURL: document_image_url,
            weightPerUnitGrams: weight_per_unit_grams,
            isFinishedGood: is_finished_good ?? false,
            importFromFinishedGood: import_from_finished_good ?? false,
            sourceFinishedGoodId: source_finished_good_id,
            unit: unit,
            hasVAT: has_vat ?? false
        )
    }
}

struct RestockEditDTO: Codable {
    let id: UUID
    let restock_bill_id: UUID
    let created_at: Date
    let old_total: Double
    let new_total: Double
    let editor_id: UUID?
    let editor_name: String?
    let note: String?
    let details: [String]?
    let store_id: UUID?
    
    init(from domain: RestockEdit, storeId: UUID) {
        self.id = domain.id
        self.restock_bill_id = domain.restockBillId
        self.created_at = domain.createdAt
        self.old_total = domain.oldTotal
        self.new_total = domain.newTotal
        self.editor_id = domain.editorId
        self.editor_name = domain.editorName
        self.note = domain.note
        self.details = domain.details
        self.store_id = storeId
    }
    
    func toDomain() -> RestockEdit {
        return RestockEdit(
            id: id,
            restockBillId: restock_bill_id,
            createdAt: created_at,
            oldTotal: old_total,
            newTotal: new_total,
            editorId: editor_id,
            editorName: editor_name,
            note: note,
            details: details
        )
    }
}

struct MaterialDTO: Codable {
    let id: UUID
    let name: String
    let stock_quantity: Int
    let stock_weight_kg: Double?
    let last_unit_price: Double
    let category: String?
    let store_id: UUID?
    let barcode: String?
    let unit: String?
    let has_vat: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, stock_quantity, stock_weight_kg, last_unit_price, category, store_id, barcode, unit, has_vat
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        stock_quantity = try c.decode(Int.self, forKey: .stock_quantity)
        stock_weight_kg = try c.decodeIfPresent(Double.self, forKey: .stock_weight_kg)
        last_unit_price = try c.decode(Double.self, forKey: .last_unit_price)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        store_id = try c.decodeIfPresent(UUID.self, forKey: .store_id)
        barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        has_vat = try c.decodeIfPresent(Bool.self, forKey: .has_vat)
    }
    
    init(id: UUID, name: String, stock_quantity: Int, stock_weight_kg: Double?, last_unit_price: Double, category: String?, store_id: UUID?, barcode: String? = nil, unit: String? = nil, has_vat: Bool? = nil) {
        self.id = id
        self.name = name
        self.stock_quantity = stock_quantity
        self.stock_weight_kg = stock_weight_kg
        self.last_unit_price = last_unit_price
        self.category = category
        self.store_id = store_id
        self.barcode = barcode
        self.unit = unit
        self.has_vat = has_vat
    }
    
    init(from domain: MaterialItem, storeId: UUID?) {
        self.id = domain.id
        self.name = domain.name
        self.stock_quantity = domain.stockQuantity
        self.stock_weight_kg = Double(domain.stockQuantity) / 1000.0
        self.last_unit_price = domain.lastUnitPrice
        self.category = domain.category
        self.store_id = storeId
        self.barcode = domain.barcode
        self.unit = domain.unit
        self.has_vat = domain.hasVAT
    }
    
    func toDomain() -> MaterialItem {
        return MaterialItem(id: id, name: name, stockQuantity: stock_quantity, lastUnitPrice: last_unit_price, category: category ?? Category.materials.rawValue, barcode: barcode, unit: unit, hasVAT: has_vat ?? false)
    }
}

struct ProductionTransactionDTO: Codable {
    let id: UUID
    let mode: String
    let total_cost: Double
    let created_at: Date
    let note: String?
    let creator_id: UUID?
    let creator_name: String?
    let production_transaction_items: [ProductionTransactionItemDTO]?
    let store_id: UUID?
    // Export buyer & payment info
    let buyer_name: String?
    let buyer_phone: String?
    let buyer_address: String?
    let grand_total: Double?
    let paid_amount: Double?
    let debt_amount: Double?
    let vat_rate: Double?
    let vat_amount: Double?
    let is_paid: Bool?
    let expected_pay_date: Date?
    let payment_receipt_url: String?
    let sequence_number: String?
    // Soft delete
    let is_deleted: Bool?
    let deleted_at: Date?
    let deleted_by_name: String?
    let delete_note: String?

    init(id: UUID, mode: String, total_cost: Double, created_at: Date, note: String?, creator_id: UUID?, creator_name: String?, production_transaction_items: [ProductionTransactionItemDTO]?, store_id: UUID?,
         buyer_name: String? = nil, buyer_phone: String? = nil, buyer_address: String? = nil,
         grand_total: Double? = nil, paid_amount: Double? = nil, debt_amount: Double? = nil,
         vat_rate: Double? = nil, vat_amount: Double? = nil, is_paid: Bool? = nil,
         expected_pay_date: Date? = nil, payment_receipt_url: String? = nil, sequence_number: String? = nil,
         is_deleted: Bool? = nil, deleted_at: Date? = nil, deleted_by_name: String? = nil, delete_note: String? = nil) {
        self.id = id
        self.mode = mode
        self.total_cost = total_cost
        self.created_at = created_at
        self.note = note
        self.creator_id = creator_id
        self.creator_name = creator_name
        self.production_transaction_items = production_transaction_items
        self.store_id = store_id
        self.buyer_name = buyer_name
        self.buyer_phone = buyer_phone
        self.buyer_address = buyer_address
        self.grand_total = grand_total
        self.paid_amount = paid_amount
        self.debt_amount = debt_amount
        self.vat_rate = vat_rate
        self.vat_amount = vat_amount
        self.is_paid = is_paid
        self.expected_pay_date = expected_pay_date
        self.payment_receipt_url = payment_receipt_url
        self.sequence_number = sequence_number
        self.is_deleted = is_deleted
        self.deleted_at = deleted_at
        self.deleted_by_name = deleted_by_name
        self.delete_note = delete_note
    }

    init(from domain: ProductionTransaction) {
        self.id = domain.id
        self.mode = domain.mode
        self.total_cost = domain.totalCost
        self.created_at = domain.createdAt
        self.note = domain.note
        self.creator_id = domain.creatorId
        self.creator_name = domain.creatorName
        self.production_transaction_items = nil
        self.store_id = nil
        self.buyer_name = domain.buyerName
        self.buyer_phone = domain.buyerPhone
        self.buyer_address = domain.buyerAddress
        self.grand_total = domain.grandTotal
        self.paid_amount = domain.paidAmount
        self.debt_amount = domain.debtAmount
        self.vat_rate = domain.vatRate
        self.vat_amount = domain.vatAmount
        self.is_paid = domain.isPaid
        self.expected_pay_date = domain.expectedPayDate
        self.payment_receipt_url = domain.paymentReceiptURL
        self.sequence_number = domain.sequenceNumber
        self.is_deleted = domain.isDeleted
        self.deleted_at = domain.deletedAt
        self.deleted_by_name = domain.deletedByName
        self.delete_note = domain.deleteNote
    }

    func toDomain() -> ProductionTransaction {
        let items = production_transaction_items?.map { $0.toDomain() } ?? []
        var tx = ProductionTransaction(id: id, createdAt: created_at, mode: mode, items: items, totalCost: total_cost, note: note)
        tx.creatorId = creator_id
        tx.creatorName = creator_name
        tx.buyerName = buyer_name
        tx.buyerPhone = buyer_phone
        tx.buyerAddress = buyer_address
        tx.grandTotal = grand_total
        tx.paidAmount = paid_amount
        tx.debtAmount = debt_amount
        tx.vatRate = vat_rate
        tx.vatAmount = vat_amount
        tx.isPaid = is_paid ?? false
        tx.expectedPayDate = expected_pay_date
        tx.paymentReceiptURL = payment_receipt_url
        tx.sequenceNumber = sequence_number
        tx.isDeleted = is_deleted ?? false
        tx.deletedAt = deleted_at
        tx.deletedByName = deleted_by_name
        tx.deleteNote = delete_note
        return tx
    }

    func withStore(_ storeId: UUID) -> ProductionTransactionDTO {
        return ProductionTransactionDTO(
            id: id, mode: mode, total_cost: total_cost, created_at: created_at,
            note: note, creator_id: creator_id, creator_name: creator_name,
            production_transaction_items: production_transaction_items, store_id: storeId,
            buyer_name: buyer_name, buyer_phone: buyer_phone, buyer_address: buyer_address,
            grand_total: grand_total, paid_amount: paid_amount, debt_amount: debt_amount,
            vat_rate: vat_rate, vat_amount: vat_amount, is_paid: is_paid,
            expected_pay_date: expected_pay_date, payment_receipt_url: payment_receipt_url,
            sequence_number: sequence_number,
            is_deleted: is_deleted, deleted_at: deleted_at, deleted_by_name: deleted_by_name, delete_note: delete_note
        )
    }
}

struct ProductionTransactionItemDTO: Codable {
    let id: UUID
    let transaction_id: UUID
    let item_name: String
    let quantity: Int
    let unit_price: Double
    let additional_cost: Double?
    let source: String?
    let document_image_url: String?
    let unit: String?
    
    init(from domain: RestockItem, transactionId: UUID) {
        self.id = domain.id
        self.transaction_id = transactionId
        self.item_name = domain.name
        self.quantity = domain.quantity
        self.unit_price = domain.unitPrice
        self.additional_cost = domain.additionalCost
        self.source = domain.source
        self.document_image_url = domain.documentImageURL
        self.unit = domain.unit
    }
    
    func toDomain() -> RestockItem {
        return RestockItem(
            id: id,
            name: item_name,
            quantity: quantity,
            unitPrice: unit_price,
            additionalCost: additional_cost ?? 0,
            source: source,
            documentImageURL: document_image_url,
            unit: unit
        )
    }
}

struct ProductionTransactionItemNoUnitDTO: Codable {
    let id: UUID
    let transaction_id: UUID
    let item_name: String
    let quantity: Int
    let unit_price: Double
    let additional_cost: Double?
    let source: String?
    let document_image_url: String?
    
    init(from domain: RestockItem, transactionId: UUID) {
        self.id = domain.id
        self.transaction_id = transactionId
        self.item_name = domain.name
        self.quantity = domain.quantity
        self.unit_price = domain.unitPrice
        self.additional_cost = domain.additionalCost
        self.source = domain.source
        self.document_image_url = domain.documentImageURL
    }
}

struct MaterialNoUnitDTO: Codable {
    let id: UUID
    let name: String
    let stock_quantity: Int
    let stock_weight_kg: Double?
    let last_unit_price: Double
    let category: String?
    let store_id: UUID?
    let barcode: String?
    
    init(from domain: MaterialItem, storeId: UUID?) {
        self.id = domain.id
        self.name = domain.name
        self.stock_quantity = domain.stockQuantity
        self.stock_weight_kg = Double(domain.stockQuantity) / 1000.0
        self.last_unit_price = domain.lastUnitPrice
        self.category = domain.category
        self.store_id = storeId
        self.barcode = domain.barcode
    }
}

struct AutoMaterialExportTemplateDTO: Codable {
    let id: UUID
    let name: String
    let data: AutoMaterialExportTemplateData
    let created_at: Date
    let updated_at: Date
    let store_id: UUID?
    
    init(from domain: AutoMaterialExportTemplate, storeId: UUID) {
        self.id = domain.id
        self.name = domain.name
        self.data = domain.data
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
        self.store_id = storeId
    }
    
    func toDomain() -> AutoMaterialExportTemplate {
        return AutoMaterialExportTemplate(
            id: id,
            name: name,
            data: data,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

struct AutoMaterialExportLogDTO: Codable {
    let id: UUID
    let template_id: UUID?
    let template_name: String
    let production_transaction_id: UUID
    let data: AutoMaterialExportLogData
    let created_at: Date
    let creator_id: UUID?
    let creator_name: String?
    let store_id: UUID?
    
    init(from domain: AutoMaterialExportLog, storeId: UUID) {
        self.id = domain.id
        self.template_id = domain.templateId
        self.template_name = domain.templateName
        self.production_transaction_id = domain.productionTransactionId
        self.data = domain.data
        self.created_at = domain.createdAt
        self.creator_id = domain.creatorId
        self.creator_name = domain.creatorName
        self.store_id = storeId
    }
    
    func toDomain() -> AutoMaterialExportLog {
        var log = AutoMaterialExportLog(
            id: id,
            createdAt: created_at,
            templateId: template_id,
            templateName: template_name,
            productionTransactionId: production_transaction_id,
            data: data
        )
        log.creatorId = creator_id
        log.creatorName = creator_name
        return log
    }
}

struct UserFeedbackDTO: Codable {
    let id: UUID
    let content: String
    let created_at: Date
    let user_id: UUID?
    let store_id: UUID?
}

struct DeviceTokenDTO: Codable {
    let token: String
    let user_id: UUID?
    let created_at: Date
    let platform: String?
}

struct OrderEditDTO: Codable {
    let id: UUID
    let order_id: UUID
    let created_at: Date
    let old_total: Double
    let new_total: Double
    let editor_id: UUID?
    let editor_name: String?
    let store_id: UUID?
    let note: String?
    let details: [String]?
    
    init(id: UUID, order_id: UUID, created_at: Date, old_total: Double, new_total: Double, editor_id: UUID?, editor_name: String?, store_id: UUID?, note: String?, details: [String]?) {
        self.id = id
        self.order_id = order_id
        self.created_at = created_at
        self.old_total = old_total
        self.new_total = new_total
        self.editor_id = editor_id
        self.editor_name = editor_name
        self.store_id = store_id
        self.note = note
        self.details = details
    }
    
    init(from domain: OrderEdit, storeId: UUID?) {
        self.id = domain.id
        self.order_id = domain.orderId
        self.created_at = domain.createdAt
        self.old_total = domain.oldTotal
        self.new_total = domain.newTotal
        self.editor_id = domain.editorId
        self.editor_name = domain.editorName
        self.store_id = storeId
        self.note = domain.note
        self.details = domain.details
    }
    
    func toDomain() -> OrderEdit {
        return OrderEdit(id: id, orderId: order_id, createdAt: created_at, oldTotal: old_total, newTotal: new_total, editorId: editor_id, editorName: editor_name, note: note, details: details)
    }
}

struct ProductionEditDTO: Codable {
    let id: UUID
    let transaction_id: UUID
    let created_at: Date
    let old_total: Double
    let new_total: Double
    let editor_id: UUID?
    let editor_name: String?
    let store_id: UUID?
    let note: String?
    let details: [String]?
    
    init(id: UUID, transaction_id: UUID, created_at: Date, old_total: Double, new_total: Double, editor_id: UUID?, editor_name: String?, store_id: UUID?, note: String?, details: [String]?) {
        self.id = id
        self.transaction_id = transaction_id
        self.created_at = created_at
        self.old_total = old_total
        self.new_total = new_total
        self.editor_id = editor_id
        self.editor_name = editor_name
        self.store_id = store_id
        self.note = note
        self.details = details
    }
    
    init(from domain: ProductionEdit, storeId: UUID?) {
        self.id = domain.id
        self.transaction_id = domain.transactionId
        self.created_at = domain.createdAt
        self.old_total = domain.oldTotal
        self.new_total = domain.newTotal
        self.editor_id = domain.editorId
        self.editor_name = domain.editorName
        self.store_id = storeId
        self.note = domain.note
        self.details = domain.details
    }
    
    func toDomain() -> ProductionEdit {
        return ProductionEdit(id: id, transactionId: transaction_id, createdAt: created_at, oldTotal: old_total, newTotal: new_total, editorId: editor_id, editorName: editor_name, note: note, details: details)
    }
}

// MARK: - TradingParty Model & DTO

struct TradingParty: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var partyType: String  // "buyer" | "supplier"
    var name: String
    var phone: String
    var address: String
    var totalDebt: Double = 0
    var updatedAt: Date = Date()
    var imageURLs: [String] = []
}

struct TradingPartyDTO: Codable {
    let id: UUID
    let store_id: UUID
    let party_type: String
    let name: String
    let phone: String?
    let address: String?
    let total_debt: Double?
    let updated_at: Date?
    let image_urls: [String]?

    init(from domain: TradingParty, storeId: UUID) {
        self.id = domain.id
        self.store_id = storeId
        self.party_type = domain.partyType
        self.name = domain.name
        self.phone = domain.phone
        self.address = domain.address
        self.total_debt = domain.totalDebt
        self.updated_at = domain.updatedAt
        self.image_urls = domain.imageURLs.isEmpty ? nil : domain.imageURLs
    }

    func toDomain() -> TradingParty {
        TradingParty(
            id: id,
            partyType: party_type,
            name: name,
            phone: phone ?? "",
            address: address ?? "",
            totalDebt: total_debt ?? 0,
            updatedAt: updated_at ?? Date(),
            imageURLs: image_urls ?? []
        )
    }
}

// MARK: - Attendance Record Model & DTO

struct AttendanceRecordDB: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var storeId: UUID
    var userId: UUID
    var userName: String
    var date: String          // "yyyy-MM-dd"
    var checkInTime: Date?
    var checkOutTime: Date?
    var checkInSelfieURL: String?
    var checkOutSelfieURL: String?
    var note: String?
    var status: String        // "checked_in" | "checked_out" | "late"
    var shift: Int = 1        // Ca làm: 1, 2, 3...
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct AttendanceRecordDTO: Codable {
    let id: UUID
    let store_id: UUID
    let user_id: UUID
    let user_name: String
    let date: String
    let check_in_time: Date?
    let check_out_time: Date?
    let check_in_selfie_url: String?
    let check_out_selfie_url: String?
    let note: String?
    let status: String
    let shift: Int?
    let created_at: Date?
    let updated_at: Date?

    init(from domain: AttendanceRecordDB) {
        self.id = domain.id
        self.store_id = domain.storeId
        self.user_id = domain.userId
        self.user_name = domain.userName
        self.date = domain.date
        self.check_in_time = domain.checkInTime
        self.check_out_time = domain.checkOutTime
        self.check_in_selfie_url = domain.checkInSelfieURL
        self.check_out_selfie_url = domain.checkOutSelfieURL
        self.note = domain.note
        self.status = domain.status
        self.shift = domain.shift
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
    }

    func toDomain() -> AttendanceRecordDB {
        AttendanceRecordDB(
            id: id,
            storeId: store_id,
            userId: user_id,
            userName: user_name,
            date: date,
            checkInTime: check_in_time,
            checkOutTime: check_out_time,
            checkInSelfieURL: check_in_selfie_url,
            checkOutSelfieURL: check_out_selfie_url,
            note: note,
            status: status,
            shift: shift ?? 1,
            createdAt: created_at ?? Date(),
            updatedAt: updated_at ?? Date()
        )
    }
}

// MARK: - Leave Request Model & DTO

struct LeaveRequest: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var storeId: UUID
    var userId: UUID
    var userName: String
    var leaveDate: String       // "yyyy-MM-dd"
    var leaveType: String       // "personal" | "sick" | "annual" | "other"
    var reason: String?
    var status: String          // "pending" | "approved" | "rejected"
    var reviewedBy: UUID?
    var reviewedAt: Date?
    var reviewNote: String?
    var createdAt: Date = Date()

    var leaveTypeLabel: String {
        switch leaveType {
        case "sick":     return "Nghỉ bệnh"
        case "annual":   return "Nghỉ phép năm"
        case "other":    return "Lý do khác"
        default:         return "Việc cá nhân"
        }
    }

    var statusLabel: String {
        switch status {
        case "approved": return "Đã duyệt"
        case "rejected": return "Từ chối"
        default:         return "Chờ duyệt"
        }
    }

    var statusColor: String {   // dùng string để Codable dễ, UI tự map
        switch status {
        case "approved": return "green"
        case "rejected": return "red"
        default:         return "orange"
        }
    }
}

struct LeaveRequestDTO: Codable {
    let id: UUID
    let store_id: UUID
    let user_id: UUID
    let user_name: String
    let leave_date: String
    let leave_type: String
    let reason: String?
    let status: String
    let reviewed_by: UUID?
    let reviewed_at: Date?
    let review_note: String?
    let created_at: Date?

    init(from domain: LeaveRequest) {
        self.id = domain.id
        self.store_id = domain.storeId
        self.user_id = domain.userId
        self.user_name = domain.userName
        self.leave_date = domain.leaveDate
        self.leave_type = domain.leaveType
        self.reason = domain.reason
        self.status = domain.status
        self.reviewed_by = domain.reviewedBy
        self.reviewed_at = domain.reviewedAt
        self.review_note = domain.reviewNote
        self.created_at = domain.createdAt
    }

    func toDomain() -> LeaveRequest {
        LeaveRequest(
            id: id, storeId: store_id, userId: user_id, userName: user_name,
            leaveDate: leave_date, leaveType: leave_type, reason: reason,
            status: status, reviewedBy: reviewed_by, reviewedAt: reviewed_at,
            reviewNote: review_note, createdAt: created_at ?? Date()
        )
    }
}
