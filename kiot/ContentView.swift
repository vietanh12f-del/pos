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
    
    init() {
        // Hide default TabBar
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
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                HomeDashboardView(viewModel: viewModel, showNewOrder: $showNewOrder, selectedTab: $selectedTab)
                    .tag(0)
                
                OrderHistoryView(viewModel: viewModel)
                    .tag(1)
                
                // Placeholder for FAB
                Color.clear
                    .tag(2)
                
                RestockHistoryView(viewModel: viewModel)
                    .tag(3)
                
                GoodsView(viewModel: viewModel)
                    .tag(4)
                
                ChatView(orderViewModel: viewModel, isTabBarVisible: $isTabBarVisible)
                    .tag(5)
                
                SettingsView()
                    .tag(6)
            }
            .accentColor(.themePrimary)
            .padding(.bottom, isTabBarVisible ? 160 : 0) // Add padding for custom tab bar
            
            // Custom Tab Bar Overlay
            if isTabBarVisible {
                WheelTabBarView(
                    tabBarManager: tabBarManager,
                    selectedTab: $selectedTab,
                    showNewOrder: $showNewOrder,
                    showEditTabBar: $showEditTabBar
                )
                .transition(.move(edge: .bottom))
            }
        }
        .fullScreenCover(isPresented: $showNewOrder) {
            SmartOrderEntryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditTabBar) {
            EditTabBarView(tabBarManager: tabBarManager)
        }
        .onChange(of: viewModel.editingBill) { bill in
            if bill != nil {
                showNewOrder = true
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
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                    
                    VStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Text("Kiot Hoa")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                            
                            // Database Status
                            if viewModel.isDatabaseConnected {
                                Image(systemName: "icloud.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.icloud.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        Text(currentDateString())
                            .font(.caption)
                            .foregroundStyle(.gray)
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
                                StatCard(title: "Chi phí", value: formatCurrency(viewModel.restockCost(for: selectedDate)), icon: "arrow.up.right", trend: "", isPositive: false)
                            }
                            
                            // Net Profit Highlight
                            let profit = viewModel.profit(for: selectedDate)
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("LỢI NHUẬN RÒNG")
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
                            QuickActionButton(icon: "archivebox", title: "Kho hàng", isPrimary: false) {
                                selectedTab = 3
                            }
                        }
                        
                        if StoreManager.shared.hasPermission(.viewInventory) {
                            QuickActionButton(icon: "cube.box", title: "Hàng hóa", isPrimary: false) {
                                selectedTab = 4
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
                                withAnimation {
                                    selectedDate = Date()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
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


// MARK: - Smart Order Entry
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
                    List {
                        ForEach(viewModel.searchSuggestions) { product in
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                viewModel.addProduct(product)
                                viewModel.searchText = ""
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: product.imageName)
                                        .font(.title2)
                                        .foregroundStyle(Color.themePrimary)
                                        .frame(width: 40, height: 40)
                                        .background(Color.themePrimary.opacity(0.1))
                                        .clipShape(Circle())
                                    
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
            Button(action: { viewModel.toggleRecording() }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                        )
                    
                    Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: viewModel.speechRecognizer.isRecording)
                }
            }
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
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tùy chỉnh")) {
                    TextField("Tên", text: $name)
                    TextField("Giá", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Số lượng", text: $quantity)
                        .keyboardType(.numberPad)
                    
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết mặt hàng")) {
                    TextField("Tên mặt hàng", text: $name)
                    TextField("Giá", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Số lượng", text: $quantity)
                        .keyboardType(.numberPad)
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
                            viewModel.addItem(name, price: priceVal, quantity: qtyVal)
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
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    init(item: OrderItem, viewModel: OrderViewModel) {
        self.item = item
        self.viewModel = viewModel
        _name = State(initialValue: item.name)
        _price = State(initialValue: String(Int(item.price)))
        _quantity = State(initialValue: String(item.quantity))
        _selectedImageData = State(initialValue: item.imageData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết")) {
                    TextField("Tên", text: $name)
                    TextField("Giá", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Số lượng", text: $quantity)
                        .keyboardType(.numberPad)
                    
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
            .navigationTitle("Sửa mặt hàng")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        if let priceVal = Double(price), let qtyVal = Int(quantity) {
                            viewModel.updateItemFull(item, name: name, price: priceVal, quantity: qtyVal, imageData: selectedImageData)
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
                        onComplete: {
                            viewModel.completeOrder()
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
                        viewModel.reset()
                        dismiss()
                    }
                    ActionButton(icon: "square.and.arrow.up", title: "Chia sẻ") {
                        renderImage()
                    }
                    ActionButton(icon: "printer", title: "In") {}
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
    let onComplete: (() -> Void)?
    
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
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.themeTextDark)
                            Text("\(item.quantity) x \(formatCurrency(item.price))")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray)
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
                        Text("NGUYEN VIET ANH - VCB")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.themeTextDark)
                        Text("9967861809")
                            .font(.footnote)
                            .foregroundStyle(Color.gray)
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
                        onComplete?()
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
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String, color: Color = .black, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 50, height: 50).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                }
                Text(title).font(.caption).fontWeight(.bold).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct OrderHistoryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @State private var selectedBill: Bill?
    
    init(viewModel: OrderViewModel) {
        self.viewModel = viewModel
        // Customize Navigation Bar Title Appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.themeBackgroundLight.ignoresSafeArea()
                
                if !StoreManager.shared.hasPermission(.viewOrders) {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Bạn không có quyền xem lịch sử đơn hàng")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else if viewModel.pastOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Chưa có đơn hàng nào")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else {
                    List {
                        ForEach(sections, id: \.title) { section in
                            Section(header: Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gray)
                                .padding(.vertical, 4)) {
                                ForEach(section.bills) { bill in
                                    Button(action: { selectedBill = bill }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(formatTime(bill.createdAt))
                                                    .font(.caption)
                                                    .foregroundStyle(Color.gray)
                                                
                                                Text(billItemsSummary(bill))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.themeTextDark)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(formatCurrency(bill.total))
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.themePrimary)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .listRowBackground(Color.white)
                                    .contextMenu {
                                        Button(action: {
                                            viewModel.startEditing(bill)
                                        }) {
                                            Label("Sửa", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            viewModel.deleteOrder(bill)
                                        }) {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        let bill = section.bills[index]
                                        viewModel.deleteOrder(bill)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden) // Hide default list background
                    .background(Color.themeBackgroundLight) // Use light theme background
                }
            }
            .navigationTitle("Lịch sử đơn hàng")
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, viewModel: viewModel)
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
    

    
    var sections: [(title: String, bills: [Bill])] {
        let grouped = Dictionary(grouping: viewModel.pastOrders) { bill -> Date in
            Calendar.current.startOfDay(for: bill.createdAt)
        }
        
        return grouped.keys.sorted(by: >).map { date in
            let title: String
            if Calendar.current.isDateInToday(date) {
                title = "Hôm nay"
            } else if Calendar.current.isDateInYesterday(date) {
                title = "Hôm qua"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "vi_VN")
                formatter.dateFormat = "dd/MM/yyyy"
                title = formatter.string(from: date)
            }
            let bills = grouped[date]?.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
            return (title: title, bills: bills)
        }
    }
}

struct BillDetailView: View {
    let bill: Bill
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack {
            HStack {
                Button("Sửa") {
                    viewModel.startEditing(bill)
                    dismiss()
                }
                .foregroundStyle(Color.blue)
                
                Spacer()
                Button("Đóng") { dismiss() }
            }
            .padding()
            
            ScrollView {
                BillReceiptView(
                    items: bill.items,
                    totalAmount: bill.total,
                    dateString: formatDate(bill.createdAt),
                    qrURL: nil, // History doesn't need fresh QR usually, or we could regenerate
                    qrImage: nil,
                    billPayload: nil,
                    showButtons: false,
                    onComplete: nil
                )
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Xóa đơn hàng")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .background(Color.themeBackgroundLight)
        .alert("Xóa đơn hàng?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Xóa", role: .destructive) {
                viewModel.deleteOrder(bill)
                dismiss()
            }
        } message: {
            Text("Bạn có chắc muốn xóa đơn hàng này? Hành động này không thể hoàn tác.")
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
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

struct RestockHistoryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @State private var selectedTab: Int = 0 // 0: Inventory, 1: History
    @State private var showNewRestock = false
    @State private var showScanner = false
    @State private var editingProduct: Product?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Chế độ xem", selection: $selectedTab) {
                    Text("Tồn kho").tag(0)
                    Text("Lịch sử nhập").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    // Inventory View
                    if !StoreManager.shared.hasPermission(.viewInventory) {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Text("Bạn không có quyền xem kho hàng")
                                .font(.headline)
                                .foregroundStyle(Color.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.themeBackgroundLight)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.products) { product in
                                    let stock = viewModel.stockLevel(for: product.name)
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(colorForString(product.color).opacity(0.1))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: product.imageName)
                                                    .foregroundStyle(colorForString(product.color))
                                            }
                                            Spacer()
                                            if stock <= 5 {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(.orange)
                                                    .font(.caption)
                                            }
                                        }
                                        
                                        Text(product.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.themeTextDark)
                                            .lineLimit(1)
                                        
                                        HStack {
                                            Text("Tồn:")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                            Spacer()
                                            Text("\(stock)")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(stock == 0 ? .red : (stock <= 5 ? .orange : .green))
                                        }
                                        
                                        Text(formatCurrency(product.price))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.05), radius: 2)
                                    .onTapGesture {
                                        editingProduct = product
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color.themeBackgroundLight)
                    }
                } else {
                    // History View
                    if !StoreManager.shared.hasPermission(.viewInventory) {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Text("Bạn không có quyền xem lịch sử nhập hàng")
                                .font(.headline)
                                .foregroundStyle(Color.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ZStack(alignment: .bottomTrailing) {
                            List {
                            if viewModel.restockHistory.isEmpty {
                                Text("Chưa có lịch sử nhập hàng")
                                    .foregroundStyle(.gray)
                                    .padding()
                            } else {
                                ForEach(viewModel.restockHistory) { bill in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(formatDate(bill.createdAt))
                                                .font(.headline)
                                                .foregroundStyle(Color.themeTextDark)
                                            Spacer()
                                            Text(formatCurrency(bill.totalCost))
                                                .fontWeight(.bold)
                                                .foregroundStyle(.red)
                                        }
                                        
                                        Text("\(bill.items.count) mặt hàng")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        
                                        // Preview first few items
                                        Text(bill.items.prefix(3).map { "\($0.quantity)x \($0.name)" }.joined(separator: ", "))
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .contextMenu {
                                        Button(action: {
                                            viewModel.editRestockBill(bill)
                                            showNewRestock = true
                                        }) {
                                            Label("Sửa", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            viewModel.deleteRestockBill(bill)
                                        }) {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                                }
                                .onDelete(perform: { indexSet in
                                    for index in indexSet {
                                        viewModel.deleteRestockBill(viewModel.restockHistory[index])
                                    }
                                })
                            }
                        }
                        .listStyle(.insetGrouped)
                        
                        // FAB for New Restock
                        Button(action: { showNewRestock = true }) {
                            Circle()
                            .fill(Color.themePrimary)
                            .frame(width: 56, height: 56)
                            .shadow(radius: 4)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(Color.themeTextDark)
                            )
                        }
                        .padding()
                        .padding(.bottom, 80) // Above Tab Bar
                    }
                }
            }
        }
    }
            .navigationTitle("Kho")
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            Button(action: { showScanner = true }) {
                                Image(systemName: "doc.text.viewfinder")
                            }
                            Button(action: { showNewRestock = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showNewRestock) {
                RestockEntryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showScanner) {
                InvoiceScannerView(viewModel: viewModel)
            }
            .sheet(item: $editingProduct) { product in
                ProductEditView(viewModel: viewModel, mode: .edit(product))
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }


struct RestockEntryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showManualInput = false
    @State private var showScanner = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // List of Items
                    List {
                        if viewModel.restockItems.isEmpty {
                            Text("Nhấn mic để nói hoặc thêm thủ công.")
                                .foregroundStyle(.gray)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.restockItems) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.themeTextDark)
                                        Text("\(item.quantity) x \(formatCurrency(item.unitPrice))")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(item.totalCost))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themeTextDark)
                                }
                            }
                            .onDelete(perform: viewModel.removeRestockItem)
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    // Total & Action
                    VStack(spacing: 16) {
                        HStack {
                            Text("Tổng chi phí")
                                .font(.headline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(viewModel.restockItems.reduce(0) { $0 + $1.totalCost }))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            viewModel.completeRestockSession()
                            dismiss()
                        }) {
                            Text("Hoàn tất nhập hàng")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themePrimary)
                                .cornerRadius(16)
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color.white)
                    .shadow(radius: 5)
                }
                
                // Mic & Manual Input Controls
                VStack {
                    Spacer()
                    HStack {
                        // Manual Input Button
                        Button(action: { showManualInput = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(radius: 3)
                                .overlay(Image(systemName: "keyboard").foregroundStyle(Color.themeTextDark))
                        }
                        
                        Spacer()
                        
                        // Mic Button
                        Button(action: viewModel.toggleRecording) {
                            Circle()
                                .fill(viewModel.speechRecognizer.isRecording ? Color.red : Color.themeTextDark)
                                .frame(width: 70, height: 70)
                                .shadow(radius: 4)
                                .overlay(
                                    Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                )
                        }
                        
                        Spacer()
                        
                        // Scanner Button
                        Button(action: { showScanner = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(radius: 3)
                                .overlay(Image(systemName: "doc.text.viewfinder").foregroundStyle(Color.themeTextDark))
                        }
                    }
                    .padding(.bottom, 140) // Adjust based on Total section height
                    .padding(.horizontal, 40)
                }
            }
            .navigationTitle("Nhập hàng")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
            }
            .onAppear {
                viewModel.isRestockMode = true
            }
            .onDisappear {
                viewModel.isRestockMode = false
            }
            .sheet(isPresented: $showManualInput) {
                ManualRestockItemView(viewModel: viewModel)
            }
            .sheet(isPresented: $showScanner) {
                InvoiceScannerView(viewModel: viewModel)
            }
        }
    }
}

