import SwiftUI

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

                        // Inline search bar
                        if showSearchBar {
                            HStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                                    TextField("Tìm theo tên KH, sản phẩm, STT...", text: $historySearchText)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                    if !historySearchText.isEmpty {
                                        Button(action: { historySearchText = "" }) {
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
        }
    }
    
    var sections: [(title: String, bills: [Bill])] {
        let query = historySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        let baseBills = viewModel.pastOrders.filter { showDeletedBills ? $0.isDeleted : !$0.isDeleted }
        let filteredBills: [Bill]
        if query.isEmpty {
            filteredBills = baseBills
        } else {
            filteredBills = baseBills.filter { bill in
                // Tìm theo tên khách hàng
                if (bill.customerName ?? "").lowercased().contains(query) { return true }
                // Tìm theo STT
                if (bill.sequenceNumber ?? "").lowercased().contains(query) { return true }
                // Tìm theo tên sản phẩm trong đơn
                if bill.items.contains(where: { $0.name.lowercased().contains(query) }) { return true }
                return false
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
