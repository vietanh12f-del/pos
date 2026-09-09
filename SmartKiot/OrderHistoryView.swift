import SwiftUI

// MARK: - Search Scope (loại tìm kiếm)
enum OrderSearchScope: String, CaseIterable, Identifiable {
    case all          = "Tất cả"
    case stt          = "Mã STT"
    case customer     = "Khách hàng"
    case product      = "Tên sản phẩm"
    case amount       = "Giá trị đơn"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:      return "line.3.horizontal.decrease.circle"
        case .stt:      return "number"
        case .customer: return "person.fill"
        case .product:  return "cart.fill"
        case .amount:   return "banknote.fill"
        }
    }
}

// MARK: - Bộ lọc nâng cao
struct OrderFilterCriteria: Equatable {
    var paymentStatus: PaymentStatusFilter = .all
    var orderStatus: OrderStatusFilter = .all
    var dateRangeEnabled: Bool = false
    var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var dateTo: Date = Date()
    var staffName: String? = nil
    
    var hasAnyActiveFilter: Bool {
        if paymentStatus != .all { return true }
        if orderStatus != .all { return true }
        if dateRangeEnabled { return true }
        if staffName != nil { return true }
        return false
    }
}

enum PaymentStatusFilter: String, CaseIterable, Identifiable {
    case all          = "Tất cả"
    case unpaid       = "Chưa thanh toán"
    case partial      = "Thanh toán 1 phần"
    case paidFull     = "Đã thanh toán"
    
    var id: String { rawValue }
    
    func matches(_ bill: Bill) -> Bool {
        switch self {
        case .all:       return true
        case .unpaid:    return bill.paymentStatus == .unpaid
        case .partial:   return bill.paymentStatus == .paidPartial
        case .paidFull:  return bill.paymentStatus == .paidFull
        }
    }
}

enum OrderStatusFilter: String, CaseIterable, Identifiable {
    case all            = "Tất cả"
    case confirmed      = "Xác nhận đơn"
    case preparing      = "Chuẩn bị hàng"
    case prepared       = "Đã soạn hàng"
    case delivering     = "Đang giao"
    case delivered      = "Đã giao"
    case completed      = "Hoàn thành"
    case cancelled      = "Đã Huỷ"
    
    var id: String { rawValue }
    
    func matches(_ bill: Bill) -> Bool {
        switch self {
        case .all:        return true
        case .confirmed:  return bill.orderStatus == "confirmed"
        case .preparing:  return bill.orderStatus == "preparing"
        case .prepared:   return bill.orderStatus == "prepared"
        case .delivering: return bill.orderStatus == "delivering"
        case .delivered:  return bill.orderStatus == "delivered"
        case .completed:  return bill.orderStatus == "completed"
        case .cancelled:  return bill.orderStatus == "cancelled"
        }
    }
}

// MARK: - Suggestion Item (dùng cho gợi ý khi gõ)
enum OrderSuggestionItem: Identifiable, Hashable {
    case customer(name: String, phone: String)
    case product(name: String)
    case stt(code: String)
    
    var id: String {
        switch self {
        case .customer(let n, _): return "C-\(n)"
        case .product(let n):     return "P-\(n)"
        case .stt(let c):         return "S-\(c)"
        }
    }
    
    var title: String {
        switch self {
        case .customer(let n, _): return n
        case .product(let n):     return n
        case .stt(let c):         return c
        }
    }
    
    var subtitle: String {
        switch self {
        case .customer(_, let p): return "Khách hàng" + (p.isEmpty ? "" : " • \(p)")
        case .product:            return "Sản phẩm"
        case .stt:                return "Số thứ tự đơn"
        }
    }
    
    var icon: String {
        switch self {
        case .customer: return "person.crop.circle.fill"
        case .product:  return "cart.circle.fill"
        case .stt:      return "number.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .customer: return .blue
        case .product:  return .green
        case .stt:      return .orange
        }
    }
    
    var suggestedText: String {
        switch self {
        case .customer(let n, _): return n
        case .product(let n):     return n
        case .stt(let c):         return c
        }
    }
}

