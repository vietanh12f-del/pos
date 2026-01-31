import SwiftUI
import Combine

enum TabType: String, CaseIterable, Codable, Identifiable {
    case home = "Trang chủ"
    case orders = "Đơn hàng"
    case restock = "Kho" // RestockHistoryView
    case goods = "Hàng hóa" // Product List / SettingsView (renamed in logic)
    case chat = "Chat"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .orders: return "list.clipboard.fill"
        case .restock: return "archivebox.fill"
        case .goods: return "cube.box.fill"
        case .chat: return "message.fill"
        }
    }
    
    // Maps to the tag in ContentView's TabView
    var tagIndex: Int {
        switch self {
        case .home: return 0
        case .orders: return 1
        case .restock: return 3
        case .goods: return 4 // SettingsView acting as Goods/Product list
        case .chat: return 5
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
        } else {
            // Default configuration (Home, Chat | FAB | Orders, Goods)
            // We store them in order. When rendering, we'll split them 2-2 around the FAB.
            self.activeTabs = [
                TabItemConfig(type: .home),
                TabItemConfig(type: .chat),
                TabItemConfig(type: .orders),
                TabItemConfig(type: .goods)
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
        if activeTabs.count >= 4 { return } // Limit to 4 slots (plus FAB)
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
