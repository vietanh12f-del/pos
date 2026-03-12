import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NotificationManager.shared.configure()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Notification settings: authStatus=\(settings.authorizationStatus.rawValue)")
        }
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        print("🚀 App did finish launching")
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs device token: \(token)")
        Task {
            do {
                try await SupabaseDatabaseService().saveDeviceToken(token)
                print("✅ Saved device token to Supabase")
            } catch {
                print("Failed to save device token: \(error)")
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print("📩 Received remote notification: \(userInfo)")
        return .noData
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("🌙 App did enter background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("🌤️ App will enter foreground")
    }
}
