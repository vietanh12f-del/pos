import SwiftUI

struct EditTabBarView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Đang hiển thị (Tối đa 4)")) {
                    ForEach(tabBarManager.activeTabs) { tab in
                        HStack {
                            Image(systemName: tab.type.icon)
                                .foregroundStyle(Color.themePrimary)
                                .frame(width: 30)
                            Text(tab.type.rawValue)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.gray)
                        }
                    }
                    .onMove(perform: tabBarManager.moveActiveTab)
                    .onDelete { indexSet in
                        for index in indexSet {
                            let tab = tabBarManager.activeTabs[index]
                            tabBarManager.removeTab(tab)
                        }
                    }
                }
                
                Section(header: Text("Các tab khác")) {
                    ForEach(tabBarManager.hiddenTabs) { tab in
                        HStack {
                            Image(systemName: tab.type.icon)
                                .foregroundStyle(.gray)
                                .frame(width: 30)
                            Text(tab.type.rawValue)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    tabBarManager.addTab(tab)
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.green)
                                    .font(.title2)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Khôi phục mặc định") {
                        withAnimation {
                            tabBarManager.resetToDefault()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Tùy chỉnh menu")
            .navigationBarItems(trailing: Button("Xong") { dismiss() })
            .environment(\.editMode, .constant(.active)) // Enable move mode by default
        }
    }
}
