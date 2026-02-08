import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import PhotosUI

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
    
    init() {
        // Default TabBar
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        if !authManager.isAuthenticated {
            AuthenticationView()
        } else if authManager.needsProfileCreation {
            ProfileCreationView()
        } else if storeManager.currentStore == nil {
            StoreSelectionView()
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        HomeDashboardView(viewModel: viewModel, showNewOrder: $showNewOrder, selectedTab: $selectedTab)
                            .tabItem {
                                Label("Tổng quan", systemImage: "house.fill")
                            }
                            .tag(0)
                        
                        OrderHistoryView(viewModel: viewModel)
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
                                Label("Chi phí", systemImage: "banknote.fill")
                            }
                            .tag(4)
                        
                        ChatView(orderViewModel: viewModel, showNewChatSheet: $showNewChat, isTabBarVisible: $isTabBarVisible)
                            .tabItem {
                                Label("Chat", systemImage: "message.fill")
                            }
                            .tag(5)
                        
                        StatisticsView(viewModel: viewModel)
                            .tabItem {
                                Label("Thống kê", systemImage: "chart.bar.xaxis")
                            }
                            .tag(7)
                        
                        SettingsView(tabBarManager: tabBarManager)
                            .tabItem {
                                Label("Cài đặt", systemImage: "gearshape.fill")
                            }
                            .tag(6)
                        
                        MoreView(selectedTab: $selectedTab)
                            .tabItem {
                                Label("Thêm", systemImage: "square.grid.2x2.fill")
                            }
                            .tag(8)
                    }
                    .accentColor(.themePrimary)
                    .toolbar(.hidden, for: .tabBar)
                    // Add padding to prevent content from being hidden behind the custom tab bar
                    // Height = 50 (button) + 12 (top) + 8 (bottom) = 70 + Safe Area
                    .padding(.bottom, isTabBarVisible ? (70 + geometry.safeAreaInsets.bottom) : 0)
                    
                    // Custom Tab Bar
                    if isTabBarVisible {
                        CustomTabBarView(selectedTab: $selectedTab, showNewOrder: $showNewOrder, showNewRestock: $showNewRestock, showNewChat: $showNewChat, showNewOperatingExpense: $showNewOperatingExpense, showAddEmployee: $showAddEmployee)
                            .transition(.move(edge: .bottom))
                            .zIndex(1)
                    }
                    
                    // Voice Assistant Overlay
                    VoiceOverlayView(viewModel: viewModel, bottomPadding: isTabBarVisible ? (70 + geometry.safeAreaInsets.bottom + 10) : 20)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom) // Prevent keyboard from pushing UI up
                .fullScreenCover(isPresented: $showNewOrder) {
                    SmartOrderEntryView(viewModel: viewModel)
                }
                .fullScreenCover(isPresented: $showNewRestock) {
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
                        // Refresh employees if needed, but since this is global, we might not need to trigger update in EmployeeManagementView immediately unless it's open
                    })
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
                        if let currentStoreId = authManager.currentUserProfile?.currentStoreId {
                            // We need to fetch stores first if they aren't loaded
                            if storeManager.myStores.isEmpty && storeManager.memberStores.isEmpty {
                                Task {
                                    await storeManager.fetchStores()
                                    // Now try to select
                                    if let store = storeManager.myStores.first(where: { $0.id == currentStoreId }) ?? 
                                        storeManager.memberStores.first(where: { $0.id == currentStoreId }) {
                                        await storeManager.selectStore(store)
                                    }
                                }
                            }
                        }
                    }
                }
                .task(id: storeManager.currentStore?.id) {
                    if storeManager.currentStore != nil {
                        viewModel.clearData()
                        await viewModel.loadData()
                    }
                }
                .alert("Lỗi", isPresented: $viewModel.showErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage)
                }
            }
        }
    }
}
    
    
    // MARK: - Home Dashboard
    struct HomeDashboardView: View {
        @ObservedObject var viewModel: OrderViewModel
        @Binding var showNewOrder: Bool
        @Binding var selectedTab: Int
        @State private var selectedDate = Date()
        
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
                                
                                Button(action: {}) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .black.opacity(0.05), radius: 2)
                                        .overlay(Image(systemName: "bell").foregroundStyle(Color.themeTextDark))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Calendar Section
                            VStack(spacing: 16) {
                                DatePicker("Chọn ngày", selection: $selectedDate, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                
                                // Financial Summary
                                if StoreManager.shared.hasPermission(.viewReports) {
                                    VStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            StatCard(title: "Doanh thu", value: formatCurrency(viewModel.revenue(for: selectedDate)), icon: "arrow.down.left", trend: "", isPositive: true)
                                            StatCard(title: "Giá vốn", value: formatCurrency(viewModel.cogs(for: selectedDate)), icon: "arrow.up.right", trend: "", isPositive: true)
                                        }
                                        
                                        // Net Profit Highlight
                                        let profit = viewModel.grossProfit(for: selectedDate)
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("LỢI NHUẬN GỘP")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.white.opacity(0.8))
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
                                } else {
                                    // Restricted View Placeholder
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
                            
                            // Daily Orders List
                            if StoreManager.shared.hasPermission(.viewOrders) {
                                if !viewModel.orders(for: selectedDate).isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Đơn hàng ngày \(formatDate(selectedDate))")
                                            .font(.headline)
                                            .foregroundStyle(Color.themeTextDark)
                                            .padding(.horizontal)
                                        
                                        ForEach(viewModel.orders(for: selectedDate)) { bill in
                                            OrderRow(bill: bill)
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
                                    
                                    if StoreManager.shared.hasPermission(.viewOrders) {
                                        
                                        QuickActionButton(icon: "clock", title: "Lịch sử", isPrimary: false) {
                                            selectedTab = 1
                                        }
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.viewInventory) {
                                        QuickActionButton(icon: "cube.box.fill", title: "Kho hàng hóa", isPrimary: false) {
                                            selectedTab = 3
                                        }
                                    }
                                    
                                    // Messages might be open to all? Let's keep it open for now
                                    QuickActionButton(icon: "message", title: "Tin nhắn", isPrimary: false) {
                                        selectedTab = 5
                                    }
                                    
                                    QuickActionButton(icon: "gearshape", title: "Cài đặt", isPrimary: false) {
                                        selectedTab = 6
                                    }
                                    
                                    if StoreManager.shared.hasPermission(.viewReports) {
                                        QuickActionButton(icon: "chart.bar", title: "Thống kê", isPrimary: false) {
                                            selectedTab = 7
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .navigationTitle("Trang chủ")
                        .navigationBarHidden(true)
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
        
        var body: some View {
            ZStack(alignment: .bottom) {
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
                    }
                    .background(Color.white)
                    
                    if !viewModel.searchText.isEmpty {
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
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: product.imageName)
                                                    .font(.title2)
                                                    .foregroundStyle(Color.themePrimary)
                                                    .frame(width: 40, height: 40)
                                                    .background(Color.themePrimary.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(product.name)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.themeTextDark)
                                                
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
                        }
                    } else {
                        
                        // Categories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Category.allCases, id: \.self) { category in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.selectedCategory = category
                                        }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }) {
                                        Text(category.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                ZStack {
                                                    if viewModel.selectedCategory == category {
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
                                            .foregroundStyle(viewModel.selectedCategory == category ? Color.themeTextDark : Color.gray)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .background(Color.white)
                        
                        // Grid
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.filteredProducts) { product in
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
                            .padding(.bottom, 100) // Space for bottom sheet
                        }
                        .background(Color.themeBackgroundLight)
                    }
                }
                
                // Voice Transcript Overlay
                if viewModel.speechRecognizer.isRecording || !viewModel.currentInput.isEmpty {
                    VStack {
                        Text(viewModel.currentInput.isEmpty ? "Đang nghe..." : viewModel.currentInput)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.themeTextDark)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 340) // Position above FAB
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.currentInput)
                    .zIndex(1) // Ensure it stays on top
                }
                
                // Voice Assistant FAB
                VoiceAIButton(viewModel: viewModel)
                    .padding(.bottom, 260)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .bottomTrailing)
                
                // Order Summary Sheet (Always visible at bottom)
                VStack(spacing: 0) {
                    // Handle
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.vertical, 10)
                    
                    VStack(spacing: 16) {
                        HStack {
                            HStack(spacing: 12) {
                                Text("\(viewModel.items.reduce(0) { $0 + $1.quantity })")
                                    .font(.headline)
                                    .frame(width: 32, height: 32)
                                    .background(Color.themePrimary.opacity(0.2))
                                    .foregroundStyle(Color.themePrimary) // Should be darker
                                    .cornerRadius(8)
                                
                                Text("Tóm tắt đơn hàng")
                                    .font(.headline)
                            }
                            Spacer()
                            Text(formatCurrency(viewModel.totalAmount))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        // Horizontal Item List
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.items) { item in
                                    HStack(spacing: 8) {
                                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                        } else {
                                            Image(systemName: item.systemImage ?? "cart.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(Color.themePrimary)
                                                .frame(width: 32, height: 32)
                                                .background(Color.themePrimary.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.themeTextDark)
                                            Text("\(item.quantity)x")
                                                .font(.caption2)
                                                .foregroundStyle(Color.gray)
                                            
                                            if item.discount > 0 {
                                                Text("-\(Int(item.discount/1000))k")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .contextMenu {
                                        Button {
                                            editingItem = item
                                        } label: {
                                            Label("Sửa chi tiết", systemImage: "pencil")
                                        }
                                        
                                        Divider()
                                        
                                        Button("+ Tăng") {
                                            viewModel.updateItem(item, newQuantity: item.quantity + 1)
                                        }
                                        
                                        Button("- Giảm") {
                                            viewModel.updateItem(item, newQuantity: item.quantity - 1)
                                        }
                                        
                                        Button("Xóa", role: .destructive) {
                                            viewModel.removeItem(item)
                                        }
                                    }
                                }
                                
                                // Manual Add Button
                                Button(action: { showManualInput = true }) {
                                    HStack(spacing: 4) {
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
                        
                        Button(action: {
                            if viewModel.editingBill != nil {
                                viewModel.saveEditedOrder()
                                dismiss()
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
                                Text(viewModel.editingBill != nil ? "Lưu thay đổi" : "Thanh toán")
                                Image(systemName: viewModel.editingBill != nil ? "checkmark" : "arrow.right")
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
                    .padding(.bottom, 30)
                }
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
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
            .onChange(of: viewModel.currentInput) { newValue in
                if !newValue.isEmpty && !viewModel.speechRecognizer.isRecording {
                    viewModel.processInput()
                }
            }
            .onDisappear {
                viewModel.cancelVoiceProcessing()
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
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(16)
                        .clipped()
                } else if let urlString = product.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(16)
                                .clipped()
                        } else if phase.error != nil {
                            // Error loading
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorForString(product.color).opacity(0.1))
                                .aspectRatio(1, contentMode: .fit)
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
                                    .aspectRatio(1, contentMode: .fit)
                                ProgressView()
                            }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorForString(product.color).opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
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
                
                HStack {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Tồn: \(stockLevel)")
                        .font(.caption)
                        .foregroundStyle(stockLevel > 0 ? .gray : .red)
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
                            showButtons: true, // Interactive mode
                            onComplete: { isPaid in
                                viewModel.completeOrder(isPaid: isPaid)
                                dismiss()
                            }
                        )
                        .padding()
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        ActionButton(icon: "trash", title: "Hủy đơn", color: .red) {
                            viewModel.reset()
                            dismiss()
                        }
                        ActionButton(icon: "plus", title: "Tạo đơn mới") {
                            // Default to unpaid when creating new order
                            viewModel.completeOrder(isPaid: false)
                            dismiss()
                        }
                        ActionButton(icon: "square.and.arrow.up", title: "Chia sẻ") {
                            renderImage()
                        }
                        ActionButton(icon: "printer.fill", title: "In") {
                            renderImage()
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
                    onComplete: nil
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
    }
    
    struct BillReceiptView: View {
        let items: [OrderItem]
        let totalAmount: Double
        let dateString: String
        let qrURL: URL?
        let qrImage: UIImage?
        let billPayload: String?
        let showButtons: Bool
        let onComplete: ((Bool) -> Void)?
        
        var body: some View {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Khách lẻ")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
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
                                Text("\(item.quantity) x \(formatCurrency(item.price))")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                                
                                if item.discount > 0 {
                                    Text("-\(formatCurrency(item.discount))")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(item.total))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                }
                .padding()
                
                DottedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 1).foregroundStyle(.gray.opacity(0.3)).padding(.horizontal)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Tổng tiền hàng")
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(formatCurrency(totalAmount))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                    }
                    HStack {
                        Text("Tổng cộng")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        Spacer()
                        Text(formatCurrency(totalAmount))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quét mã thanh toán")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray)
                            
                            // Dynamic Bank Info Display
                            let bankName = StoreManager.shared.currentStore?.bankName ?? "VCB"
                            let bankAccount = StoreManager.shared.currentStore?.bankAccountNumber ?? "9967861809"
                            
                            Text("\(bankName) - \(bankAccount)")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        Spacer()
                        if let image = qrImage {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                        } else if let url = qrURL {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().interpolation(.none).scaledToFit().frame(width: 80, height: 80)
                                } else {
                                    ProgressView().frame(width: 80, height: 80)
                                }
                            }
                        } else if let payload = billPayload {
                            QRCodeView(payload: payload).frame(width: 80, height: 80)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.gray.opacity(0.3)))
                }
                .padding(.horizontal).padding(.bottom)
                
                if showButtons {
                    HStack {
                        Text("Xác nhận đã\nthanh toán?")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(action: {
                            onComplete?(true)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Đã nhận tiền")
                            }
                            .fontWeight(.medium).padding(.horizontal, 16).padding(.vertical, 10).background(Color.white).foregroundStyle(.green).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding().padding(.top, 8)
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
        }
        
        
        
        
        
        
        
        
        struct DottedLine: Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
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
        
        // MARK: - Restock Views
        
        
        
        
        
        
        
    }
    
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
