import SwiftUI
import Combine

enum TabType: String, CaseIterable, Codable, Identifiable {
    case home = "Trang chủ"
    case orders = "Đơn hàng"
    case restock = "Kho" // RestockHistoryView
    case goods = "Hàng hóa" // Product List
    case chat = "Chat"
    case settings = "Cài đặt"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .orders: return "list.clipboard.fill"
        case .restock: return "archivebox.fill"
        case .goods: return "cube.box.fill"
        case .chat: return "message.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    // Maps to the tag in ContentView's TabView
    var tagIndex: Int {
        switch self {
        case .home: return 0
        case .orders: return 1
        case .restock: return 3
        case .goods: return 4
        case .chat: return 5
        case .settings: return 6
        }
    }
}

struct TabItemConfig: Identifiable, Codable, Equatable {
    var id: String { type.rawValue }
    let type: TabType
}

class CustomTabBarManager: ObservableObject {
    @Published var activeTabs: [TabItemConfig] = []
    @Published var hiddenTabs: [TabItemConfig] = []
    
    init() {
        loadConfig()
    }
    
    func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "activeTabs"),
           let decoded = try? JSONDecoder().decode([TabItemConfig].self, from: data) {
            self.activeTabs = decoded
            
            // Migration: If we increased the limit, maybe we want to auto-add new tabs if they are missing and we have space?
            // For now, let's just ensure we respect the stored config but allow adding more up to 6.
        } else {
            // Default configuration
            self.activeTabs = [
                TabItemConfig(type: .home),
                TabItemConfig(type: .orders),
                TabItemConfig(type: .restock),
                TabItemConfig(type: .goods),
                TabItemConfig(type: .chat),
                TabItemConfig(type: .settings)
            ]
        }
        
        updateHiddenTabs()
    }
    
    func updateHiddenTabs() {
        let allTypes = TabType.allCases
        let activeTypes = activeTabs.map { $0.type }
        self.hiddenTabs = allTypes.filter { !activeTypes.contains($0) }.map { TabItemConfig(type: $0) }
    }
    
    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(activeTabs) {
            UserDefaults.standard.set(encoded, forKey: "activeTabs")
        }
    }
    
    func moveActiveTab(from source: IndexSet, to destination: Int) {
        activeTabs.move(fromOffsets: source, toOffset: destination)
        saveConfig()
    }
    
    func addTab(_ tab: TabItemConfig) {
        if activeTabs.count >= 6 { return } // Limit to 6 slots
        activeTabs.append(tab)
        updateHiddenTabs()
        saveConfig()
    }
    
    func removeTab(_ tab: TabItemConfig) {
        activeTabs.removeAll { $0.id == tab.id }
        updateHiddenTabs()
        saveConfig()
    }
    
    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "activeTabs")
        loadConfig()
    }
}
