import Foundation
import Supabase

struct SupabaseConfig {
    static let url = URL(string: "https://cgqxrsoaxgyvcskbixuu.supabase.co")!
    static let key = "sb_publishable_sMLyG_TPBYkpKA6K1OV34g_LeCb0ugh"
    
    // Twilio Verify Service SID: VAaa6f3be2810c0a3a33709c9d2d4efb39
    // Configure this in Supabase Dashboard -> Authentication -> Providers -> Phone -> Twilio
    
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: key,
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
