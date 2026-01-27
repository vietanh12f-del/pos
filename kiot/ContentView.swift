import SwiftUI
import CoreImage.CIFilterBuiltins

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
                
                Text("Orders History (Coming Soon)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
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
                HStack {
                    TabItem(icon: "house", title: "Home", isSelected: selectedTab == 0) { selectedTab = 0 }
                    Spacer()
                    TabItem(icon: "receipt", title: "Orders", isSelected: selectedTab == 1) { selectedTab = 1 }
                    Spacer()
                    
                    // FAB
                    Button(action: { showNewOrder = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.themePrimary)
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.themePrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                    .offset(y: -24)
                    
                    Spacer()
                    TabItem(icon: "archivebox", title: "Stock", isSelected: selectedTab == 3) { selectedTab = 3 }
                    Spacer()
                    TabItem(icon: "gearshape", title: "Setup", isSelected: selectedTab == 4) { selectedTab = 4 }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .frame(height: 80)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showNewOrder) {
            SmartOrderEntryView(viewModel: viewModel)
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
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
            }
            .frame(width: 50)
        }
    }
}

// MARK: - Home Dashboard
struct HomeDashboardView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showNewOrder: Bool
    
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
                
                // AI Insight
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.themeTextDark)
                            Text("Smart Insight")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        Text("Today is busier than usual! You might need extra staff by 4 PM to handle the rush.")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeTextDark.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Text("View why")
                                .font(.caption)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                    .foregroundStyle(Color.themeTextDark)
                }
                .padding()
                .background(Color.themePrimary.opacity(0.1))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themePrimary.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)
                
                // Stats
                HStack(spacing: 16) {
                    StatCard(title: "Revenue", value: formatCurrency(viewModel.revenue), trend: "+12%", icon: "arrow.up.right", isPositive: true)
                    StatCard(title: "Orders", value: "\(viewModel.orderCount)", trend: "+5%", icon: "arrow.up.right", isPositive: true)
                }
                .padding(.horizontal)
                
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
                
                // Revenue Graph
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today's Revenue")
                            .font(.headline)
                        Spacer()
                        Text("Live")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.themePrimary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<10) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i == 9 ? Color.themePrimary : Color.themePrimary.opacity(Double(i+2)/15.0))
                                    .frame(height: CGFloat.random(in: 30...120))
                            }
                        }
                        .padding()
                    }
                    .frame(height: 200)
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.themeTextDark)
                    }
                    Spacer()
                    Text("New Order")
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
                .padding(.bottom, 240) // Position above FAB
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: viewModel.currentInput)
                .zIndex(1) // Ensure it stays on top
            }
            
            // Voice Assistant FAB
            Button(action: { viewModel.toggleRecording() }) {
                ZStack {
                    Circle()
                        .fill(Color.themePrimary)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                        )
                    
                    Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(Color.themeTextDark)
                        .symbolEffect(.pulse, isActive: viewModel.speechRecognizer.isRecording)
                }
            }
            .padding(.bottom, 160)
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
                                HStack(spacing: 6) {
                                    Text("\(item.quantity)x")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themeTextDark)
                                    Text(item.name)
                                        .font(.caption)
                                        .foregroundStyle(Color.themeTextDark)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.showPayment = true
                    }) {
                        HStack {
                            Text("Review & Pay")
                            Image(systemName: "arrow.right")
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
        .onChange(of: viewModel.currentInput) { newValue in
            if !newValue.isEmpty && !viewModel.speechRecognizer.isRecording {
                viewModel.processInput()
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