import SwiftUI
import CoreImage.CIFilterBuiltins
import PhotosUI

// MARK: - Theme Colors
extension Color {
    static let themePrimary = Color(red: 25/255, green: 230/255, blue: 196/255)
    static let themeBackgroundLight = Color(red: 246/255, green: 248/255, blue: 248/255)
    static let themeBackgroundDark = Color(red: 17/255, green: 33/255, blue: 30/255)
    static let themeTextDark = Color(red: 17/255, green: 24/255, blue: 23/255)
}

struct ContentView: View {
    @StateObject private var viewModel = OrderViewModel()
    @State private var selectedTab: Int = 0
    @State private var showNewOrder: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeDashboardView(viewModel: viewModel, showNewOrder: $showNewOrder)
                    .tag(0)
                
                OrderHistoryView(viewModel: viewModel)
                    .tag(1)
                
                // Placeholder for FAB
                Color.clear
                    .tag(2)
                
                Text("Stock (Coming Soon)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                    .tag(3)
                
                Text("Settings (Coming Soon)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                    .tag(4)
            }
            .accentColor(.themePrimary)
            
            // Custom Tab Bar Overlay
            VStack {
                Spacer()
                
                ZStack(alignment: .top) {
                    // Tab Bar Background
                    HStack {
                        TabItem(icon: "house.fill", title: "Home", isSelected: selectedTab == 0) { selectedTab = 0 }
                        Spacer()
                        TabItem(icon: "list.clipboard.fill", title: "Orders", isSelected: selectedTab == 1) { selectedTab = 1 }
                        
                        Spacer()
                            .frame(width: 60) // Space for FAB
                        
                        Spacer()
                        TabItem(icon: "archivebox.fill", title: "Stock", isSelected: selectedTab == 3) { selectedTab = 3 }
                        Spacer()
                        TabItem(icon: "gearshape.fill", title: "Setup", isSelected: selectedTab == 4) { selectedTab = 4 }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 72)
                    .background(Color.white)
                    .cornerRadius(36)
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    
                    // FAB
                    Button(action: { showNewOrder = true }) {
                        Circle()
                            .fill(Color.themePrimary)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.themePrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.themeTextDark)
                            )
                    }
                    .offset(y: -28)
                }
            }
        }
        .fullScreenCover(isPresented: $showNewOrder) {
            SmartOrderEntryView(viewModel: viewModel)
        }
        .onChange(of: viewModel.editingBill) { bill in
            if bill != nil {
                showNewOrder = true
            }
        }
    }
}

struct TabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray.opacity(0.5))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(), value: isSelected)
                
                if isSelected {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 50)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

