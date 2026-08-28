import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import PhotosUI
import Combine
import ImageIO
import Supabase
import Auth

// MARK: - Theme Colors (Moved to Components.swift)


struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @StateObject private var viewModel = OrderViewModel()
    @StateObject private var tabBarManager = CustomTabBarManager()
    @State private var selectedTab: Int = 0
    @State private var showNewOrder: Bool = false
    @State private var isTabBarVisible: Bool = true
    @State private var showEditTabBar: Bool = false
    @State private var showNewRestock: Bool = false
    @State private var showNewProduct: Bool = false
    @State private var showNewChat: Bool = false
    @State private var showAddEmployee: Bool = false
    @State private var costsSubTab: Int = 0 // State for Costs & Imports sub-tab
    @State private var showNewOperatingExpense: Bool = false // Sheet state for Operating Expense
    @State private var isKeyboardVisibleGlobal: Bool = false
    @State private var showProductionManagement: Bool = false
    @State private var showProductionReport: Bool = false
    @State private var showCustomerManagement: Bool = false
    @State private var navigateToBillId: UUID? = nil
    @State private var skippedPhoneLink: Bool = false
    
    init() {
        // Default TabBar
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        if !authManager.isAuthenticated {
            AuthenticationView()
        } else if needsPhoneLink && !skippedPhoneLink {
            LinkPhoneView(onSkip: { skippedPhoneLink = true })
        } else if storeManager.currentStore == nil {
            StoreSelectionView()
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        HomeDashboardView(viewModel: viewModel, showNewOrder: $showNewOrder, selectedTab: $selectedTab, showProductionManagement: $showProductionManagement, showProductionReport: $showProductionReport, showCustomerManagement: $showCustomerManagement)
                            .tabItem {
                                Label("Tổng quan", systemImage: "house.fill")
                            }
                            .tag(0)
                        
                        OrderHistoryView(viewModel: viewModel, navigateToBillId: $navigateToBillId)
                            .tabItem {
                                Label("Đơn hàng", systemImage: "clock.arrow.circlepath")
                            }
                            .tag(1)
                        
                        InventoryView(viewModel: viewModel, showingAddProduct: $showNewProduct, showNewRestock: $showNewRestock)
                            .tabItem {
                                Label("Kho hàng", systemImage: "cube.box.fill")
                            }
                            .tag(3)
                        
                        CostsAndImportsView(viewModel: viewModel, selectedSubTab: $costsSubTab, showNewOperatingExpense: $showNewOperatingExpense)
                            .tabItem {
                                Label("Chi Phí", systemImage: "banknote.fill")
                            }
                            .tag(4)
                        
                        ChatView(orderViewModel: viewModel, showNewChatSheet: $showNewChat, isTabBarVisible: $isTabBarVisible)
                            .tabItem {
                                Label("Chat", systemImage: "message.fill")
                            }
                            .tag(5)
                        
                        StatisticsView(viewModel: viewModel, selectedTab: $selectedTab)
                            .tabItem {
                                Label("Thống Kê", systemImage: "chart.bar.xaxis")
                            }
                            .tag(7)
                        
                        SettingsView(tabBarManager: tabBarManager, isTabBarVisible: $isTabBarVisible)
                            .tabItem {
                                Label("Cài Đặt", systemImage: "gearshape.fill")
                            }
                            .tag(6)
                        
                        MoreView(selectedTab: $selectedTab, showProductionManagement: $showProductionManagement, showProductionReport: $showProductionReport, showCustomerManagement: $showCustomerManagement, viewModel: viewModel)
                            .tabItem {
                                Label("Thêm", systemImage: "square.grid.2x2.fill")
                            }
                            .tag(8)
                    }
                    .accentColor(.themePrimary)
                    .toolbar(.hidden, for: .tabBar)
                    // Add padding to prevent content from being hidden behind the custom tab bar
                    // Height = 50 (button) + 12 (top) + 8 (bottom) = 70 + Safe Area
                    .padding(.bottom, isTabBarVisible ? (isKeyboardVisibleGlobal ? 10 : (70 + geometry.safeAreaInsets.bottom)) : 0)
                    
                    // Custom Tab Bar
                    if isTabBarVisible {
                        CustomTabBarView(selectedTab: $selectedTab, showNewOrder: $showNewOrder, showNewRestock: $showNewRestock, showNewChat: $showNewChat, showNewOperatingExpense: $showNewOperatingExpense, showAddEmployee: $showAddEmployee)
                            .transition(.move(edge: .bottom))
                            .zIndex(1)
                    }
                    
                    // Voice Assistant Overlay
                    VoiceOverlayView(viewModel: viewModel, bottomPadding: isTabBarVisible ? (70 + geometry.safeAreaInsets.bottom + 10) : 20)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .fullScreenCover(isPresented: $showNewOrder) {
                    SmartOrderEntryView(viewModel: viewModel)
                }
                .fullScreenCover(isPresented: $showNewRestock, onDismiss: {
                    // Chuyển sang tab Kho hàng và tab Lịch sử nhập (NBL)
                    selectedTab = 3
                    NotificationCenter.default.post(
                        name: NSNotification.Name("InventoryShowHistory"),
                        object: nil
                    )
                }) {
                    RestockEntryView(viewModel: viewModel)
                }
                .sheet(isPresented: $showNewOperatingExpense) {
                    AddOperatingExpenseView(viewModel: viewModel)
                }
                .sheet(isPresented: $showEditTabBar) {
                    EditTabBarView(tabBarManager: tabBarManager)
                }
                .sheet(isPresented: $showAddEmployee) {
                    AddEmployeeView(isPresented: $showAddEmployee, onAddSuccess: {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshEmployees"), object: nil)
                    })
                }
                .sheet(isPresented: $showProductionManagement) {
                    ProductionManagementView(viewModel: viewModel)
                }
                .sheet(isPresented: $showProductionReport) {
                    ProductionReportView(viewModel: viewModel)
                }
                .sheet(isPresented: $showCustomerManagement) {
                    CustomerManagementView()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToWebsiteLeads"))) { _ in
                    selectedTab = 8
                    showCustomerManagement = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToBill"))) { notif in
                    if let billId = notif.userInfo?["billId"] as? UUID {
                        showCustomerManagement = false
                        selectedTab = 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            navigateToBillId = billId
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToProductionTx"))) { notif in
                    if let txId = notif.userInfo?["txId"] as? UUID,
                       let mode = notif.userInfo?["mode"] as? String {
                        showCustomerManagement = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showProductionManagement = true
                            // Đợi sheet present xong (~0.5s) rồi mới gửi notification
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ProductionScrollToTx"),
                                    object: nil,
                                    userInfo: ["txId": txId, "mode": mode]
                                )
                            }
                        }
                    }
                }                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToTab"))) { notif in
                    if let tab = notif.userInfo?["tab"] as? Int {
                        selectedTab = tab
                    }
                }
                .onChange(of: viewModel.editingBill) { bill in
                    if bill != nil {
                        showNewOrder = true
                    }
                }
                .onChange(of: viewModel.shouldShowOrderSheet) { newValue in
                    if newValue {
                        showNewOrder = true
                        viewModel.shouldShowOrderSheet = false // Reset
                    }
                }
                .onChange(of: viewModel.shouldShowRestockSheet) { newValue in
                    if newValue {
                        showNewRestock = true
                        viewModel.shouldShowRestockSheet = false // Reset
                    }
                }
                .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                    if isAuthenticated {
                        print("🔐 Authenticated. Forcing data reload.")
                        Task {
                            await viewModel.loadData(force: true)
                        }
                    }
                }
                .onAppear {
                    // Handle auto-login to last store ONLY on app launch
                    // Check if we are already authenticated but no store selected
                    if authManager.isAuthenticated && storeManager.currentStore == nil {
                        Task {
                            await storeManager.fetchStores()
                            await storeManager.restoreLastStoreIfPossible()
                        }
                    }
                    // Khởi động lắng nghe website leads nếu store đã có sẵn
                    if storeManager.currentStore != nil {
                        WebsiteLeadNotificationService.shared.start()
                    }
                }
                .onChange(of: authManager.currentUserProfile?.id) { _ in
                    // When switching accounts, clear current store to avoid showing previous store
                    WebsiteLeadNotificationService.shared.stop()
                    storeManager.currentStore = nil
                    Task {
                        await storeManager.fetchStores()
                        await storeManager.restoreLastStoreIfPossible()
                    }
                }
                .task(id: storeManager.currentStore?.id) {
                    if storeManager.currentStore != nil {
                        viewModel.clearData()
                        await viewModel.loadData(force: true)
                    }
                }
                .onChange(of: storeManager.currentStore?.id) { newId in
                    // Khởi động / khởi động lại lắng nghe khách hàng mới từ website
                    WebsiteLeadNotificationService.shared.stop()
                    AppNotificationService.shared.teardown()
                    if newId != nil {
                        WebsiteLeadNotificationService.shared.start()
                    }
                }
                .alert("Lỗi", isPresented: $viewModel.showErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    isKeyboardVisibleGlobal = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    isKeyboardVisibleGlobal = false
                }
            }
        }
    }
    
    private var needsPhoneLink: Bool {
        let profilePhone = authManager.currentUserProfile?.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let authPhone = SupabaseConfig.client.auth.currentUser?.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profilePhone.isEmpty || !authPhone.isEmpty { return false }
        return true
    }
}
    
    
    // MARK: - Home Dashboard
    struct HomeDashboardView: View {
        @ObservedObject var viewModel: OrderViewModel
        @Binding var showNewOrder: Bool
        @Binding var selectedTab: Int
        @Binding var showProductionManagement: Bool
        @Binding var showProductionReport: Bool
        @Binding var showCustomerManagement: Bool
        @State private var isKeyboardVisible = false
        @ObservedObject private var leadService = WebsiteLeadNotificationService.shared
        @State private var showLeadsSheet = false
        @AppStorage("production_enabled_global") private var productionEnabledGlobal: Bool = true
        @State private var allProductionTx: [ProductionTransaction] = []
        @State private var showNotificationCenter = false
        @ObservedObject private var notifService = AppNotificationService.shared
        @State private var showLeaveApprovalFromNotif = false
        @State private var showAttendance = false
        @State private var showGuide = false
        @State private var showRetailProfitInfo = false
        @State private var showWholesaleProfitInfo = false

        // MARK: - Date range selection
        enum QuickRange: String, CaseIterable {
            case today     = "Hôm nay"
            case thisWeek  = "Tuần này"
            case thisMonth = "Tháng này"
            case custom    = "Tuỳ chọn"

            var reportRange: ReportDateRange? {
                switch self {
                case .today:     return .today
                case .thisWeek:  return .thisWeek
                case .thisMonth: return .thisMonth
                case .custom:    return nil
                }
            }
        }

        @State private var quickRange: QuickRange = .today
        @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
        @State private var customEnd: Date = Date()
        @State private var showCustomPicker = false

        private var activeRange: ReportDateRange {
            switch quickRange {
            case .today:     return .today
            case .thisWeek:  return .thisWeek
            case .thisMonth: return .thisMonth
            case .custom:    return .custom(start: customStart, end: customEnd)
            }
        }

        private var rangeLabel: String {
            let df = DateFormatter()
            df.locale = Locale(identifier: "vi_VN")
            df.dateFormat = "dd/MM"
            switch quickRange {
            case .today:
                let f2 = DateFormatter()
                f2.locale = Locale(identifier: "vi_VN")
                f2.dateFormat = "dd/MM/yyyy"
                return f2.string(from: Date())
            case .thisWeek:
                let cal = Calendar.current
                let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
                let start = cal.date(from: comps) ?? Date()
                let end = cal.date(byAdding: .day, value: 6, to: start) ?? Date()
                return "\(df.string(from: start)) – \(df.string(from: end))"
            case .thisMonth:
                let f2 = DateFormatter()
                f2.locale = Locale(identifier: "vi_VN")
                f2.dateFormat = "MM/yyyy"
                return "Tháng \(f2.string(from: Date()))"
            case .custom:
                return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
            }
        }
        
        var searchContentView2: some View {
            Group {
                if viewModel.searchSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("Không tìm thấy sản phẩm nào")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("\"\(viewModel.searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button("Xóa tìm kiếm") {
                            viewModel.searchText = ""
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                } else {
                    List {
                        ForEach(viewModel.searchSuggestions) { product in
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                viewModel.addProduct(product)
                                viewModel.searchText = ""
                            }) {
                                HStack(spacing: 12) {
                                    if let data = product.imageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 20, height: 20)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: product.imageName)
                                            .font(.headline)
                                            .foregroundStyle(Color.themePrimary)
                                            .frame(width: 20, height: 20)
                                            .background(Color.themePrimary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(product.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                            if product.hasVAT {
                                                Text("VAT")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.85))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(product.category)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(formatCurrency(product.price))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.themePrimary)
                                        
                                        let stock = viewModel.stockLevel(for: product.name)
                                        Text("Kho: \(stock)")
                                            .font(.caption)
                                            .foregroundStyle(stock > 0 ? .gray : .red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.white)
                    .padding(.bottom, 320)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        
        var body: some View {
            NavigationStack {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Top Bar
                            HStack {
                                Button(action: {
                                    selectedTab = 6 // Navigate to Settings
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                                        
                                        VStack(alignment: .leading) {
                                            HStack(spacing: 6) {
                                                Text(StoreManager.shared.currentStore?.name ?? "Kiot")
                                                    .font(.headline)
                                                    .foregroundStyle(Color.themeTextDark)
                                                
                                                // Database Status
                                                if viewModel.isDatabaseConnected {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "icloud.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(.green)
                                                        Text("Đã kết nối")
                                                            .font(.caption2)
                                                            .foregroundStyle(.green)
                                                    }
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "exclamationmark.icloud.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(.red)
                                                        Text("Mất kết nối")
                                                            .font(.caption2)
                                                            .foregroundStyle(.red)
                                                    }
                                                }
                                            }
                                            
                                            Text(currentDateString())
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showLeadsSheet = true
                                }) {
                                    HStack(spacing: 6) {
                                        // Text ngắn bên trái chuông khi có leads mới
                                        if leadService.newLeadsCount > 0 {
                                            Text("\(leadService.newLeadsCount) khách mới")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Color.teal))
                                                .transition(.scale.combined(with: .opacity))
                                        }

                                        ZStack(alignment: .topTrailing) {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 40, height: 40)
                                                .shadow(color: .black.opacity(0.05), radius: 2)
                                                .overlay(
                                                    Image(systemName: leadService.newLeadsCount > 0 ? "bell.badge.fill" : "bell")
                                                        .foregroundStyle(leadService.newLeadsCount > 0 ? Color.teal : Color.themeTextDark)
                                                )

                                            if leadService.newLeadsCount > 0 {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 10, height: 10)
                                                    .offset(x: 2, y: -2)
                                            }
                                        }
                                    }
                                    .animation(.spring(duration: 0.3), value: leadService.newLeadsCount)
                                }
                                .sheet(isPresented: $showLeadsSheet) {
                                    CustomerManagementView(initialTab: .all)
                                        .onDisappear {
                                            Task { await WebsiteLeadNotificationService.shared.refreshNewLeadsCount() }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)

                            // Notification tile
                            NotificationTile(service: notifService) {
                                showNotificationCenter = true
                            }
                            .padding(.horizontal)

                            // Revenue Date Range Section
                            VStack(spacing: 12) {
                                // Quick range buttons
                                HStack(spacing: 8) {
                                    ForEach(QuickRange.allCases, id: \.self) { r in
                                        Button {
                                            quickRange = r
                                            if r == .custom { showCustomPicker = true }
                                        } label: {
                                            Text(r.rawValue)
                                                .font(.caption)
                                                .fontWeight(quickRange == r ? .bold : .regular)
                                                .foregroundStyle(quickRange == r ? .white : Color.themeTextDark)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule()
                                                        .fill(quickRange == r ? Color.themePrimary : Color.white)
                                                )
                                                .overlay(
                                                    Capsule()
                                                        .stroke(quickRange == r ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)

                                // Range label
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(Color.themePrimary)
                                    Text(rangeLabel)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    if quickRange == .custom {
                                        Button {
                                            showCustomPicker = true
                                        } label: {
                                            Text("Đổi ngày")
                                                .font(.caption)
                                                .foregroundStyle(Color.themePrimary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)

                                // Financial Summary
                                if StoreManager.shared.hasPermission(.viewReports) {
                                    VStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            StatCard(title: "Doanh thu", value: formatCurrency(viewModel.revenue(for: activeRange)), icon: "arrow.down.left", trend: "", isPositive: true,
                                                info: "Tổng tiền thu từ các đơn bán lẻ đã thanh toán trong khoảng thời gian đang xem.")
                                            StatCard(title: "Giá vốn", value: formatCurrency(viewModel.cogs(for: activeRange)), icon: "arrow.up.right", trend: "", isPositive: true,
                                                info: "Chi phí vốn hàng bán (COGS) — tính theo giá nhập bình quân (AVCO) của từng sản phẩm tại thời điểm bán.")
                                        }

                                        let profit = viewModel.grossProfit(for: activeRange)
                                        HStack(spacing: 12) {
                                            Button {
                                                selectedTab = 7
                                            } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Text("LỢI NHUẬN BÁN LẺ")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(.white.opacity(0.8))
                                                        Button {
                                                            showRetailProfitInfo = true
                                                        } label: {
                                                            Image(systemName: "info.circle")
                                                                .font(.subheadline)
                                                                .foregroundStyle(.white.opacity(0.7))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                    Text(formatCurrency(profit))
                                                        .font(.title)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                                Spacer()
                                                Image(systemName: profit >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                                                    .font(.title)
                                                    .foregroundStyle(.white)
                                            }
                                            .padding()
                                            .background(profit >= 0 ? Color.themePrimary : Color.red)
                                            .cornerRadius(16)
                                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .alert("Lợi nhuận bán lẻ", isPresented: $showRetailProfitInfo) {
                                            Button("Đã hiểu", role: .cancel) {}
                                        } message: {
                                            Text("Lợi nhuận bán lẻ = Doanh thu − Giá vốn\n\nDoanh thu: tổng đơn đã thanh toán (bán lẻ).\nGiá vốn (COGS): tính theo giá nhập bình quân AVCO tại thời điểm bán.")
                                        }

                                        // Ô lợi nhuận bán sỉ — chỉ hiện khi production enabled
                                        if productionEnabledGlobal {
                                            let ws = viewModel.wholesaleStats(for: activeRange, allTransactions: allProductionTx)
                                            let wsProfit = ws.revenue - ws.materialExportCost
                                            HStack(spacing: 12) {
                                                Button {
                                                    selectedTab = 7
                                                } label: {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        HStack(spacing: 6) {
                                                            Text("LỢI NHUẬN BÁN SỈ")
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                                .foregroundStyle(.white.opacity(0.8))
                                                            Button {
                                                                showWholesaleProfitInfo = true
                                                            } label: {
                                                                Image(systemName: "info.circle")
                                                                    .font(.subheadline)
                                                                    .foregroundStyle(.white.opacity(0.7))
                                                            }
                                                            .buttonStyle(.plain)
                                                        }
                                                        Text(formatCurrency(wsProfit))
                                                            .font(.title)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(.white)
                                                    }
                                                    Spacer()
                                                    Image(systemName: wsProfit >= 0 ? "shippingbox.fill" : "exclamationmark.triangle.fill")
                                                        .font(.title)
                                                        .foregroundStyle(.white)
                                                }
                                                .padding()
                                                .background(wsProfit >= 0 ? Color.purple : Color.red)
                                                .cornerRadius(16)
                                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .alert("Lợi nhuận bán sỉ (Tổng quan)", isPresented: $showWholesaleProfitInfo) {
                                                Button("Đã hiểu", role: .cancel) {}
                                            } message: {
                                                Text("Lợi nhuận bán sỉ (Tổng quan) = Doanh thu sỉ − Tổng giá trị xuất nguyên liệu\n\nDoanh thu sỉ: tổng grandTotal của các phiếu Xuất Thành Phẩm.\nTổng giá trị xuất nguyên liệu: tổng giá trị các phiếu Xuất Nguyên Liệu trong cùng kỳ.")
                                            }
                                        }
                                    }
                                } else {
                                    VStack(alignment: .center, spacing: 12) {
                                        Image(systemName: "lock.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text("Bạn không có quyền xem báo cáo tài chính")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showCustomPicker) {
                                NavigationStack {
                                    Form {
                                        Section(header: Text("Chọn khoảng thời gian")) {
                                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                                        }
                                    }
                                    .navigationTitle("Tuỳ chọn ngày")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .confirmationAction) {
                                            Button("Xong") { showCustomPicker = false }
                                                .fontWeight(.bold)
                                        }
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Huỷ") {
                                                quickRange = .today
                                                showCustomPicker = false
                                            }
                                        }
                                    }
                                }
                                .presentationDetents([.medium])
                            }

                            // Orders List for selected range
                            if StoreManager.shared.hasPermission(.viewOrders) {
                                let rangeOrders = viewModel.orders(for: activeRange)
                                if !rangeOrders.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Đơn hàng")
                                                .font(.headline)
                                                .foregroundStyle(Color.themeTextDark)
                                            Spacer()
                                            Text("\(rangeOrders.count) đơn")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        .padding(.horizontal)

                                        ForEach(rangeOrders.prefix(10)) { bill in
                                            OrderRow(bill: bill)
                                                .padding(.horizontal)
                                        }
                                        if rangeOrders.count > 10 {
                                            Button {
                                                selectedTab = 1
                                            } label: {
                                                Text("Xem tất cả \(rangeOrders.count) đơn →")
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.themePrimary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(Color.themePrimary.opacity(0.07))
                                                    .cornerRadius(10)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            
                            // Quick Actions
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tác vụ nhanh")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    // Always allow creating orders (selling)
                                    QuickActionButton(icon: "cart.badge.plus", title: "Tạo đơn", isPrimary: true) {
                                        showNewOrder = true
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.manageEmployees) || StoreManager.shared.currentMember?.role == .owner {
                                        QuickActionButton(icon: "gearshape", title: "Cài Đặt", isPrimary: false) {
                                            selectedTab = 6
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.viewReports) {
                                        QuickActionButton(icon: "chart.bar", title: "Thống Kê", isPrimary: false) {
                                            selectedTab = 7
                                        }
                                    }
                                    
                                    if productionEnabledGlobal && StoreManager.shared.hasPermission(.manageProduction) {
                                        QuickActionButton(icon: "gearshape.2.fill", title: "Quản lý SX", isPrimary: false) {
                                            showProductionManagement = true
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.viewExpenses) {
                                        QuickActionButton(icon: "banknote.fill", title: "Chi phí", isPrimary: false) {
                                            selectedTab = 4
                                        }
                                    }
                                    
                                    if productionEnabledGlobal && StoreManager.shared.hasPermission(.viewProduction) {
                                        QuickActionButton(icon: "doc.text.magnifyingglass", title: "Báo cáo SX", isPrimary: false) {
                                            selectedTab = 8
                                            showProductionReport = true
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.manageCustomers) {
                                        QuickActionButton(icon: "person.2.fill", title: "Khách hàng", isPrimary: false) {
                                            showCustomerManagement = true
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.viewInventory) {
                                        QuickActionButton(icon: "cube.box.fill", title: "Báo cáo kho", isPrimary: false) {
                                            selectedTab = 3
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.manageEmployees) {
                                        QuickActionButton(icon: "calendar.badge.checkmark", title: "Điểm danh", isPrimary: false) {
                                            showAttendance = true
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                Button {
                                    showGuide = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.title3)
                                        Text("Hướng dẫn sử dụng & Tính năng")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .navigationTitle("Trang chủ")
                        .navigationBarHidden(true)
                        .task {
                            if productionEnabledGlobal && allProductionTx.isEmpty {
                                allProductionTx = await viewModel.fetchProductionTransactions(mode: "Xuất Thành Phẩm")
                                    + (await viewModel.fetchProductionTransactions(mode: "Nhập Nguyên liệu"))
                            }
                            // Setup realtime hooks + initial refresh
                            notifService.setup(viewModel: viewModel)
                            await notifService.refresh(viewModel: viewModel)
                        }
                        .onChange(of: activeRange) { _ in
                            if productionEnabledGlobal {
                                Task {
                                    allProductionTx = await viewModel.fetchProductionTransactions(mode: "Xuất Thành Phẩm")
                                        + (await viewModel.fetchProductionTransactions(mode: "Nhập Nguyên liệu"))
                                }
                            }
                        }
                        .sheet(isPresented: $showNotificationCenter) {
                            NotificationCenterSheet(
                                service: notifService,
                                onSelectTab: { tab in selectedTab = tab },
                                onOpenCustomerManagement: { showCustomerManagement = true },
                                onOpenProductionManagement: { showProductionManagement = true },
                                onOpenLeaveApproval: { showLeaveApprovalFromNotif = true }
                            )
                        }
                        .sheet(isPresented: $showLeaveApprovalFromNotif) {
                            LeaveApprovalView()
                        }
                        .sheet(isPresented: $showAttendance) {
                            AttendanceView()
                        }
                        .sheet(isPresented: $showGuide) {
                            GuideView(isPresented: $showGuide)
                        }
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                    .background(Color.themeBackgroundLight)
                    
                    if viewModel.showOrderSuccessToast {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                            Text("Đã trừ kho và lưu đơn hàng")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .padding(.top, 60) // Below header
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                    }
                }
            }
        }
        func currentDateString() -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "EEEE, d MMM"
            return formatter.string(from: Date())
        }
        
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
        
        
    }
    
    
    // MARK: - Smart Order Entry (Moved to separate file if possible, but kept here for now)
    // IMPORTANT: This struct must be outside ContentView to be accessible elsewhere
    
    
    struct SmartOrderEntryView: View {
        @ObservedObject var viewModel: OrderViewModel
        @Environment(\.dismiss) var dismiss
        @State private var showSummary = false
        @State private var showManualInput = false
        @State private var editingItem: OrderItem?
        @State private var customizingProduct: Product?
        @State private var showStockWarning = false
        @State private var stockWarnings: [String] = []
        @State private var showSearch = false
        @State private var showBarcodeScanner = false
        @State private var foundExternalProduct: ExternalProductInfo?
        @State private var showExternalProductAlert = false
        @State private var isLookingUpBarcode = false
        @Namespace private var namespace
        @FocusState private var walkInFocused: Bool
        @State private var keyboardHeight: CGFloat = 0
        @State private var priceEditItem: OrderItem?
        @State private var priceInput: String = ""
        @State private var priceWheelSelection: Int = 0
        @State private var priceMillionsSelection: Int = 0
        @State private var priceMillionsRangeBase: Int = 0
        @State private var showPriceMillionsRangePicker: Bool = false
        @State private var priceThousandsSelection: Int = 0
        @State private var priceThousandsRangeBase: Int = 0
        @State private var showPriceThousandsRangePicker: Bool = false
        @State private var priceHundredsSelection: Int = 0
        @State private var priceHundredsRangeBase: Int = 0
        @State private var showPriceHundredsRangePicker: Bool = false
        @State private var wheelItem: OrderItem?
        @State private var wheelSelection: Int = 1
        @State private var wheelMax: Int = 100
        @State private var nameWheelItem: OrderItem?
        @State private var nameWheelSelectionIndex: Int = 0
        @State private var showCustomerPicker = false
        @State private var customerSortMode: Int = 0
        @State private var customerSearch: String = ""
        @State private var isKeyboardVisible: Bool = false
        @State private var showWalkInCustomerSheet = false
        
        @ViewBuilder
        private func orderItemView(_ item: OrderItem) -> some View {
            HStack(spacing: 12) {
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                } else {
                    Image(systemName: item.systemImage ?? "cart.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.themePrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.themePrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                        .onTapGesture {
                            if let idx = viewModel.products.firstIndex(where: { $0.name == item.name }) {
                                nameWheelSelectionIndex = idx
                            } else {
                                nameWheelSelectionIndex = 0
                            }
                            nameWheelItem = item
                        }
                    
                    HStack(spacing: 8) {
                        Text(formatCurrency(item.price))
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .onTapGesture {
                                priceWheelSelection = max(0, Int(item.price))
                                priceEditItem = item
                            }
                        if item.discount > 0 {
                            Text("-\(Int(item.discount/1000))k")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatCurrency(item.total))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                    
                    HStack(spacing: 18) {
                        Button {
                            viewModel.updateItem(item, newQuantity: item.quantity - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.gray)
                        }
                        
                        Text("\(item.quantity)")
                            .font(.title2)
                            .frame(minWidth: 36)
                            .padding(.horizontal, 6)
                            .onTapGesture {
                                wheelItem = item
                                wheelSelection = item.quantity
                                wheelMax = item.quantity + 1000
                            }
                        
                        Button {
                            viewModel.updateItem(item, newQuantity: item.quantity + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Button {
                            viewModel.removeItem(item)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .id(item.id)
            .onTapGesture {
                editingItem = item
            }
        }
        
        @ViewBuilder
        var searchBarView: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)
                TextField("Tìm kiếm sản phẩm...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
                Button(action: { showBarcodeScanner = true }) {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(.gray)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        
        var searchContentViewOrder: some View {
            Group {
                if viewModel.searchSuggestions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("Không tìm thấy sản phẩm nào")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("\"\(viewModel.searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button("Xóa tìm kiếm") {
                            viewModel.searchText = ""
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                } else {
                    List {
                        ForEach(viewModel.searchSuggestions) { product in
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                viewModel.addProduct(product)
                                viewModel.searchText = ""
                            }) {
                                HStack(spacing: 12) {
                                    if let data = product.imageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 20, height: 20)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: product.imageName)
                                            .font(.headline)
                                            .foregroundStyle(Color.themePrimary)
                                            .frame(width: 20, height: 20)
                                            .background(Color.themePrimary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(product.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                            if product.hasVAT {
                                                Text("VAT")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.85))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(product.category)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(formatCurrency(product.price))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.themePrimary)
                                        
                                        let stock = viewModel.stockLevel(for: product.name)
                                        Text("Kho: \(stock)")
                                            .font(.caption)
                                            .foregroundStyle(stock > 0 ? .gray : .red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.white)
                    .padding(.bottom, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        
        @State private var orderCategory: String = "Tất cả"
        @State private var orderGridColumns: Int = 6
        
        var browsingContentViewOrder: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            let availableCatNames = Array(Set(viewModel.products.filter { !$0.isFinishedGood }.map { $0.category })).sorted()
                            let chips = ["Tất cả"] + availableCatNames
                            ForEach(chips, id: \.self) { cat in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        orderCategory = cat
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }) {
                                    Text(cat)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            ZStack {
                                                if orderCategory == cat {
                                                    Capsule()
                                                        .fill(Color.themePrimary)
                                                        .matchedGeometryEffect(id: "catPill", in: namespace)
                                                        .shadow(color: Color.themePrimary.opacity(0.3), radius: 4, x: 0, y: 2)
                                                } else {
                                                    Capsule()
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                }
                                            }
                                        )
                                        .foregroundStyle(orderCategory == cat ? Color.themeTextDark : Color.gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    // Grid column toggle
                    HStack(spacing: 0) {
                        ForEach([3, 4, 6], id: \.self) { n in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    orderGridColumns = n
                                }
                            } label: {
                                Image(systemName: n == 3 ? "square.grid.3x2" : n == 4 ? "square.grid.4x3.fill" : "rectangle.grid.3x2")
                                    .font(.system(size: 15))
                                    .foregroundStyle(orderGridColumns == n ? Color.themePrimary : Color.gray.opacity(0.5))
                                    .frame(width: 34, height: 34)
                                    .background(orderGridColumns == n ? Color.themePrimary.opacity(0.12) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
                .background(Color.white)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: orderGridColumns), spacing: 16) {
                        let productsToShow = viewModel.products.filter { p in
                            guard !p.isFinishedGood else { return false }
                            if orderCategory == "Tất cả" { return true }
                            return p.category.lowercased() == orderCategory.lowercased()
                        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        ForEach(productsToShow) { product in
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                viewModel.addProduct(product)
                            }) {
                                ProductCard(product: product, stockLevel: viewModel.stockLevel(for: product.name))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .simultaneousGesture(
                                LongPressGesture()
                                    .onEnded { _ in
                                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                                        generator.impactOccurred()
                                        customizingProduct = product
                                    }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .background(Color.themeBackgroundLight)
            }
        }
        
        var voiceOverlayViewOrder: some View {
            Group {
                if (viewModel.speechRecognizer.isRecording && !viewModel.isRecordingCustomerName) || !viewModel.currentInput.isEmpty {
                    VStack {
                        if viewModel.currentInput.isEmpty {
                            VStack(spacing: 6) {
                                Text("Đang chờ nói...")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                HStack(spacing: 4) {
                                    Text("Ví dụ:")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.85))
                                    Text("Bán 3 hoa cúc 50k")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.themePrimary, Color.green.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                            )
                            .padding(.horizontal, 40)
                        } else {
                            Text(viewModel.currentInput)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.themePrimary, Color.green.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                                )
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.bottom, 40)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.currentInput)
                    .zIndex(1)
                }
            }
        }
        
        var orderSummarySheetViewOrder: some View {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.vertical, 10)
                
                VStack(spacing: 16) {
                    HStack {
                        HStack(spacing: 12) {
                            Text("Tóm tắt đơn hàng")
                                .font(.headline)
                            
                            Text("\(viewModel.items.reduce(0) { $0 + $1.quantity })")
                                .font(.headline)
                                .frame(width: 32, height: 32)
                                .background(Color.themePrimary.opacity(0.2))
                                .foregroundStyle(Color.themePrimary)
                                .cornerRadius(8)
                        }
                        Spacer()
                        Text(formatCurrency(viewModel.totalAmount))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                            TextField("Tên khách lẻ", text: $viewModel.walkInName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .focused($walkInFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    walkInFocused = false
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            Spacer()
                            Button {
                                showWalkInCustomerSheet = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.themePrimary.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "pencil")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(12)
                        
                        Button {
                            showCustomerPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text("Chọn tên")
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        VoiceAIButton(viewModel: viewModel)
                    }
                    
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.items) { item in
                                orderItemView(item)
                            }
                            
                            Button(action: { showManualInput = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("Thêm hàng")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.themePrimary.opacity(0.2))
                                .foregroundStyle(Color.themePrimary)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(height: 160)
                    .onChange(of: viewModel.items.count) { _ in
                        if let id = viewModel.lastFocusedItemId ?? viewModel.items.last?.id {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.lastFocusedItemId) { newId in
                        if let id = newId {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    }
                    
                    Button(action: {
                        if viewModel.editingBill != nil {
                            viewModel.showPayment = true
                        } else {
                            let warnings = viewModel.checkStockWarnings()
                            if !warnings.isEmpty {
                                stockWarnings = warnings
                                showStockWarning = true
                            } else {
                                viewModel.showPayment = true
                            }
                        }
                    }) {
                        HStack {
                            Text(viewModel.editingBill != nil ? "Sửa thanh toán" : "Thanh toán")
                            Image(systemName: viewModel.editingBill != nil ? "pencil" : "arrow.right")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePrimary)
                        .foregroundStyle(Color.themeTextDark)
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.items.isEmpty)
                    .opacity(viewModel.items.isEmpty ? 0.6 : 1)
                }
                .padding(.horizontal)
                .padding(.bottom, 30 + (walkInFocused ? keyboardHeight : 0))
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: {
                                if viewModel.editingBill != nil {
                                    viewModel.cancelEditing()
                                }
                                viewModel.cancelVoiceProcessing()
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.themeTextDark)
                            }
                            Spacer()
                            Text(viewModel.editingBill != nil ? "Sửa đơn hàng" : "Tạo đơn mới")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                            Spacer()
                            Button(action: {
                            withAnimation { showSearch.toggle() }
                            if !showSearch {
                                viewModel.searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }) {
                            Image(systemName: showSearch ? "chevron.up" : "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.themeTextDark)
                        }
                        
                        // Barcode Scan Button
                        Button(action: { showBarcodeScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                    .padding()
                        
                        if showSearch {
                            searchBarView
                        }
                    }
                    .background(Color.white)
                    
                    if !viewModel.searchText.isEmpty {
                        searchContentViewOrder
                    } else {
                        browsingContentViewOrder
                    }
                    
                    orderSummarySheetViewOrder
                }
            .overlay(
                voiceOverlayViewOrder
            )
            .overlay(
                Group {
                    if walkInFocused {
                        Color.clear
                            .ignoresSafeArea(.all)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                walkInFocused = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    }
                }
            )
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationTitle("Tạo đơn hàng")
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showPayment) {
                PaymentView(viewModel: viewModel)
            }
            .alert("Cảnh báo tồn kho", isPresented: $showStockWarning) {
                Button("Tiếp tục", role: .destructive) {
                    viewModel.showPayment = true
                }
                Button("Hủy", role: .cancel) { }
            } message: {
                Text(stockWarnings.joined(separator: "\n"))
            }
            .navigationTitle(viewModel.editingBill != nil ? "Sửa đơn hàng" : "Tạo đơn mới")
            .navigationBarHidden(true)
            .sheet(isPresented: $showManualInput) {
                ManualItemView(viewModel: viewModel)
            }
            .sheet(item: $editingItem) { item in
                ItemEditView(item: item, viewModel: viewModel)
            }
            .sheet(item: $customizingProduct) { product in
                ProductCustomizeView(product: product, viewModel: viewModel)
            }
            .sheet(item: $priceEditItem) { item in
                VStack(spacing: 12) {
                    Text("Sửa giá").font(.headline)
                    Text(formatCurrency(Double(priceWheelSelection)))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                    HStack(alignment: .top) {
                        VStack(spacing: 2) {
                            Button { showPriceMillionsRangePicker = true } label: {
                                Text(priceMillionsRangeBase <= 0 ? ">0" : ">\(priceMillionsRangeBase)tr")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Triệu").font(.caption).foregroundStyle(.gray)
                            let millionsMin = priceMillionsRangeBase
                            let millionsMax = max(millionsMin, millionsMin + 500)
                            let millionsRange = Array(millionsMin...millionsMax)
                            Picker("", selection: $priceMillionsSelection) {
                                ForEach(millionsRange, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceMillionsSelection) { v in
                                priceWheelSelection = v * 1_000_000 + priceThousandsSelection * 1_000 + priceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showPriceThousandsRangePicker = true } label: {
                                Text(priceThousandsRangeBase <= 0 ? ">0" : ">\(priceThousandsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Ngàn").font(.caption).foregroundStyle(.gray)
                            let thousandsMin = priceThousandsRangeBase
                            let thousandsMax = min(thousandsMin + 99, 999)
                            let thousandsRange = Array(stride(from: thousandsMin, through: thousandsMax, by: 1))
                            Picker("", selection: $priceThousandsSelection) {
                                ForEach(thousandsRange, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceThousandsSelection) { v in
                                priceWheelSelection = priceMillionsSelection * 1_000_000 + v * 1_000 + priceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showPriceHundredsRangePicker = true } label: {
                                Text(priceHundredsRangeBase <= 0 ? ">0" : "\(priceHundredsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Trăm").font(.caption).foregroundStyle(.gray)
                            let hundredsMin = priceHundredsRangeBase
                            let hundredsMax = min(hundredsMin + 99, 999)
                            let hundredsRange = Array(stride(from: hundredsMin, through: hundredsMax, by: 1))
                            Picker("", selection: $priceHundredsSelection) {
                                ForEach(hundredsRange, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceHundredsSelection) { v in
                                priceWheelSelection = priceMillionsSelection * 1_000_000 + priceThousandsSelection * 1_000 + v
                            }
                        }
                    }
                    HStack {
                        Button("Đóng") { priceEditItem = nil }
                        Spacer()
                        Button("Lưu") {
                            viewModel.updateItemFull(item, name: item.name, price: Double(priceWheelSelection), quantity: item.quantity, discount: item.discount, imageData: item.imageData)
                            priceEditItem = nil
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(340)])
                .onAppear {
                    let current = max(0, priceWheelSelection)
                    priceMillionsSelection = current / 1_000_000
                    priceMillionsRangeBase = (priceMillionsSelection / 10) * 10
                    let rem1 = current % 1_000_000
                    priceThousandsSelection = rem1 / 1_000
                    priceThousandsRangeBase = (priceThousandsSelection / 100) * 100
                    let rem2 = rem1 % 1_000
                    priceHundredsRangeBase = (rem2 / 100) * 100
                    priceHundredsSelection = (rem2 / 10) * 10
                }
                .sheet(isPresented: $showPriceMillionsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng triệu").font(.headline)
                        Picker("", selection: $priceMillionsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceMillionsSelection < priceMillionsRangeBase { priceMillionsSelection = priceMillionsRangeBase }
                            showPriceMillionsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showPriceThousandsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng ngàn").font(.headline)
                        Picker("", selection: $priceThousandsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceThousandsSelection < priceThousandsRangeBase || priceThousandsSelection > priceThousandsRangeBase + 99 { priceThousandsSelection = priceThousandsRangeBase }
                            showPriceThousandsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showPriceHundredsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng trăm").font(.headline)
                        Picker("", selection: $priceHundredsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceHundredsSelection < priceHundredsRangeBase || priceHundredsSelection > priceHundredsRangeBase + 99 { priceHundredsSelection = priceHundredsRangeBase }
                            showPriceHundredsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
            }
            .sheet(item: $nameWheelItem) { item in
                NavigationStack {
                    Form {
                        Section {
                            Picker("Tên hàng", selection: $nameWheelSelectionIndex) {
                                ForEach(Array(viewModel.products.enumerated()), id: \.offset) { (i, p) in
                                    Text(p.name).tag(i)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    .navigationTitle("Sửa tên hàng")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { nameWheelItem = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                let products = viewModel.products
                                if products.indices.contains(nameWheelSelectionIndex) {
                                    let selected = products[nameWheelSelectionIndex]
                                    viewModel.updateItemFull(item, name: selected.name, price: selected.price, quantity: item.quantity, discount: item.discount, imageData: selected.imageData)
                                    nameWheelItem = nil
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .sheet(item: $wheelItem) { item in
                NavigationStack {
                    Form {
                        Section {
                            Picker("Số lượng", selection: $wheelSelection) {
                                ForEach(Array(1...wheelMax), id: \.self) { q in
                                    Text("\(q)").tag(q)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: wheelSelection) { q in
                                if q > wheelMax - 10 {
                                    wheelMax += 500
                                }
                            }
                        }
                    }
                    .navigationTitle("Sửa số lượng")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { wheelItem = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                viewModel.updateItem(item, newQuantity: wheelSelection)
                                wheelItem = nil
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .onAppear {
                if viewModel.editingBill == nil {
                    viewModel.walkInName = "Khách lẻ"
                    viewModel.walkInPhone = ""
                    viewModel.walkInAddress = ""
                    viewModel.walkInEmail = ""
                }
            }
            .onChange(of: viewModel.currentInput) { newValue in
                if !newValue.isEmpty && !viewModel.speechRecognizer.isRecording {
                    viewModel.processInput()
                }
            }
            .onDisappear {
                viewModel.cancelVoiceProcessing()
            }
            .onChange(of: viewModel.walkInName) { newName in
                if newName == "Khách lẻ" {
                    walkInFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(onScan: { code in
                    showBarcodeScanner = false
                    
                    // Find product by barcode
                    if let product = viewModel.products.first(where: { $0.barcode == code }) {
                        // Play sound or haptic
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Add to cart directly
                        viewModel.addProduct(product)
                    } else {
                        // Not found locally -> Lookup External
                        isLookingUpBarcode = true
                        Task {
                            // Timeout Task (10 seconds)
                            let timeoutTask = Task {
                                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                                await MainActor.run {
                                    if isLookingUpBarcode {
                                        isLookingUpBarcode = false
                                        viewModel.searchText = code
                                        showSearch = true // Show search bar so user can clear it
                                        // Timeout occurred - unblock UI
                                    }
                                }
                            }
                            
                            if let externalInfo = try? await BarcodeLookupService.shared.lookup(barcode: code) {
                                timeoutTask.cancel()
                                await MainActor.run {
                                    isLookingUpBarcode = false
                                    foundExternalProduct = externalInfo
                                    showExternalProductAlert = true
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }
                            } else {
                                timeoutTask.cancel()
                                await MainActor.run {
                                    isLookingUpBarcode = false
                                    viewModel.searchText = code
                                    showSearch = true // Show search bar so user can clear it
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                }
                            }
                        }
                    }
                })
            }
            .overlay {
                if isLookingUpBarcode {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Đang tra cứu sản phẩm...")
                                .foregroundStyle(.white)
                                .font(.headline)
                        }
                    }
                }
            }
            .sheet(item: $foundExternalProduct) { info in
                ExternalProductAddView(info: info, viewModel: viewModel)
            }
            .sheet(isPresented: $showCustomerPicker) {
                NavigationStack {
                    VStack {
                        Picker("Sắp xếp", selection: $customerSortMode) {
                            Text("Gần đây").tag(0)
                            Text("Mua nhiều").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                            TextField("Tìm tên khách", text: $customerSearch)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        List(filteredCustomerStats()) { stat in
                            Button {
                                viewModel.walkInName = stat.name
                                // Lookup phone/address từ bill gần nhất hoặc TradingParty
                                let recentBill = viewModel.pastOrders
                                    .filter { ($0.customerName ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == stat.name }
                                    .sorted { $0.createdAt > $1.createdAt }
                                    .first
                                if let phone = recentBill?.customerPhone, !phone.isEmpty {
                                    viewModel.walkInPhone = phone
                                }
                                if let address = recentBill?.customerAddress, !address.isEmpty {
                                    viewModel.walkInAddress = address
                                }
                                if let email = recentBill?.customerEmail, !email.isEmpty {
                                    viewModel.walkInEmail = email
                                }
                                // Fallback: fetch từ TradingParty nếu bill không có
                                Task {
                                    let db = SupabaseDatabaseService()
                                    if let party = try? await db.fetchTradingPartyByName(stat.name, type: "buyer") {
                                        await MainActor.run {
                                            if viewModel.walkInPhone.isEmpty && !party.phone.isEmpty {
                                                viewModel.walkInPhone = party.phone
                                            }
                                            if viewModel.walkInAddress.isEmpty && !party.address.isEmpty {
                                                viewModel.walkInAddress = party.address
                                            }
                                            if viewModel.walkInEmail.isEmpty && !party.email.isEmpty {
                                                viewModel.walkInEmail = party.email
                                            }
                                        }
                                    }
                                }
                                showCustomerPicker = false
                            } label: {
                                HStack {
                                    Text(stat.name)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Đã mua: \(stat.count)x")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text("Gần nhất: \(formatShortDate(stat.lastDate))")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .navigationTitle("Chọn tên khách")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCustomerPicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showWalkInCustomerSheet) {
                WalkInCustomerEditSheet(
                    name: $viewModel.walkInName,
                    phone: $viewModel.walkInPhone,
                    address: $viewModel.walkInAddress,
                    email: $viewModel.walkInEmail
                )
            }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { output in
                    if let value = output.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                        keyboardHeight = value.cgRectValue.height
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardHeight = 0
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissOrderEntry"))) { _ in
                    dismiss()
                }
        }
    }
    
    // Helpers for SmartOrderEntryView (customer picker)
    extension SmartOrderEntryView {
        struct CustomerStat: Identifiable {
            let id = UUID()
            let name: String
            let count: Int
            let lastDate: Date
        }
        
        func buildCustomerStats() -> [CustomerStat] {
            var stats: [String: (count: Int, last: Date)] = [:]
            for bill in viewModel.pastOrders {
                guard let name = bill.customerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
                let entry = stats[name] ?? (0, Date(timeIntervalSince1970: 0))
                let newCount = entry.count + 1
                let newLast = max(entry.last, bill.createdAt)
                stats[name] = (newCount, newLast)
            }
            return stats.map { CustomerStat(name: $0.key, count: $0.value.count, lastDate: $0.value.last) }
        }
        
        func filteredCustomerStats() -> [CustomerStat] {
            let all = buildCustomerStats()
            let filtered: [CustomerStat]
            if customerSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filtered = all
            } else {
                let q = customerSearch.lowercased()
                filtered = all.filter { $0.name.lowercased().contains(q) }
            }
            if customerSortMode == 1 {
                return filtered.sorted { lhs, rhs in
                    if lhs.count == rhs.count { return lhs.lastDate > rhs.lastDate }
                    return lhs.count > rhs.count
                }
            } else {
                return filtered.sorted { $0.lastDate > $1.lastDate }
            }
        }
        
        func formatShortDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
    }
    
    struct WalkInCustomerEditSheet: View {
        @Binding var name: String
        @Binding var phone: String
        @Binding var address: String
        @Binding var email: String
        @Environment(\.dismiss) var dismiss
        @State private var showCustomerHistory = false
        @State private var isSaving = false
        @State private var savedToast = false
        
        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Thông tin khách hàng")) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                                .frame(width: 22)
                            TextField("Tên", text: $name)
                                .textInputAutocapitalization(.words)
                        }
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.gray)
                                .frame(width: 22)
                            TextField("Số điện thoại", text: $phone)
                                .keyboardType(.phonePad)
                        }
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.gray)
                                .frame(width: 22)
                            TextField("Địa chỉ", text: $address)
                        }
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.gray)
                                .frame(width: 22)
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                    }
                }
                .navigationTitle("Thông tin khách hàng")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showCustomerHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.blue)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveAndDismiss()
                        } label: {
                            if isSaving {
                                ProgressView().frame(width: 44)
                            } else {
                                Text("Xong")
                            }
                        }
                        .disabled(isSaving)
                    }
                }
                .sheet(isPresented: $showCustomerHistory) {
                    CustomerHistoryListView(
                        onSelectCustomer: { customer in
                            name = customer.name
                            phone = customer.phone
                            address = customer.address
                            email = customer.email
                            showCustomerHistory = false
                        }
                    )
                }
            }
        }
        
        private func saveAndDismiss() {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            // Chỉ lưu nếu có tên thực (không phải "Khách lẻ") hoặc có số điện thoại
            let shouldSave = (!trimmedName.isEmpty && trimmedName.lowercased() != "khách lẻ") || !trimmedPhone.isEmpty
            guard shouldSave else {
                dismiss()
                return
            }
            isSaving = true
            let db = SupabaseDatabaseService()
            let capturedName = trimmedName.isEmpty ? "Khách lẻ" : trimmedName
            let capturedPhone = trimmedPhone
            let capturedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            let capturedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                do {
                    // Tìm bản ghi hiện có (theo tên hoặc SĐT) để tránh tạo trùng
                    let existing = try? await db.fetchTradingPartyByNameOrPhone(capturedName, capturedPhone, "buyer")
                    var party = existing ?? TradingParty(
                        id: UUID(),
                        partyType: "buyer",
                        name: capturedName,
                        phone: capturedPhone,
                        address: capturedAddress,
                        totalDebt: 0
                    )
                    // Cập nhật các trường mới nhất
                    party.name = capturedName
                    if !capturedPhone.isEmpty { party.phone = capturedPhone }
                    if !capturedAddress.isEmpty { party.address = capturedAddress }
                    if !capturedEmail.isEmpty { party.email = capturedEmail }
                    party.updatedAt = Date()
                    try await db.upsertTradingParty(party)
                } catch {
                    print("⚠️ Could not save customer to trading_parties: \(error)")
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        }
    }
    
    struct CustomerHistoryListView: View {
        let onSelectCustomer: (TradingParty) -> Void
        @Environment(\.dismiss) var dismiss
        @State private var customers: [TradingParty] = []
        @State private var isLoading = true
        @State private var searchText: String = ""
        
        private var filteredCustomers: [TradingParty] {
            if searchText.isEmpty {
                return customers
            } else {
                return customers.filter { customer in
                    customer.name.lowercased().contains(searchText.lowercased()) ||
                    customer.phone.lowercased().contains(searchText.lowercased())
                }
            }
        }
        
        var body: some View {
            NavigationStack {
                VStack {
                    if isLoading {
                        ProgressView("Đang tải...")
                            .padding()
                    } else if filteredCustomers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray.opacity(0.4))
                            Text("Chưa có khách hàng nào")
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 60)
                    } else {
                        List(filteredCustomers) { customer in
                            Button(action: { onSelectCustomer(customer) }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.teal.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.teal)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(customer.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.themeTextDark)
                                        
                                        if !customer.phone.isEmpty {
                                            Text(customer.phone)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white)
                        }
                        .listStyle(.plain)
                        .searchable(text: $searchText, prompt: "Tìm tên hoặc số điện thoại...")
                    }
                }
                .navigationTitle("Chọn khách hàng")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { dismiss() }
                    }
                }
                .background(Color.themeBackgroundLight)
                .task { await loadCustomers() }
            }
        }
        
        private func loadCustomers() async {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let db = SupabaseDatabaseService()
                let allParties = try await db.fetchTradingParties(type: "buyer")
                await MainActor.run { customers = allParties }
            } catch {
                print("❌ Failed to load customers: \(error)")
            }
        }
    }
    
    struct ProductCustomizeView: View {
        let product: Product
        @ObservedObject var viewModel: OrderViewModel
        @Environment(\.dismiss) var dismiss
        
        @State private var name: String
        @State private var price: String
        @State private var quantity: String = "1"
        @State private var selectedItem: PhotosPickerItem?
        @State private var selectedImageData: Data?
        
        init(product: Product, viewModel: OrderViewModel) {
            self.product = product
            self.viewModel = viewModel
            _name = State(initialValue: product.name)
            _price = State(initialValue: String(Int(product.price)))
            _selectedImageData = State(initialValue: product.imageData)
        }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Tùy chỉnh")) {
                        TextField("Tên", text: $name)
                        CurrencyTextField(title: "Giá", text: $price)
                        CurrencyTextField(title: "Số lượng", text: $quantity)
                        
                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                            
                            Button("Xóa ảnh", role: .destructive) {
                                selectedImageData = nil
                            }
                        } else {
                            // Show placeholder or current system icon
                            VStack {
                                Image(systemName: product.imageName)
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.themePrimary)
                                Text("Biểu tượng mặc định")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text(selectedImageData == nil ? "Chọn ảnh" : "Đổi ảnh")
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        selectedImageData = data
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Thêm vào đơn")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Thêm") {
                            if let priceVal = Double(price), let qtyVal = Int(quantity), !name.isEmpty {
                                // Add logic
                                viewModel.addItem(name, price: priceVal, quantity: qtyVal, imageData: selectedImageData)
                                dismiss()
                            }
                        }
                        .disabled(name.isEmpty || price.isEmpty || quantity.isEmpty)
                    }
                }
            }
            .presentationDetents([.height(500)])
        }
    }
    
    struct ManualItemView: View {
        @ObservedObject var viewModel: OrderViewModel
        @Environment(\.dismiss) var dismiss
        
        @State private var name: String = ""
        @State private var price: String = ""
        @State private var quantity: String = "1"
        @State private var discount: String = ""
        
        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Chi tiết mặt hàng")) {
                        TextField("Tên mặt hàng", text: $name)
                        CurrencyTextField(title: "Giá", text: $price)
                        CurrencyTextField(title: "Số lượng", text: $quantity)
                        CurrencyTextField(title: "Giảm giá (đ)", text: $discount)
                    }
                }
                .navigationTitle("Thêm thủ công")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Thêm") {
                            if let priceVal = Double(price), let qtyVal = Int(quantity), !name.isEmpty {
                                let discountVal = Double(discount) ?? 0
                                viewModel.addItem(name, price: priceVal, quantity: qtyVal, discount: discountVal)
                                dismiss()
                            }
                        }
                        .disabled(name.isEmpty || price.isEmpty)
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }
    
    struct ItemEditView: View {
        let item: OrderItem
        @ObservedObject var viewModel: OrderViewModel
        @Environment(\.dismiss) var dismiss
        
        @State private var name: String
        @State private var price: String
        @State private var quantity: String
        @State private var discount: String
        @State private var selectedItem: PhotosPickerItem?
        @State private var selectedImageData: Data?
        
        init(item: OrderItem, viewModel: OrderViewModel) {
            self.item = item
            self.viewModel = viewModel
            _name = State(initialValue: item.name)
            _price = State(initialValue: String(Int(item.price)))
            _quantity = State(initialValue: String(item.quantity))
            _discount = State(initialValue: String(Int(item.discount)))
            _selectedImageData = State(initialValue: item.imageData)
        }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Thông tin cơ bản")) {
                        TextField("Tên mặt hàng", text: $name)
                            .font(.headline)
                    }
                    
                    Section(header: Text("Chi tiết giá & Số lượng")) {
                        CurrencyTextField(title: "Đơn giá (đ)", text: $price)
                        CurrencyTextField(title: "Số lượng", text: $quantity)
                        CurrencyTextField(title: "Giảm giá (đ)", text: $discount)
                    }
                    
                    Section(header: Text("Hình ảnh")) {
                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity)
                                
                                Button(action: { selectedImageData = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.red)
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .padding(8)
                            }
                        } else {
                            // Show placeholder or current system icon
                            VStack(spacing: 12) {
                                if let sysImage = item.systemImage {
                                    Image(systemName: sysImage)
                                        .font(.system(size: 60))
                                        .foregroundStyle(Color.themePrimary)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundStyle(Color.gray)
                                }
                                Text("Chưa chọn ảnh")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                // Trigger picker somehow? Need to expose picker trigger
                                // But PhotosPicker is below.
                            }
                        }
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text(selectedImageData == nil ? "Chọn ảnh từ thư viện" : "Thay đổi ảnh")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        selectedImageData = data
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Sửa mặt hàng")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let priceVal = Double(price), let qtyVal = Int(quantity), let discountVal = Double(discount) {
                                viewModel.updateItemFull(item, name: name, price: priceVal, quantity: qtyVal, discount: discountVal, imageData: selectedImageData)
                                dismiss()
                            }
                        }
                        .disabled(name.isEmpty || price.isEmpty || quantity.isEmpty)
                    }
                }
            }
        }
    }
    
    struct ProductCard: View {
        let product: Product
        let stockLevel: Int
        
        var body: some View {
            VStack {
                ZStack(alignment: .topTrailing) {
                    // Placeholder Image / Gradient
                if let data = product.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 90)
                        .cornerRadius(16)
                        .clipped()
                } else if let urlString = product.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .cornerRadius(16)
                                .clipped()
                        } else if phase.error != nil {
                            // Error loading
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorForString(product.color).opacity(0.1))
                                .frame(height: 90)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(30)
                                        .foregroundStyle(colorForString(product.color))
                                )
                        } else {
                            // Loading
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 90)
                                ProgressView()
                            }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorForString(product.color).opacity(0.1))
                        .frame(height: 90)
                        .overlay(
                            Image(systemName: product.imageName)
                                .resizable()
                                .scaledToFit()
                                .padding(30)
                                .foregroundStyle(colorForString(product.color))
                        )
                }
                    
                    Text(formatCurrency(product.price))
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.themePrimary)
                        .foregroundStyle(Color.themeTextDark)
                        .clipShape(Capsule())
                        .padding(8)
                }
                
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(product.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if product.hasVAT {
                            Text("VAT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("Tồn: \(stockLevel)")
                        .font(.caption)
                        .foregroundStyle(stockLevel > 0 ? .gray : .red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    
    
    // Moved extension View and RoundedCorner to file scope
    
    // Helpers (Moved to Components.swift)
    
    
    // Payment View (Preserved and cleaned up)
    struct PaymentView: View {
        @ObservedObject var viewModel: OrderViewModel
        @Environment(\.dismiss) var dismiss
        @State private var renderedImage: UIImage?
        @State private var showShareSheet = false
        @State private var showBankSettings = false
        @State private var showReceiptCamera = false
        @State private var receiptImage: UIImage?
        @State private var isUploadingReceipt = false
        @State private var showDiscountSheet = false
        @State private var showVATRatePicker = false
        @State private var vatRateInputText: String = ""
        @State private var isPrinting = false
        /// Tracks the current isPaid state from BillReceiptView toggle so printAndClose() can read it correctly.
        /// Initialised to false (chưa thanh toán) for new orders; updated via onIsPaidChanged callback.
        @State private var currentIsPaidConfirmed: Bool = false
        
        var body: some View {
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.1), Color.white], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Đóng lại").font(.headline).foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    ScrollView {
                        // Reuse the BillReceiptView for consistency
                        BillReceiptView(
                            items: viewModel.items,
                            totalAmount: viewModel.totalAmount,
                            dateString: currentDateString(),
                            qrURL: viewModel.vietQRURL(),
                            qrImage: nil,
                            billPayload: viewModel.billPayload(),
                            showButtons: true,
                            onComplete: { isPaid in
                                if viewModel.editingBill != nil {
                                    Task {
                                        await viewModel.finalizeEditedPayment()
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            NotificationCenter.default.post(name: NSNotification.Name("DismissOrderEntry"), object: nil)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("NavigateToTab"),
                                                object: nil,
                                                userInfo: ["tab": 1]
                                            )
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                            NotificationCenter.default.post(name: NSNotification.Name("RefreshOrderHistory"), object: nil)
                                        }
                                    }
                                } else {
                                    viewModel.completeOrder(isPaid: isPaid)
                                    dismiss()
                                    // Đóng SmartOrderEntryView rồi chuyển tab Đơn hàng
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        NotificationCenter.default.post(name: NSNotification.Name("DismissOrderEntry"), object: nil)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("NavigateToTab"),
                                            object: nil,
                                            userInfo: ["tab": 1]
                                        )
                                    }
                                }
                            },
                            customerName: viewModel.walkInName,
                            customerPhone: viewModel.walkInPhone,
                            customerAddress: viewModel.walkInAddress,
                            customerEmail: viewModel.walkInEmail,
                            onOpenBankSettings: {
                                showBankSettings = true
                            },
                            onCaptureReceipt: {
                                showReceiptCamera = true
                            },
                            receiptImageURL: viewModel.paymentReceiptImageURL,
                            onPickedReceiptImage: { img in
                                receiptImage = img
                            },
                            onEditDiscount: { showDiscountSheet = true },
                            sequenceNumber: viewModel.editingBill?.sequenceNumber ?? viewModel.currentSequenceNumber,
                            customVATRate: viewModel.vatRate,
                            onEditVAT: {
                                vatRateInputText = String(format: "%.0f", viewModel.vatRate ?? StoreManager.shared.currentStoreVATRate())
                                showVATRatePicker = true
                            },
                            payFullAmount: $viewModel.payFullAmount,
                            partialAmount: $viewModel.partialAmount,
                            expectedPayDate: $viewModel.expectedPayDate,
                            note: $viewModel.note,
                            grandTotal: viewModel.totalAmountWithVAT,
                            initialIsPaid: viewModel.editingBillIsPaid,
                            orderStatus: $viewModel.newOrderStatus,
                            onIsPaidChanged: { confirmed in
                                viewModel.isPaidConfirmedByUser = confirmed
                                currentIsPaidConfirmed = confirmed
                            }
                        )
                        .padding()
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        ActionButton(icon: "trash", title: viewModel.editingBill != nil ? "Hủy sửa" : "Hủy đơn", color: .red) {
                            viewModel.reset()
                            dismiss()
                        }
                        ActionButton(icon: viewModel.editingBill != nil ? "square.and.pencil" : "plus", title: viewModel.editingBill != nil ? "Lưu sửa" : "Tạo đơn mới") {
                            if viewModel.editingBill != nil {
                                Task {
                                    await viewModel.finalizeEditedPayment()
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        NotificationCenter.default.post(name: NSNotification.Name("DismissOrderEntry"), object: nil)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("NavigateToTab"),
                                            object: nil,
                                            userInfo: ["tab": 1]
                                        )
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshOrderHistory"), object: nil)
                                    }
                                }
                            } else {
                                // Dùng trạng thái thanh toán user đã chọn trong BillReceiptView
                                viewModel.completeOrder(isPaid: currentIsPaidConfirmed)
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    NotificationCenter.default.post(name: NSNotification.Name("DismissOrderEntry"), object: nil)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("NavigateToTab"),
                                        object: nil,
                                        userInfo: ["tab": 1]
                                    )
                                }
                            }
                        }
                        ActionButton(icon: "printer.fill", title: "In và đóng bill") {
                            Task { await printAndClose() }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showBankSettings) {
                if let store = StoreManager.shared.currentStore {
                    NavigationStack {
                        StoreBankSettingsView(store: store)
                    }
                } else {
                    Text("Chưa chọn cửa hàng")
                        .padding()
                }
            }
            .fullScreenCover(isPresented: $showReceiptCamera) {
                ImagePicker(image: $receiptImage)
                    .ignoresSafeArea()
            }
            .onChange(of: receiptImage) { img in
                guard let img else { return }
                Task {
                    isUploadingReceipt = true
                    defer { isUploadingReceipt = false }
                    if let data = img.jpegData(compressionQuality: 0.8) {
                        let fileName = StorageManager.shared.generateImageName()
                        do {
                            let url = try await StorageManager.shared.uploadReceiptImage(data: data, fileName: fileName)
                            // Build and upload preview (smaller) for faster viewing in history
                            let target = CGSize(width: 800, height: 800)
                            let down = BillReceiptView.CachedImageLoader.downsample(data: data, to: target, scale: UIScreen.main.scale) ?? img
                            let previewData = down.jpegData(compressionQuality: 0.8) ?? data
                            let previewURL = try await StorageManager.shared.uploadReceiptPreviewImage(data: previewData, fileName: fileName)
                            await MainActor.run {
                                viewModel.paymentReceiptImageURL = url
                            }
                            if let u = URL(string: url) {
                                BillReceiptView.ImageCache.shared.insert(img, for: u)
                            }
                            if let pu = URL(string: previewURL) {
                                BillReceiptView.ImageCache.shared.insert(down, for: pu)
                            }
                            if let bill = viewModel.editingBill {
                                var updated = bill
                                updated.paymentReceiptURL = url
                                try await viewModel.updateOrder(updated)
                            }
                        } catch {
                            print("❌ Error uploading receipt: \(error)")
                        }
                    }
                }
            }
            .onChange(of: viewModel.paymentReceiptImageURL) { urlString in
                guard let urlString, let u = URL(string: urlString) else { return }
                if BillReceiptView.ImageCache.shared.image(for: u) == nil {
                    Task {
                        if let (data, _) = try? await URLSession.shared.data(from: u) {
                            let target = UIScreen.main.bounds.size
                            let img = BillReceiptView.CachedImageLoader.downsample(data: data, to: target, scale: UIScreen.main.scale) ?? UIImage(data: data)
                            if let img {
                                BillReceiptView.ImageCache.shared.insert(img, for: u)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDiscountSheet) {
                DiscountEditorView(viewModel: viewModel, dismiss: { showDiscountSheet = false })
            }
            .sheet(isPresented: $showVATRatePicker) {
                VATRatePickerSheet(
                    rateText: $vatRateInputText,
                    defaultRate: StoreManager.shared.currentStoreVATRate(),
                    onSave: { newRate in viewModel.vatRate = newRate },
                    onReset: { viewModel.vatRate = nil }
                )
            }
            .onAppear {
                // Init currentIsPaidConfirmed: đơn mới = false, đang sửa = trạng thái bill gốc
                currentIsPaidConfirmed = viewModel.editingBill != nil ? viewModel.editingBillIsPaid : false
            }
        }
        
        func currentDateString() -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            return formatter.string(from: Date())
        }
        
        @MainActor
        private func renderImage() {
            Task {
                var loadedQR: UIImage? = nil
                if let url = viewModel.vietQRURL() {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        loadedQR = UIImage(data: data)
                    }
                }
                
                // Create a dedicated view for rendering (cleaner, no buttons)
                let renderView = BillReceiptView(
                    items: viewModel.items,
                    totalAmount: viewModel.totalAmount,
                    dateString: currentDateString(),
                    qrURL: viewModel.vietQRURL(),
                    qrImage: loadedQR,
                    billPayload: viewModel.billPayload(),
                    showButtons: false,
                    onComplete: nil,
                    customerName: viewModel.walkInName,
                    customerPhone: viewModel.walkInPhone,
                    customerAddress: viewModel.walkInAddress,
                    customerEmail: viewModel.walkInEmail,
                    onOpenBankSettings: nil,
                    onCaptureReceipt: nil,
                    receiptImageURL: nil,
                    onPickedReceiptImage: nil,
                    onEditDiscount: nil,
                    sequenceNumber: viewModel.editingBill?.sequenceNumber ?? viewModel.currentSequenceNumber,
                    customVATRate: viewModel.vatRate,
                    payFullAmount: .constant(true),
                    partialAmount: .constant(viewModel.totalAmount),
                    expectedPayDate: .constant(nil),
                    note: .constant(viewModel.note),
                    grandTotal: viewModel.totalAmount
                )
                    .frame(width: 375) // Standard width for image
                
                let renderer = ImageRenderer(content: renderView)
                renderer.scale = UIScreen.main.scale
                
                if let image = renderer.uiImage {
                    renderedImage = image
                    showShareSheet = true
                }
            }
        }

        @MainActor
        private func printAndClose() async {
            isPrinting = true
            defer { isPrinting = false }

            // Render bill thành ảnh
            var loadedQR: UIImage? = nil
            if let url = viewModel.vietQRURL(),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                loadedQR = UIImage(data: data)
            }
            let renderView = BillReceiptView(
                items: viewModel.items,
                totalAmount: viewModel.totalAmount,
                dateString: currentDateString(),
                qrURL: viewModel.vietQRURL(),
                qrImage: loadedQR,
                billPayload: viewModel.billPayload(),
                showButtons: false,
                onComplete: nil,
                customerName: viewModel.walkInName,
                customerPhone: viewModel.walkInPhone,
                customerAddress: viewModel.walkInAddress,
                customerEmail: viewModel.walkInEmail,
                onOpenBankSettings: nil,
                onCaptureReceipt: nil,
                receiptImageURL: nil,
                onPickedReceiptImage: nil,
                onEditDiscount: nil,
                sequenceNumber: viewModel.editingBill?.sequenceNumber ?? viewModel.currentSequenceNumber,
                customVATRate: viewModel.vatRate,
                payFullAmount: .constant(viewModel.payFullAmount),
                partialAmount: .constant(viewModel.partialAmount),
                expectedPayDate: .constant(viewModel.expectedPayDate),
                note: .constant(viewModel.note),
                grandTotal: viewModel.totalAmountWithVAT,
                initialIsPaid: currentIsPaidConfirmed
            )
            .frame(width: 375)
            let renderer = ImageRenderer(content: renderView)
            renderer.scale = UIScreen.main.scale
            guard let image = renderer.uiImage else { return }

            // Lưu bill / sửa bill trước khi mở share sheet
            let isEditing = viewModel.editingBill != nil
            if isEditing {
                await viewModel.finalizeEditedPayment()
            } else {
                viewModel.completeOrder(isPaid: currentIsPaidConfirmed)
            }

            // Mở ShareSheet chia sẻ ảnh (giống BillDetailView)
            renderedImage = image
            showShareSheet = true

            // Điều hướng về tab lịch sử sau khi share sheet mở
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                NotificationCenter.default.post(name: NSNotification.Name("DismissOrderEntry"), object: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToTab"),
                    object: nil,
                    userInfo: ["tab": 1]
                )
            }
            if isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshOrderHistory"), object: nil)
                }
            }
        }
    }
    
    struct DiscountEditorView: View {
        @ObservedObject var viewModel: OrderViewModel
        let dismiss: () -> Void
        
        var body: some View {
            VStack(spacing: 12) {
                Text("Chỉnh giảm giá")
                    .font(.headline)
                Picker("Loại", selection: $viewModel.discountMode) {
                    Text("Phần trăm").tag(OrderViewModel.DiscountMode.percent)
                    Text("Theo giá").tag(OrderViewModel.DiscountMode.finalPrice)
                    Text("Số tiền").tag(OrderViewModel.DiscountMode.amount)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                HStack {
                    VStack {
                        Text("Phần trăm")
                            .font(.caption)
                        Picker("", selection: $viewModel.discountPercent) {
                            ForEach(0...100, id: \.self) { v in
                                Text("\(v)%").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.discountMode != .percent)
                    }
                    .padding(8)
                    .background(viewModel.discountMode == .percent ? Color.themePrimary.opacity(0.08) : Color.gray.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.discountMode == .percent ? Color.themePrimary : Color.gray.opacity(0.2), lineWidth: viewModel.discountMode == .percent ? 2 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if viewModel.discountMode == .percent {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary)
                            } else {
                                Image(systemName: "circle").foregroundStyle(Color.gray.opacity(0.3))
                            }
                        }
                        .padding(6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.discountMode = .percent }
                    VStack {
                        Text("Theo giá")
                            .font(.caption)
                        Picker("", selection: Binding<Int>(
                            get: {
                                let base = Int((viewModel.discountFinalPriceTarget ?? viewModel.totalAmount) / 1000.0)
                                return max(0, base)
                            },
                            set: { thousands in
                                let target = Double(thousands) * 1000.0
                                viewModel.discountFinalPriceTarget = min(max(0, target), viewModel.subtotalAmount)
                            }
                        )) {
                            let maxT = Int(max(0, viewModel.subtotalAmount) / 1000.0)
                            ForEach(0...max(maxT, 0), id: \.self) { v in
                                Text(formatCurrency(Double(v) * 1000.0)).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.discountMode != .finalPrice)
                    }
                    .padding(8)
                    .background(viewModel.discountMode == .finalPrice ? Color.themePrimary.opacity(0.08) : Color.gray.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.discountMode == .finalPrice ? Color.themePrimary : Color.gray.opacity(0.2), lineWidth: viewModel.discountMode == .finalPrice ? 2 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if viewModel.discountMode == .finalPrice {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary)
                            } else {
                                Image(systemName: "circle").foregroundStyle(Color.gray.opacity(0.3))
                            }
                        }
                        .padding(6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.discountMode = .finalPrice }
                    VStack {
                        Text("Số tiền")
                            .font(.caption)
                        Picker("", selection: Binding<Int>(
                            get: {
                                Int(viewModel.discountAmountValue / 1000.0)
                            },
                            set: { thousands in
                                let v = Double(thousands) * 1000.0
                                viewModel.discountAmountValue = min(max(0, v), viewModel.subtotalAmount)
                            }
                        )) {
                            let maxA = Int(max(0, viewModel.subtotalAmount) / 1000.0)
                            ForEach(0...max(maxA, 0), id: \.self) { v in
                                Text(formatCurrency(Double(v) * 1000.0)).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.discountMode != .amount)
                    }
                    .padding(8)
                    .background(viewModel.discountMode == .amount ? Color.themePrimary.opacity(0.08) : Color.gray.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.discountMode == .amount ? Color.themePrimary : Color.gray.opacity(0.2), lineWidth: viewModel.discountMode == .amount ? 2 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if viewModel.discountMode == .amount {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary)
                            } else {
                                Image(systemName: "circle").foregroundStyle(Color.gray.opacity(0.3))
                            }
                        }
                        .padding(6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.discountMode = .amount }
                }
                .frame(height: 180)
                .padding(.horizontal)
                .onChange(of: viewModel.discountFinalPriceTarget) { newTarget in
                    let subtotal = viewModel.subtotalAmount
                    let target = min(max(0, newTarget ?? subtotal), subtotal)
                    let amount = max(0, subtotal - target)
                    if viewModel.discountAmountValue != amount {
                        viewModel.discountAmountValue = amount
                    }
                }
                .onChange(of: viewModel.discountAmountValue) { newAmount in
                    let subtotal = viewModel.subtotalAmount
                    let amount = min(max(0, newAmount), subtotal)
                    let target = max(0, subtotal - amount)
                    if viewModel.discountFinalPriceTarget != target {
                        viewModel.discountFinalPriceTarget = target
                    }
                }
                
                HStack {
                    Button("Giá ban đầu") {
                        viewModel.discountMode = .amount
                        viewModel.discountPercent = 0
                        viewModel.discountAmountValue = 0
                        viewModel.discountFinalPriceTarget = nil
                    }
                    .frame(maxWidth: .infinity)
                    Button("Xong") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
    }
    
    struct BillReceiptView: View {
        let items: [OrderItem]
        let totalAmount: Double
        let dateString: String
        let qrURL: URL?
        let qrImage: UIImage?
        let billPayload: String?
        let showButtons: Bool
        let showPaymentInfo: Bool  // hiển thị payment info khi !showButtons (dùng cho in ảnh)
        let onComplete: ((Bool) -> Void)?
        let customerName: String
        let customerPhone: String?
        let customerAddress: String?
        let customerEmail: String?
        let onOpenBankSettings: (() -> Void)?
        let onCaptureReceipt: (() -> Void)?
        let receiptImageURL: String?
        let onPickedReceiptImage: ((UIImage) -> Void)?
        let onEditDiscount: (() -> Void)?
        let sequenceNumber: String?
        var customVATRate: Double?
        var onEditVAT: (() -> Void)?
        @Binding var payFullAmount: Bool
        @Binding var partialAmount: Double
        @Binding var expectedPayDate: Date?
        @Binding var note: String
        let grandTotal: Double
        var initialIsPaid: Bool = false  // trạng thái isPaid của bill gốc khi sửa
        var onIsPaidChanged: ((Bool) -> Void)? = nil  // callback khi người dùng toggle isPaid
        @Binding var orderStatus: String?
        @State private var receiptPickerItem: PhotosPickerItem?
        @State private var showReceiptPreview = false
        @State private var previewURL: URL?
        @StateObject private var previewLoader = CachedImageLoader()
        @StateObject private var originalLoader = CachedImageLoader()
        @State private var showPartialAmountWheel = false
        @State private var isPaidConfirmed: Bool = false
        @State private var showOrderStatusPicker = false
        // Local copy của payFullAmount để tránh trigger re-render view cha khi toggle
        @State private var localPayFullAmount: Bool = true
        @State private var partialAmountMillionsSelection = 0
        @State private var partialAmountThousandsSelection = 0
        @State private var partialAmountHundredsSelection = 0
        @State private var partialAmountMillionsRangeBase = 0
        @State private var partialAmountThousandsRangeBase = 0
        @State private var partialAmountHundredsRangeBase = 0
        @State private var showPartialAmountMillionsRangePicker = false
        @State private var showPartialAmountThousandsRangePicker = false
        @State private var showPartialAmountHundredsRangePicker = false
        @State private var showDatePicker = false
        @State private var partialAmountSelection = 0
        
        private var partialAmountMillionsRange: ClosedRange<Int> {
            let start = partialAmountMillionsRangeBase
            let end = max(start, start + 500)
            return start...end
        }
        
        private var partialAmountThousandsRange: ClosedRange<Int> {
            let start = partialAmountThousandsRangeBase
            let end = min(start + 999, 999)
            return start...end
        }
        
        private var partialAmountHundredsRange: [Int] {
            let start = partialAmountHundredsRangeBase
            let end = min(start + 999, 999)
            return Array(stride(from: start, through: end, by: 10))
        }
        
        private func formatDateOnly(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        
        init(items: [OrderItem], totalAmount: Double, dateString: String, qrURL: URL?, qrImage: UIImage?, billPayload: String?, showButtons: Bool, showPaymentInfo: Bool = true, onComplete: ((Bool) -> Void)?, customerName: String, customerPhone: String? = nil, customerAddress: String? = nil, customerEmail: String? = nil, onOpenBankSettings: (() -> Void)?, onCaptureReceipt: (() -> Void)?, receiptImageURL: String?, onPickedReceiptImage: ((UIImage) -> Void)?, onEditDiscount: (() -> Void)?, sequenceNumber: String? = nil, customVATRate: Double? = nil, onEditVAT: (() -> Void)? = nil, payFullAmount: Binding<Bool>, partialAmount: Binding<Double>, expectedPayDate: Binding<Date?>, note: Binding<String>, grandTotal: Double, initialIsPaid: Bool = false, orderStatus: Binding<String?> = .constant(nil), onIsPaidChanged: ((Bool) -> Void)? = nil) {
            self.items = items
            self.totalAmount = totalAmount
            self.dateString = dateString
            self.qrURL = qrURL
            self.qrImage = qrImage
            self.billPayload = billPayload
            self.showButtons = showButtons
            self.showPaymentInfo = showPaymentInfo
            self.onComplete = onComplete
            self.customerName = customerName
            self.customerPhone = customerPhone
            self.customerAddress = customerAddress
            self.customerEmail = customerEmail
            self.onOpenBankSettings = onOpenBankSettings
            self.onCaptureReceipt = onCaptureReceipt
            self.receiptImageURL = receiptImageURL
            self.onPickedReceiptImage = onPickedReceiptImage
            self.onEditDiscount = onEditDiscount
            self.sequenceNumber = sequenceNumber
            self.customVATRate = customVATRate
            self.onEditVAT = onEditVAT
            self._payFullAmount = payFullAmount
            self._partialAmount = partialAmount
            self._expectedPayDate = expectedPayDate
            self._note = note
            self.grandTotal = grandTotal
            self.initialIsPaid = initialIsPaid
            self._orderStatus = orderStatus
            self.onIsPaidChanged = onIsPaidChanged
        }
        
        var body: some View {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                        let headerLines = StoreManager.shared.currentStoreReceiptHeaderLines().filter { !$0.isEmpty }
                        if !headerLines.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(headerLines, id: \.self) { line in
                                    Text(line)
                                        .font(.headline)
                                        .foregroundStyle(Color.themeTextDark)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Text(customerName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        
                        if let phone = customerPhone, !phone.isEmpty {
                            Text("SĐT: \(phone)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        if let email = customerEmail, !email.isEmpty {
                            Text("Email: \(email)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    
                    HStack {
                        Text(dateString)
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                        
                        if let stt = sequenceNumber {
                            Spacer()
                            Text("STT: \(stt)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    if let address = customerAddress, !address.isEmpty {
                        Text("Địa chỉ: \(address)")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Ghi chú — hiển thị ngay dưới địa chỉ
                    if showButtons {
                        TextField("Ghi chú...", text: $note, axis: .vertical)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)
                            .padding(.top, 2)
                    } else if !note.isEmpty {
                        Text("Ghi chú: \(note)")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                DottedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 1).foregroundStyle(.gray.opacity(0.3)).padding(.horizontal)
                
                VStack(spacing: 16) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            // Product Image
                            if let data = item.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            } else {
                                Image(systemName: item.systemImage ?? "cart.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.themePrimary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.themePrimary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.themeTextDark)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(item.quantity) x \(formatCurrency(item.price))")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if item.discount > 0 {
                                    Text("-\(formatCurrency(item.discount))")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(item.total))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                
                DottedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 1).foregroundStyle(.gray.opacity(0.3)).padding(.horizontal)
                
                VStack(spacing: 8) {
                    let vatEnabled = StoreManager.shared.currentStoreVATEnabled()
                    let vatRate = customVATRate ?? StoreManager.shared.currentStoreVATRate()
                    let vatAmount = vatEnabled ? (totalAmount * vatRate / 100.0) : 0
                    let subtotal = items.reduce(0) { $0 + $1.total }
                    let discountValue = max(0, subtotal - totalAmount)
                    if vatEnabled {
                        HStack {
                            Text("Tổng tiền hàng")
                                .foregroundStyle(Color.gray)
                            Spacer()
                            Text(formatCurrency(totalAmount))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack {
                            Button {
                                onEditVAT?()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("VAT (\(vatRate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", vatRate) : String(format: "%.1f", vatRate))%)")
                                        .foregroundStyle(Color.gray)
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(customVATRate != nil ? Color.orange : Color.gray.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(onEditVAT == nil)
                            Spacer()
                            Text(formatCurrency(vatAmount))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack {
                        Text("Tổng cộng")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        Spacer()
                        Text(formatCurrency(grandTotal))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if (onEditDiscount != nil) || discountValue > 0 {
                        HStack {
                            Text("Giảm giá")
                                .foregroundStyle(Color.gray)
                            Spacer()
                            Text("-" + formatCurrency(discountValue))
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture {
                                    onEditDiscount?()
                                }
                        }
                    }
                    
                    // Payment Options
                    if showButtons {
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Thanh toán")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                            
                            // Payment Option Buttons
                            HStack(spacing: 12) {
                                Button {
                                    localPayFullAmount = true
                                    payFullAmount = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: localPayFullAmount ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(localPayFullAmount ? Color.themePrimary : .gray)
                                        Text("100%")
                                            .font(.subheadline)
                                            .fontWeight(localPayFullAmount ? .bold : .regular)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(localPayFullAmount ? Color.themePrimary.opacity(0.12) : Color.gray.opacity(0.08)))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    localPayFullAmount = false
                                    payFullAmount = false
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: !localPayFullAmount ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(!localPayFullAmount ? Color.themePrimary : .gray)
                                        Text("Trả một phần")
                                            .font(.subheadline)
                                            .fontWeight(!localPayFullAmount ? .bold : .regular)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(!localPayFullAmount ? Color.themePrimary.opacity(0.12) : Color.gray.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }

                            if !localPayFullAmount {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Số tiền trả:")
                                            .font(.subheadline)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Button {
                                            showPartialAmountWheel = true
                                            let current = max(0, Int(partialAmount))
                                            partialAmountMillionsSelection = current / 1_000_000
                                            partialAmountThousandsSelection = (current % 1_000_000) / 1_000
                                            partialAmountHundredsSelection = (current % 1_000) / 10
                                        } label: {
                                            Text(formatCurrency(partialAmount))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.themePrimary)
                                        }
                                    }
                                    
                                    let debt = max(0, grandTotal - partialAmount)
                                    if debt > 0 {
                                        HStack {
                                            Text("Công nợ:")
                                                .font(.subheadline)
                                                .foregroundStyle(.gray)
                                            Spacer()
                                            Text(formatCurrency(debt))
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.red)
                                        }

                                        // Expected Pay Date
                                        HStack {
                                            Text("Dự kiến trả hết:")
                                                .font(.subheadline)
                                                .foregroundStyle(.gray)
                                            Spacer()
                                            Button {
                                                showDatePicker = true
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Text(expectedPayDate == nil ? "Chưa xác định" : formatDateOnly(expectedPayDate!))
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(expectedPayDate == nil ? .gray : Color.themePrimary)
                                                    Image(systemName: "calendar")
                                                        .font(.caption)
                                                        .foregroundStyle(expectedPayDate == nil ? .gray : Color.themePrimary)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Capsule().fill(Color.gray.opacity(0.1)))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                            }
                        }
                    }
                }
                .padding()
                
                if showButtons {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quét mã thanh toán")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                                let bankName = StoreManager.shared.currentStore?.bankName ?? ""
                                let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber ?? ""
                                if bankName.isEmpty || bankAccount.isEmpty {
                                    Text("Chưa cài đặt ngân hàng")
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.red)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("\(bankName) - \(bankAccount)")
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.themeTextDark)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                            let bankName = StoreManager.shared.currentStore?.bankName ?? ""
                            let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber ?? ""
                            if bankName.isEmpty || bankAccount.isEmpty {
                                if showButtons {
                                    Button {
                                        onOpenBankSettings?()
                                    } label: {
                                        HStack {
                                            Image(systemName: "building.columns")
                                            Text("Cài đặt ngân hàng")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } else {
                                if let image = qrImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                } else if let url = qrURL {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().interpolation(.none).scaledToFit().frame(width: 200, height: 200)
                                        } else {
                                            ProgressView().frame(width: 200, height: 200)
                                        }
                                    }
                                } else if let payload = billPayload {
                                    QRCodeView(payload: payload).frame(width: 200, height: 200)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.gray.opacity(0.3)))
                    }
                    .padding(.horizontal).padding(.bottom)
                } else if showPaymentInfo {
                    // Show payment info when printing
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Thông tin thanh toán")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        
                        HStack {
                            Text("Tổng tiền")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(grandTotal))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Đã trả")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            if !isPaidConfirmed {
                                Text("Chưa thanh toán")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                            } else {
                                Text(formatCurrency(localPayFullAmount ? grandTotal : partialAmount))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        if !localPayFullAmount && (grandTotal - partialAmount) > 0 {
                            HStack {
                                Text("Công nợ")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(grandTotal - partialAmount))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        if let expectedDate = expectedPayDate {
                            HStack {
                                Text("Ngày dự kiến trả")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(formatDateOnly(expectedDate))
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        if !note.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ghi chú")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.themeTextDark)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                    .padding(.horizontal).padding(.bottom)
                }
                
                if showButtons {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chụp hình chuyển khoản")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                                if let url = receiptImageURL, !url.isEmpty {
                                    Text("Đã lưu ảnh xác nhận")
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Chưa có ảnh xác nhận")
                                        .font(.footnote)
                                        .foregroundStyle(.gray)
                                }
                            }
                            Spacer()
                            if let urlString = receiptImageURL,
                               let original = URL(string: urlString) {
                                let preview = URL(string: urlString.replacingOccurrences(of: ".jpg", with: "-preview.jpg")) ?? original
                                Button {
                                    previewURL = preview
                                    showReceiptPreview = true
                                } label: {
                                    ZStack {
                                        if let ui = previewLoader.image ?? originalLoader.image {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onAppear {
                                        previewLoader.load(url: preview, targetSize: CGSize(width: 400, height: 400))
                                        originalLoader.load(url: original, targetSize: CGSize(width: 400, height: 400))
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                ZStack {
                                    Color.gray.opacity(0.08)
                                    Image(systemName: "photo")
                                        .foregroundStyle(Color.gray)
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            Button {
                                onCaptureReceipt?()
                            } label: {
                                Image(systemName: "camera.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .labelStyle(.iconOnly)
                            
                            PhotosPicker(selection: $receiptPickerItem, matching: .images) {
                                Image(systemName: "photo")
                            }
                            .buttonStyle(.bordered)
                            .labelStyle(.iconOnly)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.gray.opacity(0.3)))
                    .padding(.horizontal).padding(.bottom)
                    .onChange(of: receiptPickerItem) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                onPickedReceiptImage?(img)
                                receiptPickerItem = nil
                            }
                        }
                    }
                    .sheet(isPresented: $showReceiptPreview) {
                        NavigationStack {
                            ZStack {
                                Color.black.opacity(0.9).ignoresSafeArea()
                                if let preview = previewURL {
                                    if let ui = previewLoader.image ?? originalLoader.image ?? BillReceiptView.ImageCache.shared.image(for: preview) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        ProgressView()
                                            .tint(.white)
                                            .task {
                                                previewLoader.load(url: preview, targetSize: CGSize(width: 800, height: 800))
                                                if let urlString = receiptImageURL, let original = URL(string: urlString) {
                                                    originalLoader.load(url: original, targetSize: CGSize(width: 800, height: 800))
                                                }
                                            }
                                    }
                                }
                            }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Đóng") { showReceiptPreview = false }
                                }
                            }
                        }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                    .task(id: receiptImageURL) {
                        if let s = receiptImageURL {
                            let previewString = s.replacingOccurrences(of: ".jpg", with: "-preview.jpg")
                            if let pu = URL(string: previewString) {
                                previewLoader.load(url: pu, targetSize: CGSize(width: 800, height: 800))
                            }
                            if let ou = URL(string: s) {
                                originalLoader.load(url: ou, targetSize: CGSize(width: 800, height: 800))
                            }
                        }
                    }
                }
                
                if showButtons {
                    VStack(spacing: 0) {
                        // Trạng thái thanh toán toggle
                        HStack {
                            Text("Trạng thái thanh toán")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                            Spacer()
                            Button(action: {
                                isPaidConfirmed.toggle()
                                onIsPaidChanged?(isPaidConfirmed)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isPaidConfirmed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isPaidConfirmed ? .green : .gray)
                                    Text(isPaidConfirmed ? "Đã thanh toán" : "Chưa thanh toán")
                                        .fontWeight(.medium)
                                        .foregroundStyle(isPaidConfirmed ? .green : .gray)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isPaidConfirmed ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.horizontal)
                        
                        // Trạng thái đơn hàng
                        HStack {
                            Text("Trạng thái đơn hàng")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                            Spacer()
                            Button {
                                showOrderStatusPicker = true
                            } label: {
                                let info = orderStatusDisplayInfo(orderStatus)
                                HStack(spacing: 6) {
                                    Image(systemName: info.icon)
                                        .foregroundStyle(info.color)
                                    Text(info.label)
                                        .fontWeight(.medium)
                                        .foregroundStyle(info.color)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(info.color.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.horizontal)
                        
                        // Nút đóng bill
                        Button(action: {
                            onComplete?(isPaidConfirmed)
                        }) {
                            Text("Lưu & Đóng bill")
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.themePrimary)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                } else {
                    // Static footer for image
                    HStack {
                        Spacer()
                        Text("Cảm ơn quý khách!")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                    .padding(.bottom)
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            // Partial Amount Wheel
            .sheet(isPresented: $showPartialAmountWheel) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("Số tiền trả")
                            .font(.headline)
                        Text(formatCurrency(Double(partialAmountSelection)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        HStack(alignment: .top) {
                            VStack(spacing: 2) {
                                Button { showPartialAmountMillionsRangePicker = true } label: {
                                    Text(partialAmountMillionsRangeBase <= 0 ? ">0" : ">\(partialAmountMillionsRangeBase)tr")
                                        .fontWeight(.bold)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Triệu")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $partialAmountMillionsSelection) {
                                    ForEach(partialAmountMillionsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: partialAmountMillionsSelection) { v in
                                    partialAmountSelection = v * 1_000_000 + partialAmountThousandsSelection * 1_000 + partialAmountHundredsSelection
                                }
                            }
                            VStack(spacing: 2) {
                                Button { showPartialAmountThousandsRangePicker = true } label: {
                                    Text(partialAmountThousandsRangeBase <= 0 ? ">0" : ">\(partialAmountThousandsRangeBase)")
                                        .fontWeight(.bold)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Ngàn")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $partialAmountThousandsSelection) {
                                    ForEach(partialAmountThousandsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: partialAmountThousandsSelection) { v in
                                    partialAmountSelection = partialAmountMillionsSelection * 1_000_000 + v * 1_000 + partialAmountHundredsSelection
                                }
                            }
                            VStack(spacing: 2) {
                                Button { showPartialAmountHundredsRangePicker = true } label: {
                                    Text(partialAmountHundredsRangeBase <= 0 ? ">0" : "\(partialAmountHundredsRangeBase)")
                                        .fontWeight(.bold)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Trăm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $partialAmountHundredsSelection) {
                                    ForEach(partialAmountHundredsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: partialAmountHundredsSelection) { v in
                                    partialAmountSelection = partialAmountMillionsSelection * 1_000_000 + partialAmountThousandsSelection * 1_000 + v
                                }
                            }
                        }
                        HStack {
                            Button("Đóng") {
                                showPartialAmountWheel = false
                            }
                            Spacer()
                            Button("Lưu") {
                                partialAmount = Double(partialAmountSelection)
                                showPartialAmountWheel = false
                            }
                        }
                        .font(.headline)
                    }
                    .padding()
                    .presentationDetents([.height(340)])
                    // Range pickers
                    .sheet(isPresented: $showPartialAmountMillionsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng triệu")
                                .font(.headline)
                            Picker("", selection: $partialAmountMillionsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                    Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if partialAmountMillionsSelection < partialAmountMillionsRangeBase {
                                    partialAmountMillionsSelection = partialAmountMillionsRangeBase
                                }
                                showPartialAmountMillionsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                    .sheet(isPresented: $showPartialAmountThousandsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng ngàn")
                                .font(.headline)
                            Picker("", selection: $partialAmountThousandsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 999, by: 100)), id: \.self) { v in
                                    Text(v == 0 ? ">0" : ">\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if partialAmountThousandsSelection < partialAmountThousandsRangeBase {
                                    partialAmountThousandsSelection = partialAmountThousandsRangeBase
                                }
                                showPartialAmountThousandsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                    .sheet(isPresented: $showPartialAmountHundredsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng trăm")
                                .font(.headline)
                            Picker("", selection: $partialAmountHundredsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                    Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if partialAmountHundredsSelection < partialAmountHundredsRangeBase || partialAmountHundredsSelection > partialAmountHundredsRangeBase + 99 {
                                    partialAmountHundredsSelection = partialAmountHundredsRangeBase
                                }
                                showPartialAmountHundredsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                }
            }
            // Date Picker
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker("Ngày dự kiến trả", selection: Binding(
                            get: { expectedPayDate ?? Date() },
                            set: { expectedPayDate = $0 }
                        ), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Ngày dự kiến trả")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showDatePicker = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                let initialPartialAmount = partialAmount
                let millions = Int(initialPartialAmount / 1_000_000)
                let thousands = Int((initialPartialAmount.truncatingRemainder(dividingBy: 1_000_000)) / 1_000)
                let hundreds = Int(initialPartialAmount.truncatingRemainder(dividingBy: 1_000))
                
                partialAmountMillionsSelection = millions
                partialAmountThousandsSelection = thousands
                partialAmountHundredsSelection = hundreds
                partialAmountSelection = millions * 1_000_000 + thousands * 1_000 + hundreds
                
                partialAmountMillionsRangeBase = max(0, millions - 500)
                partialAmountThousandsRangeBase = max(0, thousands - 500)
                partialAmountHundredsRangeBase = max(0, (hundreds / 100) * 100)
                
                // Khởi tạo trạng thái thanh toán từ bill gốc (khi sửa đơn)
                isPaidConfirmed = initialIsPaid
                // Sync local copy
                localPayFullAmount = payFullAmount
            }
            .confirmationDialog("Chọn trạng thái đơn hàng", isPresented: $showOrderStatusPicker, titleVisibility: .visible) {
                Button("🛍️ Chuẩn bị hàng")  { orderStatus = "preparing" }
                Button("📦 Đã soạn hàng")    { orderStatus = "prepared" }
                Button("🚴 Đang giao hàng")  { orderStatus = "delivering" }
                Button("✅ Đã giao hàng")    { orderStatus = "delivered" }
                Button("🎉 Hoàn thành")      { orderStatus = "completed" }
                Button("❌ Đã Huỷ", role: .destructive) { orderStatus = "cancelled" }
                Button("⭕ Chưa cập nhật")   { orderStatus = nil }
                Button("Hủy", role: .cancel) { }
            }
        }
        
        private func orderStatusDisplayInfo(_ status: String?) -> (label: String, icon: String, color: Color) {
            switch status {
            case "preparing":  return ("Chuẩn bị hàng",  "bag.fill",              .purple)
            case "prepared":   return ("Đã soạn hàng",   "shippingbox.fill",      .orange)
            case "delivering": return ("Đang giao hàng", "figure.walk",           Color(red: 0.0, green: 0.6, blue: 1.0))
            case "delivered":  return ("Đã giao hàng",   "bicycle",               Color(red: 0.2, green: 0.6, blue: 1.0))
            case "completed":  return ("Hoàn thành",      "checkmark.seal.fill",  .green)
            case "cancelled":  return ("Đã Huỷ",          "xmark.circle.fill",    .red)
            default:           return ("Chưa cập nhật",   "circle.dotted",        .gray)
            }
        }
        
        
        
        
        
        
        
        final class ImageCache {
            static let shared = ImageCache()
            private let cache = NSCache<NSURL, UIImage>()
            func image(for url: URL) -> UIImage? {
                cache.object(forKey: url as NSURL)
            }
            func insert(_ image: UIImage, for url: URL) {
                cache.setObject(image, forKey: url as NSURL)
            }
        }
        
        final class CachedImageLoader: ObservableObject {
            @Published var image: UIImage?
            
            func load(url: URL, targetSize: CGSize? = nil) {
                if let cached = ImageCache.shared.image(for: url) {
                    image = cached
                    return
                }
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let target = targetSize ?? UIScreen.main.bounds.size
                        let ui = Self.downsample(data: data, to: target, scale: UIScreen.main.scale) ?? UIImage(data: data)
                        await MainActor.run {
                            image = ui
                        }
                        if let ui {
                            ImageCache.shared.insert(ui, for: url)
                        }
                    } catch {
                    }
                }
            }
            
            static func downsample(data: Data, to size: CGSize, scale: CGFloat) -> UIImage? {
                let cfData = data as CFData
                guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }
                let maxDimension = Int(max(size.width, size.height) * scale)
                let options: [NSString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
                return UIImage(cgImage: cgImage)
            }
        }
        
        
        struct DottedLine: Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: 0))
                return path
            }
        }
        
        struct QRCodeView: View {
            let payload: String
            var body: some View {
                if let image = generateQRCode(from: payload) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(5).background(Color.white).cornerRadius(8)
                } else {
                    Image(systemName: "qrcode").resizable().interpolation(.none).scaledToFit()
                }
            }
            private func generateQRCode(from string: String) -> UIImage? {
                let context = CIContext()
                let filter = CIFilter.qrCodeGenerator()
                let data = Data(string.utf8)
                filter.setValue(data, forKey: "inputMessage")
                filter.setValue("Q", forKey: "inputCorrectionLevel")
                guard let outputImage = filter.outputImage else { return nil }
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = outputImage.transformed(by: transform)
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
                return nil
            }
        }
    }

// MARK: - Guide View with Accordion
struct GuideView: View {
    @Binding var isPresented: Bool
    @State private var expandedSections: Set<String> = []
    
    private func toggleSection(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        Text("📖 Hướng dẫn sử dụng & Tính năng")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Chào mừng bạn đến với hệ thống quản lý cửa hàng! Nhấn vào từng phần để xem chi tiết:")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    SectionButton(
                        icon: "🏠",
                        title: "Tab Tổng quan & Tính doanh thu lợi nhuận",
                        isExpanded: expandedSections.contains("overview"),
                        action: { toggleSection("overview") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Xem doanh thu, lợi nhuận theo thời gian thực")
                                Text("• Lọc theo hôm nay/tuần này/tháng này/quý này")
                                Text("• Xem lợi nhuận bán lẻ và bán sỉ riêng biệt")
                            }
                            .font(.subheadline)
                            
                            Divider()
                            
                            Text("📊 Công thức tính lợi nhuận (Bán lẻ):")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. Doanh thu = Tổng tiền các đơn đã thanh toán")
                                Text("2. Giá vốn (COGS) = Tổng giá nhập của các sản phẩm đã bán (tính theo AVCO)")
                                Text("3. Lợi nhuận gộp = Doanh thu − Giá vốn")
                                Text("4. Lợi nhuận ròng = Lợi nhuận gộp − Chi phí vận hành")
                            }
                            .font(.subheadline)
                            
                            Divider()
                            
                            Text("📝 Ví dụ minh họa (Bán lẻ):")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bạn bán 10 bó hoa hồng, mỗi bó 50.000đ:")
                                    .font(.subheadline)
                                HStack {
                                    Text("• Doanh thu:")
                                    Spacer()
                                    Text("500.000đ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                                HStack {
                                    Text("• Giá vốn (mỗi bó 30.000đ):")
                                    Spacer()
                                    Text("300.000đ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }
                                HStack {
                                    Text("• Lợi nhuận gộp:")
                                    Spacer()
                                    Text("200.000đ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                HStack {
                                    Text("• Chi phí vận hành (thuê mặt bằng):")
                                    Spacer()
                                    Text("50.000đ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                }
                                Divider()
                                HStack {
                                    Text("👉 Lợi nhuận ròng:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("150.000đ")
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }
                            }
                            .font(.subheadline)
                            .padding()
                            .background(Color.themeBackgroundLight)
                            .cornerRadius(12)
                            
                            Divider()
                            
                            Text("🏭 Công thức tính lợi nhuận (Bán sỉ):")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. Đã thu = Tổng tiền thực tế thu được từ khách sỉ")
                                Text("2. Chi phí nguyên liệu = Tổng chi phí nhập nguyên liệu trong cùng kỳ")
                                Text("3. Lợi nhuận ròng bán sỉ = Đã thu − Chi phí nguyên liệu")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "🛒",
                        title: "Tab Đơn hàng",
                        isExpanded: expandedSections.contains("orders"),
                        action: { toggleSection("orders") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Tạo đơn hàng bán lẻ nhanh chóng")
                                Text("• Quét mã vạch sản phẩm bằng camera")
                                Text("• Nhập đơn hàng bằng giọng nói AI")
                                Text("• Xem lịch sử tất cả đơn hàng")
                                Text("• Chỉnh sửa đơn hàng đã tạo")
                            }
                            .font(.subheadline)
                            
                            Divider()
                            
                            Text("💡 Cách dùng nhanh:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("Nhấn nút lớn màu xanh dương ở giữa tab bar để tạo đơn hàng ngay lập tức!")
                                .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "📦",
                        title: "Tab Kho hàng",
                        isExpanded: expandedSections.contains("inventory"),
                        action: { toggleSection("inventory") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Quản lý danh sách sản phẩm (thêm/sửa/xoá)")
                                Text("• Nhập hàng (Restock)")
                                Text("• Xem lịch sử nhập kho chi tiết")
                                Text("• Quản lý kho nguyên vật liệu (nếu bật chế độ sản xuất)")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "💰",
                        title: "Tab Chi phí",
                        isExpanded: expandedSections.contains("expenses"),
                        action: { toggleSection("expenses") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Quản lý chi phí vận hành (thuê mặt bằng, lương, điện nước...)")
                                Text("• Xem lịch sử chi phí")
                                Text("• Chi phí này sẽ được trừ vào lợi nhuận ròng bán lẻ")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "📊",
                        title: "Tab Thống kê",
                        isExpanded: expandedSections.contains("statistics"),
                        action: { toggleSection("statistics") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Xem doanh thu, lợi nhuận chi tiết theo ngày/tuần/tháng/quý")
                                Text("• Xem lợi nhuận bán lẻ và bán sỉ riêng biệt")
                                Text("• Xem chi tiết từng ngày")
                                Text("• Xuất báo cáo CSV để mở trong Excel")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "🏭",
                        title: "Tính năng sản xuất",
                        isExpanded: expandedSections.contains("production"),
                        action: { toggleSection("production") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Xuất thành phẩm (bán sỉ cho khách hàng)")
                                Text("• Nhập nguyên liệu vào kho")
                                Text("• Xuất nguyên liệu tự động theo template")
                                Text("• Xem báo cáo sản xuất chi tiết")
                            }
                            .font(.subheadline)
                            
                            Divider()
                            
                            Text("📝 Ví dụ quy trình sản xuất:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. Nhập nguyên liệu (vd: 10kg hồng tươi, giá 500.000đ/kg)")
                                Text("2. Sản xuất thành phẩm (vd: làm 100 bó hoa từ 10kg hồng)")
                                Text("3. Xuất thành phẩm bán sỉ cho khách (vd: bán 50 bó, giá 100.000đ/bó)")
                                Text("4. Xem báo cáo sản xuất để biết lợi nhuận")
                            }
                            .font(.subheadline)
                            .padding()
                            .background(Color.themeBackgroundLight)
                            .cornerRadius(12)
                        }
                    }
                    
                    SectionButton(
                        icon: "👥",
                        title: "Quản lý nhân viên",
                        isExpanded: expandedSections.contains("employees"),
                        action: { toggleSection("employees") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng chính:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Mời nhân viên vào cửa hàng bằng email/SDT")
                                Text("• Phân quyền truy cập cho từng nhân viên")
                                Text("• Điểm danh nhân viên (chụp ảnh selfie)")
                                Text("• Xem lịch sử làm việc và giờ làm")
                                Text("• Quản lý nghỉ phép")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    SectionButton(
                        icon: "➕",
                        title: "Các tính năng khác",
                        isExpanded: expandedSections.contains("others"),
                        action: { toggleSection("others") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎯 Tính năng khác:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 💬 Chat với khách hàng")
                                Text("• ⚙️ Cài đặt cửa hàng và tuỳ chỉnh tab bar")
                                Text("• 👤 Quản lý khách hàng")
                                Text("• 📱 Nhận thông báo từ website")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Hướng dẫn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
    }
}

struct SectionButton<Content: View>: View {
    let icon: String
    let title: String
    let isExpanded: Bool
    let action: () -> Void
    let content: () -> Content
    
    init(icon: String, title: String, isExpanded: Bool, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.isExpanded = isExpanded
        self.action = action
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(icon)
                        .font(.title2)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    content()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                .background(Color.themeBackgroundLight)
            }
        }
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}
        
        // MARK: - Restock Views
        
        
        
        
        
        // DiscountEditorView moved to top-level under ContentView for wider visibility
        
    
    #Preview {
        ContentView()
    }
    
    // Extension for partial corner radius
    extension View {
        func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
            clipShape(RoundedCorner(radius: radius, corners: corners))
        }
    }
    
    struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners
        
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }
