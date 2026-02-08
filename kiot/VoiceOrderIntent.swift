import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct VoiceOrderIntent: AppIntent {
    static var title: LocalizedStringResource = "Kiot Voice Order"
    static var description = IntentDescription("Tạo đơn hoặc nhập hàng nhanh bằng giọng nói")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Nội dung", requestValueDialog: "Bạn muốn nhập gì? (Ví dụ: Bán 2 cà phê, Nhập 50 hoa hồng)")
    var phrase: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to OrderViewModel
        // We delay slightly to ensure view is loaded if app was just launched
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        NotificationCenter.default.post(name: NSNotification.Name("TriggerVoiceInput"), object: phrase)
        return .result()
    }
}


