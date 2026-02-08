import AppIntents
import SwiftUI

// MARK: - App Intents for Apple Intelligence & Siri
// These intents allow the app to expose "Nhập hàng" and "Tạo đơn" capabilities to the system.

@available(iOS 16.0, *)
struct CreateOrderIntent: AppIntent {
    static var title: LocalizedStringResource = "Tạo Đơn Hàng"
    static var description = IntentDescription("Tạo đơn hàng mới bằng giọng nói hoặc nhập liệu")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Nội dung")
    var content: String?

    func perform() async throws -> some IntentResult {
        // In a real implementation, this would pass the 'content' string to the OrderViewModel
        // via a Notification or a shared Dependency Injection container.
        
        if let text = content {
            // Post notification for the ViewModel to pick up
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TriggerVoiceInput"), object: text)
            }
            return .result(dialog: "Đã gửi yêu cầu: \(text)")
        } else {
            return .result(dialog: "Bạn muốn mua gì?")
        }
    }
}

@available(iOS 16.0, *)
struct RestockIntent: AppIntent {
    static var title: LocalizedStringResource = "Nhập Hàng"
    static var description = IntentDescription("Nhập hàng vào kho")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Nội dung nhập")
    var content: String?

    func perform() async throws -> some IntentResult {
        if let text = content {
             DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TriggerRestockInput"), object: text)
            }
            return .result(dialog: "Đang xử lý nhập hàng: \(text)")
        } else {
            return .result(dialog: "Bạn muốn nhập gì?")
        }
    }
}

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateOrderIntent(),
            phrases: [
                "Tạo đơn hàng trong \(.applicationName)",
                "Bán hàng \(.applicationName)",
                "Order \(.applicationName)"
            ],
            shortTitle: "Tạo Đơn Hàng",
            systemImageName: "cart.fill"
        )
        
        AppShortcut(
            intent: RestockIntent(),
            phrases: [
                "Nhập hàng \(.applicationName)",
                "Restock \(.applicationName)",
                "Thêm kho \(.applicationName)"
            ],
            shortTitle: "Nhập Hàng",
            systemImageName: "archivebox.fill"
        )
        
        AppShortcut(
            intent: VoiceOrderIntent(),
            phrases: [
                "Tạo đơn nhanh \(.applicationName)",
                "Kiot Voice \(.applicationName)"
            ],
            shortTitle: "Kiot Voice Order",
            systemImageName: "mic.fill"
        )
    }
}