// MARK: - Home Dashboard
struct HomeDashboardView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showNewOrder: Bool
    @State private var selectedDate = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                    
                    VStack(alignment: .leading) {
                        Text("Luxe Cafe")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
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
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Daily Stats
                    HStack(spacing: 16) {
                        StatCard(title: "Income", value: formatCurrency(viewModel.revenue(for: selectedDate)), trend: "", icon: "banknote.fill", isPositive: true)
                        StatCard(title: "Orders", value: "\(viewModel.orders(for: selectedDate).count)", trend: "", icon: "bag.fill", isPositive: true)
                    }
                }
                .padding(.horizontal)
                
                // Daily Orders List
                if !viewModel.orders(for: selectedDate).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Orders on \(formatDate(selectedDate))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.orders(for: selectedDate)) { bill in
                            HStack {
                                Text(formatTime(bill.createdAt))
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .frame(width: 50, alignment: .leading)
                                
                                VStack(alignment: .leading) {
                                    Text(billItemsSummary(bill))
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(bill.total))
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        QuickActionButton(icon: "cart.badge.plus", title: "New Order", isPrimary: true) {
                            showNewOrder = true
                        }
                        QuickActionButton(icon: "archivebox", title: "Inventory", isPrimary: false) {}
                        QuickActionButton(icon: "chart.bar", title: "Analytics", isPrimary: false) {}
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.themeBackgroundLight)
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func billItemsSummary(_ bill: Bill) -> String {
        let names = bill.items.map { $0.name }
        return names.joined(separator: ", ")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let trend: String
    let icon: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .textCase(.uppercase)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
            
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(trend)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(isPositive ? Color.green : Color.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPrimary ? Color.themePrimary : Color.white)
            .foregroundStyle(Color.themeTextDark)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: isPrimary ? 0 : 1)
            )
        }
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
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
                    Text(viewModel.editingBill != nil ? "Edit Order" : "New Order")
                        .font(.headline)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.themeTextDark)
                    }
                }
                .padding()
                .background(Color.white)
                
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Button(action: { viewModel.selectedCategory = category }) {
                                VStack(spacing: 12) {
                                    Text(category.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(viewModel.selectedCategory == category ? Color.themeTextDark : Color.gray)
                                    
                                    Rectangle()
                                        .fill(viewModel.selectedCategory == category ? Color.themePrimary : Color.clear)
                                        .frame(height: 3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 4)
                .background(Color.white)
                
                // Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.filteredProducts) { product in
                            Button(action: { viewModel.addProduct(product) }) {
                                ProductCard(product: product)
                            }
                            .simultaneousGesture(
                                LongPressGesture()
                                    .onEnded { _ in
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
                            
                            Text("Order Summary")
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
                                    } else if let sysImage = item.systemImage {
                                        Image(systemName: sysImage)
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
                                        Label("Edit Details", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button("+ Increase") {
                                        viewModel.updateItem(item, newQuantity: item.quantity + 1)
                                    }
                                    
                                    Button("- Decrease") {
                                        viewModel.updateItem(item, newQuantity: item.quantity - 1)
                                    }
                                    
                                    Button("Remove", role: .destructive) {
                                        viewModel.removeItem(item)
                                    }
                                }
                            }
                            
                            // Manual Add Button
                            Button(action: { showManualInput = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("Add Item")
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
                            viewModel.showPayment = true
                        }
                    }) {
                        HStack {
                            Text(viewModel.editingBill != nil ? "Save Changes" : "Review & Pay")
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
                Section(header: Text("Customize Item")) {
                    TextField("Name", text: $name)
                    TextField("Price", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                        
                        Button("Remove Photo", role: .destructive) {
                            selectedImageData = nil
                        }
                    } else {
                        // Show placeholder or current system icon
                        VStack {
                            Image(systemName: product.imageName)
                                .font(.system(size: 60))
                                .foregroundStyle(Color.themePrimary)
                            Text("Default Icon")
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
                            Text(selectedImageData == nil ? "Select Photo" : "Change Photo")
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
            .navigationTitle("Add to Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    TextField("Price", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Manual Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    TextField("Price", text: $price)
                        .keyboardType(.numberPad)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                        
                        Button("Remove Photo", role: .destructive) {
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
                            Text("No Photo Selected")
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
                            Text(selectedImageData == nil ? "Select Photo" : "Change Photo")
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
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            
            Text(product.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .cornerRadius(16)
    }
    
    func colorForString(_ name: String) -> Color {
        switch name {
        case "brown": return .brown
        case "orange": return .orange
        case "black": return .black
        case "purple": return .purple
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        case "pink": return .pink
        case "gray": return .gray
        default: return .gray
        }
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

// Helpers
func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "VND"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
}

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
                
                if viewModel.pastOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("No orders yet")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else {
                    List {
                        ForEach(viewModel.pastOrders) { bill in
                            Button(action: { selectedBill = bill }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formatDate(bill.createdAt))
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
                            .listRowBackground(Color.white) // Force white background for rows
                            .contextMenu {
                                Button(action: {
                                    viewModel.startEditing(bill)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: {
                                    viewModel.deleteOrder(bill)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: viewModel.deleteOrder)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden) // Hide default list background
                    .background(Color.themeBackgroundLight) // Use light theme background
                }
            }
            .navigationTitle("Order History")
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, viewModel: viewModel)
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
    
    func billItemsSummary(_ bill: Bill) -> String {
        let names = bill.items.map { $0.name }
        return names.joined(separator: ", ")
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
                Button("Edit") {
                    viewModel.startEditing(bill)
                    dismiss()
                }
                .foregroundStyle(Color.blue)
                
                Spacer()
                Button("Close") { dismiss() }
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
                    Text("Delete Order")
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
        .alert("Delete Order?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteOrder(bill)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this order? This action cannot be undone.")
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
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

#Preview {
    ContentView()
}