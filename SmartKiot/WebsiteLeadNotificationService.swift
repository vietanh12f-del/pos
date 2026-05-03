import Foundation
import Combine
import Supabase

// MARK: - WebsiteLeadNotificationService
// Lắng nghe Realtime INSERT trên bảng website_leads.
// Khi có khách hàng mới từ website, gửi local notification và cập nhật badge.

class WebsiteLeadNotificationService: ObservableObject {
    static let shared = WebsiteLeadNotificationService()

    /// Số leads có status "new" — dùng để hiển thị badge trên icon chuông
    @Published var newLeadsCount: Int = 0

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
        stop()

        let client = SupabaseConfig.client
        let ch = client.channel("website_leads_realtime")
        self.channel = ch

        print("📡 [WebsiteLeadNotification] Starting Realtime Stream...")

        let insertionStream = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "website_leads"
        )

        streamTask = Task {
            for await change in insertionStream {
                print("⚡️ [WebsiteLeadNotification] NEW INSERT EVENT DETECTED!")
                await handleNewInsert(change)
            }
        }

        Task {
            await ch.subscribe()
            print("✅ [WebsiteLeadNotification] Channel Subscribed")
            // Load số leads mới ngay khi kết nối
            await refreshNewLeadsCount()

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

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        if let ch = channel {
            Task { await ch.unsubscribe() }
            channel = nil
        }
        DispatchQueue.main.async { self.newLeadsCount = 0 }
    }

    /// Gọi sau khi user xem/xử lý leads để reset badge
    func refreshNewLeadsCount() async {
        do {
            let leads = try await SupabaseDatabaseService().fetchWebsiteLeads()
            let count = leads.filter { $0.status == "new" }.count
            await MainActor.run { self.newLeadsCount = count }
        } catch {
            print("❌ [WebsiteLeadNotification] refreshNewLeadsCount error: \(error)")
        }
    }

    // MARK: - Handle new lead

    @MainActor
    private func handleNewInsert(_ change: InsertAction) {
        let decoder = SupabaseConfig.client.database.configuration.decoder
        do {
            let payload = try change.decodeRecord(as: LeadPayload.self, decoder: decoder)
            print("📥 [WebsiteLeadNotification] Decoded Lead: \(payload.full_name) - \(payload.phone)")

            if let storeIdStr = payload.store_id,
               let leadStoreId = UUID(uuidString: storeIdStr),
               let currentStoreId = StoreManager.shared.currentStore?.id,
               leadStoreId != currentStoreId {
                print("⏭️ [WebsiteLeadNotification] Lead belongs to another store. Skipping.")
                return
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

            // Tăng badge ngay lập tức
            newLeadsCount += 1

        } catch {
            print("❌ [WebsiteLeadNotification] Decode error: \(error)")
        }
    }
}
