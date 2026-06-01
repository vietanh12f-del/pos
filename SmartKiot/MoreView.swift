import SwiftUI

struct MoreView: View {
    @Binding var selectedTab: Int
    @Binding var showProductionManagement: Bool
    @Binding var showProductionReport: Bool
    @Binding var showCustomerManagement: Bool
    @AppStorage("production_enabled_global") private var productionEnabled: Bool = true
    @State private var showAttendance = false
    @ObservedObject var viewModel: OrderViewModel
    @ObservedObject private var storeManager = StoreManager.shared

    private var menuItems: [MenuItem] {
        var items: [MenuItem] = []
        
        // Chat - available to all employees (cần quyền viewHome)
        if storeManager.hasPermission(.viewHome) {
            items.append(MenuItem(id: 5, title: "Chat", icon: "message.fill", color: .blue))
        }
        
        // Chi Phí - viewExpenses
        if storeManager.hasPermission(.viewExpenses) {
            items.append(MenuItem(id: 4, title: "Chi Phí", icon: "banknote.fill", color: .green))
        }
        
        // Thống Kê - viewStatistics
        if storeManager.hasPermission(.viewStatistics) {
            items.append(MenuItem(id: 7, title: "Thống Kê", icon: "chart.bar.xaxis", color: .orange))
        }
        
        // Cài Đặt - manageEmployees hoặc owner/manager
        if storeManager.hasPermission(.manageEmployees) || storeManager.currentMember?.role == .owner {
            items.append(MenuItem(id: 6, title: "Cài Đặt", icon: "gearshape.fill", color: .gray))
        }
        
        // Quản Lý Khách Hàng - manageCustomers
        if storeManager.hasPermission(.manageCustomers) {
            items.append(MenuItem(id: 101, title: "Quản Lý Khách Hàng", icon: "person.2.fill", color: .teal))
        }
        
        // Điểm danh - manageEmployees
        if storeManager.hasPermission(.manageEmployees) {
            items.append(MenuItem(id: 102, title: "Điểm danh", icon: "calendar.badge.checkmark", color: .indigo))
        }
        
        // Sản xuất
        if productionEnabled {
            // Báo Cáo Sản Xuất - chỉ cần viewProduction (xem báo cáo)
            if storeManager.hasPermission(.viewProduction) {
                items.append(MenuItem(id: 100, title: "Báo Cáo Sản Xuất", icon: "doc.text.magnifyingglass", color: .purple))
            }
            // Quản Lý Sản Xuất - cần manageProduction (tạo/sửa/xóa phiếu SX)
            if storeManager.hasPermission(.manageProduction) {
                items.append(MenuItem(id: 99, title: "Quản Lý Sản Xuất", icon: "gearshape.2.fill", color: .purple))
            }
        }
        
        return items
    }

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
                            } else if item.id == 101 {
                                showCustomerManagement = true
                            } else if item.id == 102 {
                                showAttendance = true
                            } else {
                                selectedTab = item.id
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
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
                }
                .padding()
            }
            .navigationBarHidden(true)
            .background(Color.themeBackgroundLight)
            .sheet(isPresented: $showAttendance) {
                AttendanceView()
            }
        }
    }
}

struct MenuItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let color: Color
}