struct ManualRestockItemView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var incurredCost = ""
    @State private var sellingPrice = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết hàng hóa")) {
                    TextField("Tên hàng", text: $name)
                    if !name.isEmpty {
                        Text("Tồn hiện tại: \(viewModel.stockLevel(for: name))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    TextField("Số lượng", text: $quantity)
                        .keyboardType(.numberPad)
                        .onChange(of: quantity) { _ in updateSellingPrice() }
                    
                    TextField("Đơn giá nhập", text: $price)
                        .keyboardType(.decimalPad)
                        .onChange(of: price) { newValue in
                            // Filter non-numeric characters first (allow comma and dot)
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                price = filtered
                            }
                            updateSellingPrice()
                        }
                    
                    TextField("Chi phí phát sinh (Ship, bao bì...)", text: $incurredCost)
                        .keyboardType(.decimalPad)
                        .onChange(of: incurredCost) { newValue in
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                incurredCost = filtered
                            }
                            updateSellingPrice()
                        }
                    
                    if let p = parseDouble(price), let q = Int(quantity), q > 0 {
                        let extra = parseDouble(incurredCost) ?? 0
                        let total = (p * Double(q)) + extra
                        let unitCost = total / Double(q)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tổng chi phí:")
                                Spacer()
                                Text(formatCurrency(total))
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Giá vốn/sp:")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(unitCost))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    TextField("Giá bán dự kiến (Lãi 30%)", text: $sellingPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Thêm hàng nhập")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thêm") {
                        if let p = parseDouble(price), let q = Int(quantity), !name.isEmpty {
                            let extra = parseDouble(incurredCost) ?? 0
                            let suggested = parseDouble(sellingPrice)
                            viewModel.addRestockItem(name, unitPrice: p, quantity: q, additionalCost: extra, suggestedPrice: suggested)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty || quantity.isEmpty)
                }
            }
        }
        .presentationDetents([.height(550)])
    }
    
    func updateSellingPrice() {
        if let p = parseDouble(price), let q = Int(quantity), q > 0 {
            let extra = parseDouble(incurredCost) ?? 0
            let total = (p * Double(q)) + extra
            let unitCost = total / Double(q)
            let suggested = unitCost * 1.3
            sellingPrice = String(Int(suggested))
        }
    }
    
    func parseDouble(_ input: String) -> Double? {
        // Handle "2,000" or "20,000" (Thousands separator)
        // If input contains comma, remove it assuming it's a thousands separator for VND
        // e.g. "2,000" -> "2000"
        let clean = input.replacingOccurrences(of: ",", with: "")
        
        // Also handle "2.000" as 2000 if it looks like thousands separator (common in VN)
        // Simple heuristic: if it has a dot and 3 digits after it, and no other dots/commas... 
        // But let's stick to the user request: "unit input with comma like 2,000"
        // So we strip comma.
        
        return Double(clean)
    }
}


#Preview {
    ContentView()
}
