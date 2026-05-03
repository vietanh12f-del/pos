import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    static let soundKey = "chat_sound_enabled"
    static let notificationsKey = "chat_notifications_enabled"
    static let bannerKey = "chat_banner_enabled"
    
    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    var soundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.soundKey) }
    }
    
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.notificationsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.notificationsKey) }
    }
    
    var bannerEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.bannerKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.bannerKey) }
    }
    
    func notifyIncomingMessage(title: String, body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if soundEnabled {
            content.sound = UNNotificationSound.default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Website Lead Notification

    static let websiteLeadNotificationsKey = "website_lead_notifications_enabled"

    var websiteLeadNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.websiteLeadNotificationsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.websiteLeadNotificationsKey) }
    }

    /// Gửi thông báo khi có khách hàng mới từ website
    func notifyNewWebsiteLead(title: String, body: String) {
        print("📣 [NotificationManager] notifyNewWebsiteLead called: \(title) - \(body)")
        guard websiteLeadNotificationsEnabled else { 
            print("⚠️ [NotificationManager] websiteLeadNotificationsEnabled is FALSE, skipping")
            return 
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "WEBSITE_LEAD"
        if soundEnabled {
            content.sound = UNNotificationSound.default
        }
        let request = UNNotificationRequest(
            identifier: "website-lead-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        var options: UNNotificationPresentationOptions = []
        if bannerEnabled { options.insert(.banner) }
        if soundEnabled { options.insert(.sound) }
        options.insert(.badge)
        completionHandler(options)
    }
}
