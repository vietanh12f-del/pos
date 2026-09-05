import SwiftUI

struct StatisticsExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct StatisticsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedTab: Int
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selectedType: StatType = .month
    @State private var selectedMonth = Date()
    @State private var selectedQuarter: Int
    @State private var selectedYear: Int
    @State private var stats: [DailyFinancialStats] = []
    @State private var productSearch: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var searchFocused: Bool
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    @State private var exportItem: StatisticsExportItem?
    @State private var allProductionTx: [ProductionTransaction] = []
    @State private var showRetailDetail = false
    @State private var showWholesaleDetail = false
    @State private var showWholesaleProfitInfo = false
    @State private var showRetailProfitInfo = false
    @State private var showTotalProfitInfo = false
    @State private var showWholesaleDashboardProfitInfo = false
    @State private var showInventoryValueInfo = false
    @State private var showAllOrdersDetail = false
    @State private var showInventoryDetail = false
    
    enum StatType {
        case today, week, month, quarter
    }
    
    init(viewModel: OrderViewModel, selectedTab: Binding<Int>) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
        let calendar = Calendar.current
        let date = Date()
        _selectedQuarter = State(initialValue: (calendar.component(.month, from: date) - 1) / 3 + 1)
        _selectedYear = State(initialValue: calendar.component(.year, from: date))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Thống Kê")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    // Chỉ owner mới được xuất báo cáo
                    if StoreManager.shared.currentMember?.role == .owner {
                        Button {
                            let range = currentRange()
                            let url = viewModel.exportFinancialReport(range: range, allProductionTx: allProductionTx)
                            if let url = url {
                                exportURL = url
                                exportItem = StatisticsExportItem(url: url)
                            }
                        } label: {
                            Text("Xuất báo cáo (Ảnh)")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.themePrimary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)
                Divider()
                
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                    
                    Picker("Khoảng thời gian", selection: $selectedType) {
                        Text("Hôm nay").tag(StatType.today)
                        Text("Tuần này").tag(StatType.week)
                        Text("Theo tháng").tag(StatType.month)
                        Text("Theo quý").tag(StatType.quarter)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedType) { _ in regenerate() }
                    
                    if selectedType == .month {
                        HStack {
                            Button(action: { moveMonth(-1) }) {
                                Image(systemName: "chevron.left")
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            
                            Text(monthYearString(selectedMonth))
                                .font(.headline)
                                .frame(width: 150)
                            
                            Button(action: { moveMonth(1) }) {
                                Image(systemName: "chevron.right")
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.vertical, 4)
                    } else if selectedType == .quarter {
                        HStack {
                            Button(action: { moveQuarter(-1) }) {
                                Image(systemName: "chevron.left")
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            
                            Text("Quý \(selectedQuarter)/\(String(format: "%d", selectedYear))")
                                .font(.headline)
                                .frame(width: 150)
                            
                            Button(action: { moveQuarter(1) }) {
                                Image(systemName: "chevron.right")
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    let totalRevenue = stats.reduce(0) { $0 + $1.revenue }
                    let totalCOGS = stats.reduce(0) { $0 + $1.cogs }
                    let totalOpEx = stats.reduce(0) { $0 + $1.operatingCosts }
                    let totalFees = stats.reduce(0) { $0 + $1.incurredFees }
                    let totalNet = stats.reduce(0) { $0 + $1.netProfit }
                    
                    Color.clear.frame(height: 0).id("page-top")

                    // ── BÁN LẺ ──────────────────────────────────────────
                    sectionHeader("🛒 Bán lẻ (POS)")

                    HStack(spacing: 12) {
                        StatCard(title: "Doanh thu", value: formatCurrency(totalRevenue), icon: "arrow.down.left", trend: "", isPositive: true,
                            info: "Tổng tiền thu được từ các đơn bán lẻ đã thanh toán (isPaid = true) trong kỳ.")
                        if AuthManager.shared.canViewCostPrice {
                            StatCard(title: "Giá vốn", value: formatCurrency(totalCOGS), icon: "arrow.up.right", trend: "", isPositive: false,
                                info: "Chi phí vốn hàng bán (COGS) — tính theo giá nhập bình quân (AVCO) của từng sản phẩm tại thời điểm bán.")
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button {
                            selectedTab = 4
                        } label: {
                            StatCard(title: "Chi phí vận hành", value: formatCurrency(totalOpEx), icon: "arrow.up.right", trend: "", isPositive: false,
                                info: "Tổng chi phí vận hành (OPEX) đã nhập thủ công: tiền thuê mặt bằng, lương, điện nước, v.v.")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Text("Lợi nhuận ròng")
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Button {
                                    showRetailProfitInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .alert("Lợi nhuận ròng (Bán lẻ)", isPresented: $showRetailProfitInfo) {
                                    Button("Đã hiểu", role: .cancel) {}
                                } message: {
                                    Text("Lợi nhuận ròng = Doanh thu − Giá vốn − Chi phí vận hành\n\nDoanh thu: tổng đơn đã thanh toán.\nGiá vốn (COGS): tính theo giá nhập bình quân AVCO tại thời điểm bán.\nChi phí vận hành (OPEX): các khoản chi phí nhập thủ công (thuê mặt bằng, lương, điện nước...).")
                                }
                            }
                            Spacer()
                            Text(formatCurrency(totalNet))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(totalNet >= 0 ? .green : .red)
                        }
                        .padding(.horizontal)

                        if !stats.isEmpty {
                            VStack(spacing: 12) {
                                Button {
                                    showRetailDetail = true
                                } label: {
                                    HStack {
                                        Image(systemName: "list.bullet.rectangle")
                                        Text("Chi tiết theo ngày (\(stats.count) ngày)")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.themePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary.opacity(0.07))
                                    .cornerRadius(10)
                                }
                                .sheet(isPresented: $showRetailDetail) {
                                    NavigationStack {
                                        List {
                                            ForEach(stats) { s in
                                                StatisticsRow(stat: s)
                                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                    .listRowBackground(Color.themeBackgroundLight)
                                                    .listRowSeparator(.hidden)
                                            }
                                        }
                                        .listStyle(.plain)
                                        .background(Color.themeBackgroundLight)
                                        .navigationTitle("Chi tiết bán lẻ")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .toolbar {
                                            ToolbarItem(placement: .confirmationAction) {
                                                Button("Đóng") { showRetailDetail = false }
                                            }
                                        }
                                    }
                                }
                                
                                Button {
                                    showAllOrdersDetail = true
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Chi tiết tất cả đơn hàng")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.themePrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary.opacity(0.07))
                                    .cornerRadius(10)
                                }
                                .sheet(isPresented: $showAllOrdersDetail) {
                                    AllOrdersDetailView(
                                        orders: getRetailOrdersInCurrentRange(),
                                        dateRange: getDateRangeString()
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // ── BÁN SỈ / SẢN XUẤT ───────────────────────────────
                    let ws = viewModel.wholesaleStats(for: currentRange(), allTransactions: allProductionTx)

                    if storeManager.currentStoreProductionEnabled() {

                    sectionHeader("🏭 Bán sỉ / Sản xuất")

                    HStack(spacing: 12) {
                        StatCard(title: "Doanh thu sỉ", value: formatCurrency(ws.revenue), icon: "shippingbox.fill", trend: "", isPositive: true,
                            info: "Tổng grandTotal của các phiếu Xuất Thành Phẩm có ghi nhận giá bán (grandTotal > 0). Không bao gồm hàng xuất vào kho bán lẻ.")
                        StatCard(title: "Chi phí NL", value: formatCurrency(ws.materialCost), icon: "arrow.up.right", trend: "", isPositive: false,
                            info: "Tổng chi phí nguyên liệu đã nhập (Nhập Nguyên Liệu) trong kỳ. Phản ánh chi phí đầu vào cho sản xuất.")
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        StatCard(title: "Đã thu", value: formatCurrency(ws.paid), icon: "checkmark.circle.fill", trend: "", isPositive: true,
                            info: "Tổng tiền đã thu thực tế từ khách sỉ (paidAmount) trong kỳ.")
                        StatCard(title: "Còn nợ", value: formatCurrency(ws.debt), icon: "clock.fill", trend: "", isPositive: false,
                            info: "Tổng công nợ chưa thu (debtAmount) từ các đơn bán sỉ trong kỳ. Cần theo dõi và thu hồi.")
                    }
                    .padding(.horizontal)

                    // Lợi nhuận ròng bán sỉ
                    let wsNetProfit = ws.paid - ws.materialCost
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Lợi nhuận ròng")
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Button {
                                    showWholesaleProfitInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .alert("Lợi nhuận ròng (Bán sỉ)", isPresented: $showWholesaleProfitInfo) {
                                    Button("Đã hiểu", role: .cancel) {}
                                } message: {
                                    Text("Lợi nhuận ròng = Đã thu − Chi phí nguyên liệu\n\nLưu ý: Chỉ tính trên tiền đã thu thực tế (không tính phần còn nợ). Chi phí nguyên liệu là tổng Nhập Nguyên Liệu trong cùng kỳ.")
                                }
                            }
                            Text("= Đã thu − Chi phí nguyên liệu")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text(formatCurrency(wsNetProfit))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(wsNetProfit >= 0 ? .green : .red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Lợi nhuận (giống tab Tổng quan)
                    let wsDashboardProfit = ws.revenue - ws.materialExportCost
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Lợi nhuận")
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Button {
                                    showWholesaleDashboardProfitInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .alert("Lợi nhuận (Bán sỉ - giống Tổng quan)", isPresented: $showWholesaleDashboardProfitInfo) {
                                    Button("Đã hiểu", role: .cancel) {}
                                } message: {
                                    Text("Lợi nhuận = Doanh thu sỉ − Tổng giá trị xuất nguyên liệu\n\nDoanh thu sỉ: tổng grandTotal của các phiếu Xuất Thành Phẩm.\nTổng giá trị xuất nguyên liệu: tổng giá trị các phiếu Xuất Nguyên Liệu trong cùng kỳ.")
                                }
                            }
                            Text("= Doanh thu sỉ − Tổng giá trị xuất nguyên liệu")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text(formatCurrency(wsDashboardProfit))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(wsDashboardProfit >= 0 ? .green : .red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Tổng giá trị tồn kho
                    let inventoryValue = ws.materialCost - ws.materialExportCost
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Tổng giá trị tồn kho")
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Button {
                                    showInventoryValueInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .alert("Tổng giá trị tồn kho nguyên liệu", isPresented: $showInventoryValueInfo) {
                                    Button("Đã hiểu", role: .cancel) {}
                                } message: {
                                    Text("Tổng giá trị tồn kho = Giá trị nguyên liệu nhập − Giá trị nguyên liệu đã xuất\n\nGiá trị nguyên liệu nhập: tổng các phiếu Nhập Nguyên Liệu trong kỳ.\nGiá trị nguyên liệu đã xuất: tổng các phiếu Xuất Nguyên Liệu trong kỳ.")
                                }
                            }
                            Text("= Giá trị nguyên liệu nhập − Giá trị nguyên liệu đã xuất")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text(formatCurrency(inventoryValue))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(inventoryValue >= 0 ? .blue : .red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    if ws.transactions.isEmpty {
                        Text("Không có giao dịch bán sỉ trong kỳ này")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                    } else {
                        Button {
                            showWholesaleDetail = true
                        } label: {
                            HStack {
                                Image(systemName: "shippingbox")
                                Text("Chi tiết giao dịch sỉ (\(ws.transactions.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary.opacity(0.07))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showWholesaleDetail) {
                            NavigationStack {
                                List {
                                    ForEach(ws.transactions) { tx in
                                        WholesaleRow(tx: tx)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                            .listRowBackground(Color.themeBackgroundLight)
                                            .listRowSeparator(.hidden)
                                    }
                                }
                                .listStyle(.plain)
                                .background(Color.themeBackgroundLight)
                                .navigationTitle("Chi tiết bán sỉ")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Đóng") { showWholesaleDetail = false }
                                    }
                                }
                            }
                        }
                    }

                    // ── TỔNG HỢP ────────────────────────────────────────
                    let totalCombined = totalNet + (ws.paid - ws.materialCost)
                    sectionHeader("📊 Tổng hợp")

                    VStack(spacing: 10) {
                        HStack {
                            Text("Lợi nhuận bán lẻ")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(totalNet))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(totalNet >= 0 ? .green : .red)
                        }
                        HStack {
                            Text("Lợi nhuận bán sỉ")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(ws.paid - ws.materialCost))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle((ws.paid - ws.materialCost) >= 0 ? .green : .red)
                        }
                        Divider()
                        HStack {
                            HStack(spacing: 6) {
                                Text("Tổng lợi nhuận ròng")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themeTextDark)
                                Button {
                                    showTotalProfitInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .alert("Tổng lợi nhuận ròng", isPresented: $showTotalProfitInfo) {
                                    Button("Đã hiểu", role: .cancel) {}
                                } message: {
                                    Text("Tổng lợi nhuận ròng = Lợi nhuận bán lẻ + Lợi nhuận bán sỉ\n\nBán lẻ: Doanh thu − Giá vốn − Chi phí vận hành\nBán sỉ: Đã thu − Chi phí nguyên liệu\n\nLưu ý: Phần còn nợ của bán sỉ chưa được tính vào đây.")
                                }
                            }
                            Spacer()
                            Text(formatCurrency(totalCombined))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(totalCombined >= 0 ? .green : .red)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)

                    } // end if productionEnabled

                    // Button cho danh sách tồn kho (luôn hiển thị)
                    Button {
                        showInventoryDetail = true
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("Danh sách tồn kho")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.themePrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.themePrimary.opacity(0.07))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showInventoryDetail) {
                        InventoryListView(products: viewModel.products)
                    }

                    // (Đã di chuyển phần \"Sản phẩm đã bán\" sang Lịch sử đơn hàng)
                    }
                    .padding(.bottom, keyboardHeight + 20)
                }
                }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                searchFocused = false
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            }
            .onChange(of: searchFocused) { focused in
                if focused {
                }
            }
            .onAppear {
                searchFocused = false
                keyboardHeight = 0
            }
            .onDisappear {
                searchFocused = false
                keyboardHeight = 0
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
        }
        .onAppear {
            regenerate()
            Task { await loadProductionTx() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { output in
            if let value = output.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                keyboardHeight = value.cgRectValue.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
    
    private func currentRange() -> ReportDateRange {
        switch selectedType {
        case .today:
            return .today
        case .week:
            return .thisWeek
        case .month:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: selectedMonth)
            let start = calendar.date(from: components) ?? selectedMonth
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? selectedMonth
            return .custom(start: start, end: end)
        case .quarter:
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = (selectedQuarter - 1) * 3 + 1
            components.day = 1
            let start = calendar.date(from: components) ?? Date()
            let end = calendar.date(byAdding: .month, value: 3, to: start)?.addingTimeInterval(-1) ?? Date()
            return .custom(start: start, end: end)
        }
    }
    
    private func regenerate() {
        let range: ReportDateRange
        
        switch selectedType {
        case .today:
            range = .today
        case .week:
            range = .thisWeek
        case .month:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: selectedMonth)
            let start = calendar.date(from: components) ?? selectedMonth
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? selectedMonth
            range = .custom(start: start, end: end)
        case .quarter:
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = (selectedQuarter - 1) * 3 + 1
            components.day = 1
            let start = calendar.date(from: components) ?? Date()
            let end = calendar.date(byAdding: .month, value: 3, to: start)?.addingTimeInterval(-1) ?? Date()
            range = .custom(start: start, end: end)
        }
        
        stats = FinancialReportService.shared.generateReport(
            orders: viewModel.pastOrders,
            expenses: viewModel.operatingExpenses,
            restocks: viewModel.restockHistory,
            range: range
        )
    }
    
    private func loadProductionTx() async {
        let exports = await viewModel.fetchProductionTransactions(mode: "Xuất Thành Phẩm")
        let imports = await viewModel.fetchProductionTransactions(mode: "Nhập Nguyên liệu")
        await MainActor.run { allProductionTx = exports + imports }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func moveMonth(_ value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
            regenerate()
        }
    }
    
    private func moveQuarter(_ value: Int) {
        var newQuarter = selectedQuarter + value
        var newYear = selectedYear
        
        while newQuarter > 4 {
            newQuarter -= 4
            newYear += 1
        }
        while newQuarter < 1 {
            newQuarter += 4
            newYear -= 1
        }
        
        selectedQuarter = newQuarter
        selectedYear = newYear
        regenerate()
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yyyy"
        return "Tháng " + formatter.string(from: date)
    }
    
    private func getRetailOrdersInCurrentRange() -> [Bill] {
        let range = currentRange()
        let (startDate, endDate) = FinancialReportService.shared.getDateRange(range)
        
        return viewModel.pastOrders.filter { order in
            order.isPaid && !order.isDeleted && 
            order.createdAt >= startDate && order.createdAt <= endDate
        }
    }
    
    private func getDateRangeString() -> String {
        let range = currentRange()
        let (startDate, endDate) = FinancialReportService.shared.getDateRange(range)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

struct StatisticsRow: View {
    let stat: DailyFinancialStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(stat.date))
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Text(formatCurrency(stat.netProfit))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(stat.netProfit >= 0 ? .green : .red)
            }
            
            HStack(spacing: 12) {
                valueBox(title: "Doanh thu", value: stat.revenue, color: .green)
                if AuthManager.shared.canViewCostPrice {
                    valueBox(title: "Giá vốn", value: stat.cogs, color: .red)
                }
                valueBox(title: "Chi phí vận hành", value: stat.operatingCosts, color: .orange)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    private func valueBox(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(formatCurrency(value))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WholesaleRow: View {
    let tx: ProductionTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.buyerName ?? "Khách sỉ")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    if let phone = tx.buyerPhone, !phone.isEmpty {
                        Text(phone).font(.caption).foregroundStyle(.gray)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(tx.grandTotal ?? 0))
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                    Text(formatDateShort(tx.createdAt))
                        .font(.caption2).foregroundStyle(.gray)
                }
            }

            HStack(spacing: 16) {
                if let paid = tx.paidAmount, paid > 0 {
                    Label(formatCurrency(paid), systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                if let debt = tx.debtAmount, debt > 0 {
                    Label(formatCurrency(debt), systemImage: "clock.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                // Items summary
                let names = tx.items.prefix(2).map { $0.name }.joined(separator: ", ")
                Text(names + (tx.items.count > 2 ? "..." : ""))
                    .font(.caption).foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    private func formatDateShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}
