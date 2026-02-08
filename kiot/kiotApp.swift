//
//  kiotApp.swift
//  kiot
//
//  Created by Ngan Thanh on 26/1/26.
//

import SwiftUI
import Supabase

@main
struct kiotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // Force Light Mode for consistent theming
                .onOpenURL { url in
                    print("🔗 Opened URL: \(url)")
                    Task {
                        // Handle OAuth callback
                        // This might vary based on Supabase SDK version, but usually we just need to let the client know,
                        // or if the client observes the session it might happen automatically if we store the session.
                        // However, explicit handling is safer.
                        // SupabaseConfig.client.handle(url) is not always available.
                        // Common pattern:
                        try? await SupabaseConfig.client.auth.session(from: url)
                    }
                }
        }
    }
}
