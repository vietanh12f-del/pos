import SwiftUI

struct MoreView: View {
    @Binding var selectedTab: Int
    @Binding var showProductionManagement: Bool
    @Binding var showProductionReport: Bool
    
    let menuItems: [MenuItem] = [
        MenuItem(id: 5, title: "Chat", icon: "message.fill", color: .blue),
        MenuItem(id: 4, title: "Chi Phí", icon: "banknote.fill", color: .green),
        MenuItem(id: 7, title: "Thống Kê", icon: "chart.bar.xaxis", color: .orange),
        MenuItem(id: 6, title: "Cài Đặt", icon: "gearshape.fill", color: .gray),
        MenuItem(id: 99, title: "Quản Lý Sản Xuất", icon: "gearshape.2.fill", color: .purple),
        MenuItem(id: 100, title: "Báo Cáo Sản Xuất", icon: "doc.text.magnifyingglass", color: .purple)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(menuItems) { item in
                        Button(action: {
                            if item.id == 99 {
                                showProductionManagement = true
                            } else if item.id == 100 {
                                showProductionReport = true
                            } else {
                                selectedTab = item.id
                            }
                        }) {
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(item.color.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: item.icon)
                                            .font(.title2)
                                            .foregroundStyle(item.color)
                                    )
                                
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Thêm")
            .background(Color.themeBackgroundLight)
        }
    }
}

struct MenuItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let color: Color
}
