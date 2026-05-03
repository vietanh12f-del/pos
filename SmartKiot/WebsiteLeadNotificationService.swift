import Foundation
import Supabase

// MARK: - WebsiteLeadNotificationService
// Lắng nghe Realtime INSERT trên bảng website_leads.
// Khi có khách hàng mới từ website, gửi local notification cho chủ cửa hàng.

class WebsiteLeadNotificationService {
    static let shared = WebsiteLeadNotificationService()

    private var channel: RealtimeChannelV2?
    private var streamTask: Task<Void, Never>?

    private init() {}

    struct LeadPayload: Decodable {
        let full_name: String
        let phone: String
        let lead_type: String
        let store_id: String?
    }

    // MARK: - Start / Stop

    func start() {
        stop() // Đảm bảo dọn dẹp kết nối cũ

        let client = SupabaseConfig.client
        let ch = client.channel("website_leads_realtime")
        self.channel = ch

        print("📡 [WebsiteLeadNotification] Starting Realtime Stream...")

        // Lắng nghe INSERT (Khách mới)
        let insertionStream = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "website_leads"
        )

        streamTask = Task {
            print("🚀 [WebsiteLeadNotification] Insert Stream Task started")
            for await change in insertionStream {
                print("⚡️ [WebsiteLeadNotification] NEW INSERT EVENT DETECTED!")
                await handleNewInsert(change)
            }
        }

        Task {
            await ch.subscribe()
            
            let userId = SupabaseConfig.client.auth.currentUser?.id.uuidString ?? "nil"
            print("📡 [WebsiteLeadNotification] Channel Subscribed - User: \(userId)")
            
            // Health check
            try? await self.performHealthCheck()
            
            #if DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationManager.shared.notifyNewWebsiteLead(
                    title: "✅ Realtime đã kết nối",
                    body: "Sẽ nhận thông báo khi có khách mới từ website"
                )
            }
            #endif
        }
    }

    private func performHealthCheck() async throws {
        let client = SupabaseConfig.client
        let recentLeads: [LeadPayload] = try await client.database
            .from("website_leads")
            .select("*")
            .limit(1)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        if let latest = recentLeads.first {
            print("✅ [WebsiteLeadNotification] Health Check: Latest lead in DB is '\(latest.full_name)'")
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        
        if let ch = channel {
            Task { await ch.unsubscribe() }
            channel = nil
            print("🔌 [WebsiteLeadNotification] Unsubscribed")
        }
    }

    // MARK: - Handle new lead

    @MainActor
    private func handleNewInsert(_ change: InsertAction) {
        let decoder = SupabaseConfig.client.database.configuration.decoder
        do {
            let payload = try change.decodeRecord(as: LeadPayload.self, decoder: decoder)
            print("📥 [WebsiteLeadNotification] Decoded Lead: \(payload.full_name) - \(payload.phone)")

            // Kiểm tra store_id khớp (Nếu website không gửi store_id thì mặc định là gửi cho tất cả)
            if let storeIdStr = payload.store_id,
               let leadStoreId = UUID(uuidString: storeIdStr) {
                
                let currentStoreId = StoreManager.shared.currentStore?.id
                if let currentStoreId = currentStoreId, leadStoreId != currentStoreId {
                    print("⏭️ [WebsiteLeadNotification] Lead belongs to another store (\(leadStoreId)). Skipping.")
                    return
                }
            }

            let typeLabel: String
            switch payload.lead_type {
            case "appointment": typeLabel = "Đặt lịch hẹn"
            case "partner":     typeLabel = "Đối tác"
            default:            typeLabel = "Tư vấn"
            }

            let title = "🌐 Khách mới từ Website"
            let body = "\(payload.full_name) · \(payload.phone) — \(typeLabel)"

            NotificationManager.shared.notifyNewWebsiteLead(title: title, body: body)
            print("🔔 [WebsiteLeadNotification] Notification triggered: \(body)")

        } catch {
            print("❌ [WebsiteLeadNotification] Decode error: \(error)")
            print("⚠️ [WebsiteLeadNotification] Raw Insert Data: \(change.record)")
        }
    }
}
