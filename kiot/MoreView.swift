import SwiftUI

struct MoreView: View {
    @Binding var selectedTab: Int
    
    let menuItems: [MenuItem] = [
        MenuItem(id: 5, title: "Chat", icon: "message.fill", color: .blue),
        MenuItem(id: 4, title: "Chi phí", icon: "banknote.fill", color: .green),
        MenuItem(id: 7, title: "Thống kê", icon: "chart.bar.xaxis", color: .orange),
        MenuItem(id: 6, title: "Cài đặt", icon: "gearshape.fill", color: .gray)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(menuItems) { item in
                        Button(action: {
                            selectedTab = item.id
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