struct OrderHistoryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var navigateToBillId: UUID?
    @State private var selectedBill: Bill?
    @State private var highlightedBillId: UUID?
    @State private var showSoldSearch: Bool = false
    @State private var soldSearchText: String = ""
    @State private var soldStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var soldEndDate: Date = Date()
    @State private var showCustomerPicker: Bool = false
    @State private var availableCustomers: [TradingParty] = []
    @State private var isLoadingCustomers: Bool = false
    @State private var showSearchBar: Bool = false
    @State private var historySearchText: String = ""
    @State private var showInventoryReport: Bool = false
    @State private var showDeletedBills: Bool = false
    @State private var isRefreshing: Bool = false
    
    // MARK: - Search Scope + Filter
    @State private var searchScope: OrderSearchScope = .all
    @State private var showFilterSheet: Bool = false
    @State private var filters: OrderFilterCriteria = OrderFilterCriteria()
    
    // MARK: - Suggestions
    @State private var showSuggestions: Bool = false
    @State private var suggestionDebounceTask: Task<Void, Never>? = nil
    @State private var cachedCustomerNames: [(name: String, phone: String)] = []
    @State private var cachedProductNames: [String] = []
    @State private var cachedSTTs: [String] = []
    @State private var cachedStaffNames: [String] = []
    
    init(viewModel: OrderViewModel, navigateToBillId: Binding<UUID?> = .constant(nil)) {
        self.viewModel = viewModel
        self._navigateToBillId = navigateToBillId
        // Customize Navigation Bar Title Appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBackgroundLight.ignoresSafeArea()
                
                if !StoreManager.shared.hasPermission(.viewOrders) {
                    VStack(spacing: 16) {
                        // Title + Buttons
                        HStack {
                            Text("Lịch sử đơn hàng")
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Bạn không có quyền xem lịch sử đơn hàng")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Title + Buttons
                        HStack {
                            Text("Lịch sử đơn hàng")
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            Button {
                                Task {
                                    isRefreshing = true
                                    await viewModel.refreshOrders()
                                    isRefreshing = false
                                }
                            } label: {
                                if isRefreshing {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.headline)
                                }
                            }
                            .padding(.trailing, 4)
                            // Tìm kiếm sản phẩm đã bán (theo ngày)
                            Button {
                                showSoldSearch = true
                            } label: {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.headline)
                            }
                            .padding(.trailing, 4)
                            // Toggle inline search bar
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSearchBar.toggle()
                                    if !showSearchBar { historySearchText = "" }
                                }
                            } label: {
                                Image(systemName: showSearchBar ? "xmark.circle.fill" : "magnifyingglass")
                                    .font(.headline)
                                    .foregroundStyle(showSearchBar ? .gray : .primary)
                            }
                            .padding(.trailing, 8)
                            Button {
                                showDeletedBills.toggle()
                            } label: {
                                Label("Lịch sử xoá", systemImage: showDeletedBills ? "trash.fill" : "trash")
                                    .foregroundColor(showDeletedBills ? .red : .gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // Inline search bar + Scope + Filter + Suggestions
                        if showSearchBar {
                            VStack(spacing: 6) {
                                // Search Scope Picker (chip style)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(OrderSearchScope.allCases) { scope in
                                            Button {
                                                searchScope = scope
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: scope.icon)
                                                        .font(.caption2)
                                                    Text(scope.rawValue)
                                                        .font(.caption)
                                                        .fontWeight(searchScope == scope ? .bold : .medium)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule().fill(searchScope == scope
                                                        ? Color.themePrimary.opacity(0.18)
                                                        : Color.gray.opacity(0.08))
                                                )
                                                .foregroundStyle(searchScope == scope
                                                    ? Color.themePrimary
                                                    : Color.gray)
                                                .overlay(
                                                    Capsule().stroke(searchScope == scope
                                                        ? Color.themePrimary.opacity(0.4)
                                                        : Color.clear, lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                                .padding(.horizontal, 4)
                                
                                // Search Field + Icons
                                HStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                                        TextField(scopePlaceholder, text: $historySearchText, onEditingChanged: { editing in
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                showSuggestions = editing && !historySearchText.isEmpty
                                            }
                                        })
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .onChange(of: historySearchText) { _ in
                                                // Debounce: hiện gợi ý sau 150ms nếu đang nhập
                                                suggestionDebounceTask?.cancel()
                                                if !historySearchText.isEmpty {
                                                    let task = Task { @MainActor in
                                                        try? await Task.sleep(nanoseconds: 150_000_000)
                                                        if !Task.isCancelled {
                                                            rebuildSuggestionCacheIfNeeded()
                                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                                showSuggestions = true
                                                            }
                                                        }
                                                    }
                                                    suggestionDebounceTask = task
                                                } else {
                                                    withAnimation(.easeInOut(duration: 0.1)) {
                                                        showSuggestions = false
                                                    }
                                                }
                                            }
                                        if !historySearchText.isEmpty {
                                            Button(action: {
                                                historySearchText = ""
                                                withAnimation { showSuggestions = false }
                                            }) {
                                                Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                    
                                    // Icon chọn khách có sẵn
                                    Button {
                                        showCustomerPicker = true
                                        if availableCustomers.isEmpty {
                                            isLoadingCustomers = true
                                            Task {
                                                let buyers = (try? await SupabaseDatabaseService().fetchTradingParties(type: "buyer")) ?? []
                                                await MainActor.run {
                                                    availableCustomers = buyers.sorted { $0.name < $1.name }
                                                    isLoadingCustomers = false
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.title3)
                                            .foregroundStyle(Color.themePrimary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Icon bộ lọc (mới thêm)
                                    Button {
                                        rebuildSuggestionCacheIfNeeded()
                                        showFilterSheet = true
                                    } label: {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(filters.hasAnyActiveFilter ? Color.orange : Color.themePrimary)
                                            if filters.hasAnyActiveFilter {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 8, height: 8)
                                                    .offset(x: 1, y: -1)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 2)
                                
                                // Suggestion Dropdown (xuất hiện khi gõ)
                                if showSuggestions {
                                    let items = currentSuggestions
                                    if !items.isEmpty {
                                        ScrollView(.vertical, showsIndicators: false) {
                                            VStack(spacing: 0) {
                                                ForEach(items.prefix(10)) { item in
                                                    Button {
                                                        historySearchText = item.suggestedText
                                                        // Tự động set scope phù hợp để filter chính xác hơn
                                                        switch item {
                                                        case .customer: searchScope = .customer
                                                        case .product:  searchScope = .product
                                                        case .stt:      searchScope = .stt
                                                        }
                                                        withAnimation { showSuggestions = false }
                                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                    } label: {
                                                        HStack(spacing: 10) {
                                                            Image(systemName: item.icon)
                                                                .font(.title3)
                                                                .foregroundStyle(item.iconColor)
                                                                .frame(width: 28, height: 28)
                                                                .background(item.iconColor.opacity(0.12))
                                                                .clipShape(Circle())
                                                            
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(item.title)
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                                    .foregroundStyle(Color.themeTextDark)
                                                                    .lineLimit(1)
                                                                Text(item.subtitle)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.gray)
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            Image(systemName: "arrow.up.left")
                                                                .font(.caption2)
                                                                .foregroundStyle(.gray.opacity(0.6))
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 9)
                                                        .background(Color.white)
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    Divider()
                                                        .padding(.leading, 50)
                                                }
                                            }
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                                        }
                                        .frame(maxHeight: 320)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                
                                // Filter summary badges (nếu có filter đang bật)
                                if filters.hasAnyActiveFilter {
                                    activeFilterBadges
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        ScrollViewReader { proxy in
                            List {
                                if sections.isEmpty {
                                    // Empty state bên trong List để refreshable luôn hoạt động
                                    Section {
                                        VStack(spacing: 16) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 60))
                                                .foregroundStyle(Color.gray.opacity(0.3))
                                            Text(showDeletedBills ? "Chưa có đơn hàng nào bị xoá" : "Chưa có đơn hàng nào")
                                                .font(.headline)
                                                .foregroundStyle(Color.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 60)
                                        .listRowBackground(Color.clear)
                                    }
                                } else {
                                    ForEach(sections, id: \.title) { section in
                                        Section(header: OrderHistorySectionHeader(title: section.title)) {
                                            ForEach(section.bills) { bill in
                                                OrderHistoryRow(
                                                    bill: bill,
                                                    viewModel: viewModel,
                                                    highlightedBillId: $highlightedBillId,
                                                    selectedBill: $selectedBill
                                                )
                                                .id(bill.id)
                                            }
                                            .onDelete { indexSet in
                                                for index in indexSet {
                                                    let bill = section.bills[index]
                                                    if showDeletedBills {
                                                        // Lịch sử xoá: chỉ owner mới được xoá hẳn
                                                        guard AuthManager.shared.currentUserProfile?.accountRole == .owner else { return }
                                                        Task { await viewModel.hardDeleteOrder(bill) }
                                                    } else {
                                                        viewModel.deleteOrder(bill)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                            .refreshable {
                                print("🔄 [OrderHistoryView] Pull-to-refresh triggered")
                                isRefreshing = true
                                await viewModel.refreshOrders()
                                isRefreshing = false
                                print("✅ [OrderHistoryView] Pull-to-refresh done, orders: \(viewModel.pastOrders.count)")
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.themeBackgroundLight)
                            .onChange(of: highlightedBillId) { billId in
                                if let billId = billId {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(billId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showInventoryReport = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Báo cáo kho")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(0.95),
                                            Color.teal.opacity(0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 54)
                                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, viewModel: viewModel)
            }
            .sheet(isPresented: $showInventoryReport) {
                InventoryReportView(viewModel: viewModel)
            }
            .onAppear {
                // Chỉ refresh lần đầu nếu chưa có data
                if viewModel.pastOrders.isEmpty {
                    Task { await viewModel.refreshOrders() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshOrderHistory"))) { _ in
                Task {
                    await viewModel.refreshOrders()
                }
            }
            .onChange(of: navigateToBillId) { billId in
                guard let billId else { return }
                if let bill = viewModel.pastOrders.first(where: { $0.id == billId }) {
                    selectedBill = bill
                    highlightedBillId = billId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        highlightedBillId = nil
                    }
                }
                navigateToBillId = nil
            }
            .sheet(isPresented: $showSoldSearch) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("Sản phẩm đã bán")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        HStack(spacing: 8) {
                            Image(systemName: "calendar").foregroundStyle(.gray)
                            DatePicker("Từ", selection: $soldStartDate, displayedComponents: .date)
                            DatePicker("Đến", selection: $soldEndDate, displayedComponents: .date)
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                            TextField("Tìm theo tên sản phẩm", text: $soldSearchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !soldSearchText.isEmpty {
                                Button(action: { soldSearchText = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        let sold = viewModel.soldProductsTotals(
                            range: .custom(start: soldStartDate, end: soldEndDate),
                            search: soldSearchText
                        )
                        List {
                            ForEach(sold, id: \.name) { item in
                                HStack {
                                    Text(item.name).font(.subheadline).foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    Text("\(item.quantity)").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .listStyle(.plain)
                    }
                    .navigationTitle("Sản phẩm đã bán")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Đóng") { showSoldSearch = false }
                        }
                    }
                    .background(Color.themeBackgroundLight)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCustomerPicker) {
                NavigationStack {
                    Group {
                        if isLoadingCustomers {
                            ProgressView("Đang tải...").frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if availableCustomers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.slash").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
                                Text("Chưa có khách hàng nào").foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(availableCustomers) { party in
                                    Button {
                                        historySearchText = party.name
                                        showCustomerPicker = false
                                        if !showSearchBar {
                                            withAnimation { showSearchBar = true }
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(party.name).font(.subheadline).fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                            if !party.phone.isEmpty {
                                                Text("SĐT: \(party.phone)").font(.caption).foregroundStyle(.gray)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                    .navigationTitle("Chọn khách hàng")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCustomerPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // MARK: - Bộ lọc nâng cao Sheet
            .sheet(isPresented: $showFilterSheet) {
                OrderHistoryFilterSheet(
                    filters: $filters,
                    availableStaffNames: cachedStaffNames,
                    onReset: {
                        filters = OrderFilterCriteria()
                    }
                )
            }
        }
    }
    
    var sections: [(title: String, bills: [Bill])] {
        let query = historySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        let baseBills = viewModel.pastOrders.filter { showDeletedBills ? $0.isDeleted : !$0.isDeleted }
        
        // Bước 1: lọc theo bộ lọc nâng cao (trạng thái thanh toán, trạng thái đơn, ngày, nhân viên)
        var afterAdvancedFilters: [Bill] = baseBills
        // Bộ lọc trạng thái thanh toán
        afterAdvancedFilters = afterAdvancedFilters.filter { filters.paymentStatus.matches($0) }
        // Bộ lọc trạng thái đơn
        afterAdvancedFilters = afterAdvancedFilters.filter { filters.orderStatus.matches($0) }
        // Bộ lọc khoảng ngày
        if filters.dateRangeEnabled {
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: filters.dateFrom)
            let endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: filters.dateTo)) ?? filters.dateTo
            afterAdvancedFilters = afterAdvancedFilters.filter { bill in
                bill.createdAt >= startDay && bill.createdAt < endDay
            }
        }
        // Bộ lọc theo nhân viên tạo đơn
        if let staff = filters.staffName, !staff.isEmpty {
            afterAdvancedFilters = afterAdvancedFilters.filter { bill in
                (bill.creatorName ?? "").smartContains(staff.lowercased())
            }
        }
        
        // Bước 2: lọc theo từ khoá tìm kiếm, phân biệt theo search scope
        let filteredBills: [Bill]
        if query.isEmpty {
            filteredBills = afterAdvancedFilters
        } else {
            filteredBills = afterAdvancedFilters.filter { bill in
                switch searchScope {
                case .all:
                    // Tất cả: khách, STT, sản phẩm, nhân viên, giá trị (nếu match số)
                    if (bill.customerName ?? "").smartContains(query) { return true }
                    if (bill.sequenceNumber ?? "").smartContains(query) { return true }
                    if bill.items.contains(where: { $0.name.smartContains(query) }) { return true }
                    if (bill.creatorName ?? "").smartContains(query) { return true }
                    // Nếu query là số: thử match theo giá trị đơn (bằng hoặc gần đúng)
                    if let num = Double(query) {
                        if bill.total == num { return true }
                        if abs(bill.total - num) <= 500 { return true }
                        let formatted = (bill.total as NSNumber).stringValue
                        if formatted.smartContains(query) { return true }
                    }
                    return false
                    
                case .stt:
                    return (bill.sequenceNumber ?? "").smartContains(query)
                    
                case .customer:
                    return (bill.customerName ?? "").smartContains(query)
                    
                case .product:
                    return bill.items.contains(where: { $0.name.smartContains(query) })
                    
                case .amount:
                    if let num = Double(query) {
                        if bill.total == num { return true }
                        if abs(bill.total - num) <= 500 { return true }
                        let formatted = (bill.total as NSNumber).stringValue
                        if formatted.smartContains(query) { return true }
                    }
                    // Cũng cho phép gõ số không dấu phẩy so sánh bằng định dạng Việt Nam
                    let noSep = query.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
                    if let num2 = Double(noSep) {
                        if bill.total == num2 { return true }
                    }
                    return false
                }
            }
        }
        
        if showDeletedBills {
            // Lịch sử xoá: group theo ngày xoá, sort theo deletedAt giảm dần (vừa xoá lên trên)
            let grouped = Dictionary(grouping: filteredBills) { bill -> Date in
                Calendar.current.startOfDay(for: bill.deletedAt ?? bill.createdAt)
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
                let bills = (grouped[date] ?? []).sorted {
                    ($0.deletedAt ?? $0.createdAt) > ($1.deletedAt ?? $1.createdAt)
                }
                return (title: title, bills: bills)
            }
        }
        
        // Lịch sử thường: group và sort theo createdAt
        let grouped = Dictionary(grouping: filteredBills) { bill -> Date in
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.currencySymbol = "₫"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    
    private func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func billItemsSummary(_ bill: Bill) -> String {
        if bill.items.count == 1 {
            return bill.items[0].name
        } else if bill.items.count == 0 {
            return "Không có sản phẩm"
        } else {
            return "\(bill.items[0].name) + \(bill.items.count - 1) sản phẩm khác"
        }
    }
    
    // MARK: - Helpers: Scope Placeholder / Suggestions / Filter Badges
    
    private var scopePlaceholder: String {
        switch searchScope {
        case .all:      return "Tìm theo KH, STT, SP, giá, nhân viên..."
        case .stt:      return "Tìm theo mã STT..."
        case .customer: return "Tìm theo tên khách hàng..."
        case .product:  return "Tìm theo tên sản phẩm..."
        case .amount:   return "Tìm theo giá trị đơn (vd: 50000)..."
        }
    }
    
    private var dateRangeBadgeText: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM"
        return "\(df.string(from: filters.dateFrom)) → \(df.string(from: filters.dateTo))"
    }
    
    /// Cache danh sách từ khoá gợi ý (dựa trên dữ liệu đơn hiện tại)
    private func rebuildSuggestionCacheIfNeeded() {
        let bills = viewModel.pastOrders.filter { !$0.isDeleted }
        
        // Khách hàng: dùng availableCustomers nếu đã load, ngoài ra bổ sung từ customerName trong đơn
        var customerSet: [(name: String, phone: String)] = []
        var addedCustomer: Set<String> = []
        // Ưu tiên danh sách TradingParty chính thức (có phone)
        for p in availableCustomers {
            if !addedCustomer.contains(p.name.lowercased()) {
                customerSet.append((name: p.name, phone: p.phone))
                addedCustomer.insert(p.name.lowercased())
            }
        }
        // Thêm những customerName trong bill chưa có trong TradingParty
        for bill in bills {
            if let name = bill.customerName, !name.isEmpty, !addedCustomer.contains(name.lowercased()) {
                customerSet.append((name: name, phone: ""))
                addedCustomer.insert(name.lowercased())
            }
        }
        cachedCustomerNames = customerSet.sorted { a, b in a.name < b.name }
        
        // Sản phẩm: lấy tên sản phẩm unique từ các đơn
        var productSet: Set<String> = []
        for bill in bills {
            for it in bill.items { productSet.insert(it.name) }
        }
        cachedProductNames = productSet.sorted()
        
        // STT: lấy sequenceNumber unique
        var sttSet: Set<String> = []
        for bill in bills { if let s = bill.sequenceNumber { sttSet.insert(s) } }
        cachedSTTs = sttSet.sorted(by: >) // Mới nhất lên đầu
        
        // Nhân viên: lấy creatorName unique
        var staffSet: Set<String> = []
        for bill in bills { if let s = bill.creatorName, !s.isEmpty { staffSet.insert(s) } }
        cachedStaffNames = staffSet.sorted()
    }
    
    /// Gợi ý hiện tại (filter theo từ khoá + scope)
    private var currentSuggestions: [OrderSuggestionItem] {
        let query = historySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        
        var results: [OrderSuggestionItem] = []
        
        // Ưu tiên scope hiện tại, nhưng nếu scope là all thì show tất cả
        switch searchScope {
        case .all, .customer:
            let matchedCustomers = cachedCustomerNames
                .filter { $0.name.lowercased().smartContains(query) }
                .prefix(5)
            results.append(contentsOf: matchedCustomers.map { .customer(name: $0.name, phone: $0.phone) })
        default: break
        }
        
        switch searchScope {
        case .all, .product:
            let matchedProducts = cachedProductNames
                .filter { $0.lowercased().smartContains(query) }
                .prefix(5)
            results.append(contentsOf: matchedProducts.map { .product(name: $0) })
        default: break
        }
        
        switch searchScope {
        case .all, .stt:
            let matchedSTT = cachedSTTs
                .filter { $0.lowercased().smartContains(query) }
                .prefix(3)
            results.append(contentsOf: matchedSTT.map { .stt(code: $0) })
        default: break
        }
        
        return results
    }
    
    /// Badge tóm tắt các filter đang bật (clickable để xoá)
    private var activeFilterBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if filters.paymentStatus != .all {
                    FilterBadgeChip(
                        label: "TT: \(filters.paymentStatus.rawValue)",
                        color: .blue,
                        onRemove: { filters.paymentStatus = .all }
                    )
                }
                if filters.orderStatus != .all {
                    FilterBadgeChip(
                        label: "Đơn: \(filters.orderStatus.rawValue)",
                        color: .purple,
                        onRemove: { filters.orderStatus = .all }
                    )
                }
                if filters.dateRangeEnabled {
                    FilterBadgeChip(
                        label: "Ngày: \(dateRangeBadgeText)",
                        color: .orange,
                        onRemove: { filters.dateRangeEnabled = false }
                    )
                }
                if let staff = filters.staffName, !staff.isEmpty {
                    FilterBadgeChip(
                        label: "NV: \(staff)",
                        color: .green,
                        onRemove: { filters.staffName = nil }
                    )
                }
                // Nút reset tất cả
                Button {
                    filters = OrderFilterCriteria()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark").font(.caption2)
                        Text("Xoá hết").font(.caption).fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(Color.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Filter Badge Chip (xoá filter nhanh)
private struct FilterBadgeChip: View {
    let label: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Bộ lọc nâng cao Sheet
private struct OrderHistoryFilterSheet: View {
    @Binding var filters: OrderFilterCriteria
    let availableStaffNames: [String]
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempPayment: PaymentStatusFilter
    @State private var tempOrderStatus: OrderStatusFilter
    @State private var tempDateEnabled: Bool
    @State private var tempDateFrom: Date
    @State private var tempDateTo: Date
    @State private var tempStaffName: String?
    @State private var showStaffPicker: Bool = false
    @State private var staffSearch: String = ""
    
    init(filters: Binding<OrderFilterCriteria>, availableStaffNames: [String], onReset: @escaping () -> Void) {
        self._filters = filters
        self.availableStaffNames = availableStaffNames
        self.onReset = onReset
        self._tempPayment = State(initialValue: filters.wrappedValue.paymentStatus)
        self._tempOrderStatus = State(initialValue: filters.wrappedValue.orderStatus)
        self._tempDateEnabled = State(initialValue: filters.wrappedValue.dateRangeEnabled)
        self._tempDateFrom = State(initialValue: filters.wrappedValue.dateFrom)
        self._tempDateTo = State(initialValue: filters.wrappedValue.dateTo)
        self._tempStaffName = State(initialValue: filters.wrappedValue.staffName)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 22) {
                    
                    // Nhóm 1: Loại tìm kiếm (Search Scope)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(icon: "magnifyingglass", title: "Loại tìm kiếm (Search Scope)", color: .blue)
                        VStack(spacing: 2) {
                            ForEach(OrderSearchScope.allCases) { scope in
                                FilterOptionRow(
                                    title: scope.rawValue,
                                    icon: scope.icon,
                                    selected: false // Scope dùng cho thanh search, ở đây chỉ làm tham khảo
                                )
                                .disabled(true)
                                .opacity(0.7)
                                if scope.id != OrderSearchScope.allCases.last?.id {
                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        
                        Text("💡 Định nghĩa từng loại xem tại thanh chip ngay trên thanh tìm kiếm.")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    
                    // Nhóm 2: Trạng thái thanh toán
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(icon: "creditcard.fill", title: "Trạng thái thanh toán", color: .green)
                        VStack(spacing: 2) {
                            ForEach(PaymentStatusFilter.allCases) { p in
                                Button {
                                    tempPayment = p
                                } label: {
                                    FilterOptionRow(
                                        title: p.rawValue,
                                        icon: paymentIcon(p),
                                        selected: tempPayment == p
                                    )
                                }
                                .buttonStyle(.plain)
                                if p.id != PaymentStatusFilter.allCases.last?.id {
                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    
                    // Nhóm 3: Trạng thái đơn
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(icon: "bag.fill", title: "Trạng thái đơn hàng", color: .purple)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(OrderStatusFilter.allCases) { s in
                                Button {
                                    tempOrderStatus = s
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: orderStatusFilterIcon(s))
                                            .font(.caption)
                                            .foregroundStyle(tempOrderStatus == s ? .white : .purple)
                                        Text(s.rawValue)
                                            .font(.caption)
                                            .fontWeight(tempOrderStatus == s ? .bold : .medium)
                                            .foregroundStyle(tempOrderStatus == s ? .white : Color.themeTextDark)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Spacer(minLength: 0)
                                        if tempOrderStatus == s {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(tempOrderStatus == s ? Color.purple : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(tempOrderStatus == s ? Color.purple.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Nhóm 4: Khoảng ngày
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(icon: "calendar", title: "Lọc theo khoảng ngày", color: .orange)
                        Toggle(isOn: $tempDateEnabled) {
                            Text("Bật lọc theo ngày")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .tint(.orange)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                        )
                        
                        if tempDateEnabled {
                            VStack(spacing: 10) {
                                DatePicker(selection: $tempDateFrom, in: ...tempDateTo, displayedComponents: .date) {
                                    Text("Từ ngày").font(.subheadline).foregroundStyle(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                )
                                
                                DatePicker(selection: $tempDateTo, in: tempDateFrom..., displayedComponents: .date) {
                                    Text("Đến ngày").font(.subheadline).foregroundStyle(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Nhóm 5: Nhân viên (người tạo đơn)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(icon: "person.2.fill", title: "Theo nhân viên tạo đơn", color: .teal)
                        VStack(spacing: 8) {
                            if let staff = tempStaffName, !staff.isEmpty {
                                HStack {
                                    Label(staff, systemImage: "person.crop.circle.fill")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.teal)
                                    Spacer()
                                    Button {
                                        tempStaffName = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(12)
                                .background(Color.teal.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.teal.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            
                            Button {
                                showStaffPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(Color.teal)
                                    Text(tempStaffName == nil ? "Chọn nhân viên..." : "Đổi nhân viên khác")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Footer: khoảng trống
                    Color.clear.frame(height: 10)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Bộ lọc đơn hàng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Huỷ").foregroundStyle(.gray)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onReset()
                    } label: {
                        Text("Đặt lại")
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        // Áp dụng filter
                        filters.paymentStatus = tempPayment
                        filters.orderStatus = tempOrderStatus
                        filters.dateRangeEnabled = tempDateEnabled
                        filters.dateFrom = tempDateFrom
                        filters.dateTo = tempDateTo
                        filters.staffName = tempStaffName
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Áp dụng bộ lọc")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.themePrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.themePrimary.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
            }
            .sheet(isPresented: $showStaffPicker) {
                NavigationStack {
                    VStack(spacing: 0) {
                        // Search NV
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                            TextField("Tìm nhân viên...", text: $staffSearch)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !staffSearch.isEmpty {
                                Button { staffSearch = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        List {
                            Section {
                                Button {
                                    tempStaffName = nil
                                    showStaffPicker = false
                                } label: {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.xmark")
                                            .foregroundStyle(.red)
                                        Text("Tất cả nhân viên")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.themeTextDark)
                                        Spacer()
                                        if tempStaffName == nil {
                                            Image(systemName: "checkmark").foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Section(header: Text("Nhân viên").font(.caption).foregroundStyle(.gray)) {
                                let filteredStaff = availableStaffNames.filter { name in
                                    staffSearch.isEmpty || name.lowercased().contains(staffSearch.lowercased())
                                }
                                if filteredStaff.isEmpty {
                                    Label("Chưa có nhân viên nào trong dữ liệu đơn", systemImage: "person.slash")
                                        .foregroundStyle(.gray)
                                        .font(.caption)
                                }
                                ForEach(filteredStaff, id: \.self) { name in
                                    Button {
                                        tempStaffName = name
                                        showStaffPicker = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.crop.circle.fill")
                                                .foregroundStyle(.teal)
                                            Text(name)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.themeTextDark)
                                            Spacer()
                                            if tempStaffName == name {
                                                Image(systemName: "checkmark").foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                    .background(Color.themeBackgroundLight)
                    .navigationTitle("Chọn nhân viên")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showStaffPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func paymentIcon(_ p: PaymentStatusFilter) -> String {
        switch p {
        case .all:       return "creditcard.and.123"
        case .paidFull:  return "checkmark.seal.fill"
        case .partial:   return "exclamationmark.bubble.fill"
        case .unpaid:    return "xmark.seal.fill"
        }
    }
    
    private func orderStatusFilterIcon(_ s: OrderStatusFilter) -> String {
        switch s {
        case .all:        return "square.grid.2x2"
        case .confirmed:  return "checkmark.circle.fill"
        case .preparing:  return "bag.fill"
        case .prepared:   return "shippingbox.fill"
        case .delivering: return "figure.walk"
        case .delivered:  return "bicycle"
        case .completed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }
}

private struct SectionLabel: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
        }
    }
}

private struct FilterOptionRow: View {
    let title: String
    let icon: String
    var selected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(selected ? Color.green.opacity(0.12) : Color.gray.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(selected ? .green : .gray)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.themeTextDark)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .font(.title3)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct OrderHistorySectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(Color.gray)
            .padding(.vertical, 4)
    }
}

private struct OrderHistoryRow: View {
    let bill: Bill
    let viewModel: OrderViewModel
    @Binding var highlightedBillId: UUID?
    @Binding var selectedBill: Bill?
    
    var body: some View {
        Button(action: { selectedBill = bill }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(formatTime(bill.createdAt))
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                        
                        if let stt = bill.sequenceNumber {
                            Text("• \(stt)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    
                    Text(billItemsSummary(bill))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.themeTextDark)
                        .lineLimit(1)
                    
                    if let creator = bill.creatorName {
                        Text("Người tạo: \(creator)")
                            .font(.caption2)
                            .foregroundStyle(Color.gray)
                    }
                    if let customer = bill.customerName, !customer.isEmpty {
                        Text("Khách: \(customer)")
                            .font(.caption2)
                            .foregroundStyle(Color.gray)
                    }
                    if viewModel.hasHistory(for: bill.id) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("Đã chỉnh sửa")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if bill.isDeleted {
                        Text("Đã xoá")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    Text(formatCurrency(bill.total))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(bill.paymentStatus == .unpaid ? Color.red : Color.themePrimary)
                    
                    // Badge trạng thái thanh toán 3 mức
                    let ps = bill.paymentStatus
                    switch ps {
                    case .paidFull:
                        // Không hiện badge — màu xanh của tổng tiền đã đủ
                        EmptyView()
                    case .paidPartial:
                        HStack(spacing: 3) {
                            Image(systemName: ps.icon).font(.caption2)
                            Text(ps.label).font(.caption2).fontWeight(.bold)
                        }
                        .foregroundStyle(ps.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ps.color.opacity(0.12))
                        .cornerRadius(4)
                        if let debt = bill.debtAmount, debt > 0 {
                            Text("Còn: \(formatCurrency(debt))")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    case .unpaid:
                        HStack(spacing: 3) {
                            Image(systemName: ps.icon).font(.caption2)
                            Text(ps.label).font(.caption2).fontWeight(.bold)
                        }
                        .foregroundStyle(ps.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ps.color.opacity(0.12))
                        .cornerRadius(4)
                    }
                    if let expectedDate = bill.expectedPayDate {
                        Text("Đến hạn: \(formatDateOnly(expectedDate))")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    if let status = bill.orderStatus {
                        let info = orderStatusInfo(status)
                        HStack(spacing: 3) {
                            Image(systemName: info.icon)
                                .font(.caption2)
                            Text(info.label)
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(info.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(info.color.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(rowBackground)
        .opacity(bill.isDeleted ? 0.6 : 1)
        .contextMenu {
            Button {
                viewModel.startEditing(bill)
            } label: {
                Label("Sửa", systemImage: "pencil")
            }
            if !bill.isDeleted {
                Button(role: .destructive) {
                    viewModel.deleteOrder(bill)
                } label: {
                    Label("Xóa", systemImage: "trash")
                }
            } else if AuthManager.shared.currentUserProfile?.accountRole == .owner {
                Button(role: .destructive) {
                    Task { await viewModel.hardDeleteOrder(bill) }
                } label: {
                    Label("Xoá hẳn", systemImage: "trash.fill")
                }
            }
        }
    }
    
    private var rowBackground: Color {
        highlightedBillId == bill.id
            ? Color.themePrimary.opacity(0.08)
            : Color.white
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.currencySymbol = "₫"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₫"
    }
    
    private func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func billItemsSummary(_ bill: Bill) -> String {
        if bill.items.count == 1 {
            return bill.items[0].name
        } else if bill.items.count == 0 {
            return "Không có sản phẩm"
        } else {
            return "\(bill.items[0].name) + \(bill.items.count - 1) sản phẩm khác"
        }
    }
    
    private func orderStatusInfo(_ status: String) -> (label: String, icon: String, color: Color) {
        switch status {
        case "confirmed": return ("Xác nhận đơn", "checkmark.circle.fill", .blue)
        case "preparing":  return ("Chuẩn bị hàng",  "bag.fill",             .purple)
        case "prepared":   return ("Đã soạn hàng",   "shippingbox.fill",     .orange)
        case "delivering": return ("Đang giao hàng", "figure.walk",          Color(red: 0.0, green: 0.6, blue: 1.0))
        case "delivered":  return ("Đã giao hàng",   "bicycle",              Color(red: 0.2, green: 0.6, blue: 1.0))
        case "completed":  return ("Hoàn thành",      "checkmark.seal.fill", .green)
        case "cancelled":  return ("Đã Huỷ",          "xmark.circle.fill",   .red)
        default:           return (status,             "circle.dotted",       .gray)
        }
    }
}
