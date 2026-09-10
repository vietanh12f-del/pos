import SwiftUI
import Charts

struct StatisticsExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct StatisticsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedTab: Int
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var quickRange: QuickRange = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false
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
    @State private var showDebtDetail = false
    @State private var showTopProductsDetail = false
    
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
            let f3 = DateFormatter()
            f3.locale = Locale(identifier: "vi_VN")
            f3.dateFormat = "dd/MM/yyyy"
            return "\(f3.string(from: customStart)) – \(f3.string(from: customEnd))"
        }
    }
    
    init(viewModel: OrderViewModel, selectedTab: Binding<Int>) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
    }
    
    private var timeRangeSelector: some View {
        VStack(spacing: 12) {
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

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(rangeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
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
            .padding(.horizontal, 16)
            .onChange(of: quickRange) { _ in regenerate() }
            .onChange(of: customStart) { _ in
                if quickRange == .custom { regenerate() }
            }
            .onChange(of: customEnd) { _ in
                if quickRange == .custom { regenerate() }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.themeBackgroundLight)
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
                
                timeRangeSelector
                Divider()

                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                    
                    let totalRevenue = stats.reduce(0) { $0 + $1.revenue }
                    let totalCOGS = stats.reduce(0) { $0 + $1.cogs }
                    let totalOpEx = stats.reduce(0) { $0 + $1.operatingCosts }
                    let totalFees = stats.reduce(0) { $0 + $1.incurredFees }
                    let totalNet = stats.reduce(0) { $0 + $1.netProfit }
                    
                    // Tính toán thông tin thu nợ
                    let retailOrders = getRetailOrdersInCurrentRange()
                    let totalActualReceived = retailOrders.reduce(0.0) { total, order in
                        if order.isPaid {
                            return total + (order.paidAmount ?? order.total)
                        } else {
                            return total + (order.paidAmount ?? 0)
                        }
                    }
                    let totalDebt = retailOrders.reduce(0.0) { total, order in
                        total + order.effectiveDebt
                    }
                    
                    Color.clear.frame(height: 0).id("page-top")

                    // ── BÁN LẺ ──────────────────────────────────────────
                    sectionHeader("🛒 Bán lẻ (POS)")

                    HStack(spacing: 12) {
                        StatCard(title: "Doanh thu bán hàng", value: formatCurrency(totalRevenue), icon: "arrow.down.left", trend: "", isPositive: true,
                            info: "Giá trị bán hàng trong kỳ, gồm cả phần chưa thu; không bao gồm phí thu hộ.")
                        
                        StatCard(title: "Thực thu", value: formatCurrency(totalActualReceived), icon: "checkmark.circle", trend: "", isPositive: true,
                            info: "Tổng tiền đã nhận trên các đơn trong kỳ, bao gồm phần phí thu hộ.")
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        if AuthManager.shared.canViewCostPrice {
                            StatCard(title: "Giá vốn", value: formatCurrency(totalCOGS), icon: "arrow.up.right", trend: "", isPositive: false,
                                     info: "Giá vốn hàng đã bán trong kỳ, theo giá lưu tại thời điểm bán.")
                        }
                        StatCard(title: "Công nợ", value: formatCurrency(totalDebt), icon: "clock", trend: "", isPositive: false,
                                 info: "Số tiền còn phải thu trên các đơn trong kỳ.")
                    }.padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        let shopFees = retailOrders.reduce(0) { $0 + $1.shopFeeTotal }
                        StatCard(title: "Phí shop chịu", value: formatCurrency(shopFees), icon: "truck.box", trend: "", isPositive: false,
                                 info: "Phí shop chịu của các đơn trong kỳ, trừ một lần khỏi lợi nhuận; không cộng vào tiền khách trả.")
                        StatCard(title: "Doanh thu sau phí", value: formatCurrency(totalRevenue - shopFees), icon: "banknote", trend: "", isPositive: true,
                                 info: "Doanh thu bán hàng trừ phí shop chịu. Phí thu hộ không tính vào doanh thu bán hàng.")
                    }.padding(.horizontal)
                    
                    // Tính lợi nhuận ròng dựa trên thực thu
                    let actualNetProfit = totalActualReceived - totalCOGS - totalOpEx - retailOrders.reduce(0) { $0 + $1.shopFeeTotal + $1.receivedCustomerFees }
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button { selectedTab = 4 } label: {
                                StatCard(title: "Chi phí vận hành", value: formatCurrency(totalOpEx), icon: "arrow.up.right", trend: "", isPositive: false,
                                         info: "Chi phí vận hành đã nhập trong kỳ; không tính lại phí shop chịu hoặc tiền hoàn ứng.")
                            }.buttonStyle(.plain)
                            if AuthManager.shared.canViewCostPrice {
                                StatCard(title: "Lợi nhuận ròng", value: formatCurrency(actualNetProfit), icon: "chart.line.uptrend.xyaxis", trend: "", isPositive: actualNetProfit >= 0,
                                         info: "Thực thu trừ phí thu hộ đã thu, giá vốn, phí shop chịu và chi phí vận hành. Phí thu hộ khi trả một phần được phân bổ theo tỷ lệ thanh toán.")
                            }
                        }.padding(.horizontal)
                        let chartRange = FinancialReportService.shared.getDateRange(activeRange)
                        BusinessTrendChart(buckets: FinancialTrendBuilder.buckets(orders: viewModel.pastOrders, expenses: viewModel.operatingExpenses, start: chartRange.0, end: chartRange.1))
                            .padding(.horizontal)
                    if StoreManager.shared.currentMember?.role == .owner {
                        PendingEmployeeAdvanceCard(viewModel: viewModel).padding(.horizontal)
                    }
                    // Button công nợ (nếu có)
                    if totalDebt > 0 {
                        let debtCustomers = Set(retailOrders.filter { $0.effectiveDebt > 0 }.compactMap { $0.customerName }).count
                        let overdueOrders = retailOrders.filter { order in
                            guard let expectedDate = order.expectedPayDate, order.effectiveDebt > 0 else { return false }
                            return expectedDate < Date()
                        }.count

                        Button {
                            showDebtDetail = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.text.rectangle")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Danh sách công nợ")
                                    Text("\(debtCustomers) khách hàng\(overdueOrders > 0 ? " · \(overdueOrders) quá hạn" : "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(totalDebt)).fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary.opacity(0.07))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .sheet(isPresented: $showDebtDetail) {
                            DebtListView(
                                orders: getRetailOrdersInCurrentRange(),
                                dateRange: getDateRangeString()
                            )
                        }
                    }

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
                    let totalCombined = actualNetProfit + (ws.paid - ws.materialCost)
                    sectionHeader("📊 Tổng hợp")

                    VStack(spacing: 10) {
                        HStack {
                            Text("Lợi nhuận bán lẻ")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(actualNetProfit))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(actualNetProfit >= 0 ? .green : .red)
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
                                    Text("Tổng lợi nhuận ròng = Lợi nhuận bán lẻ + Lợi nhuận bán sỉ\n\nBán lẻ: Thực thu − Phí thu hộ đã thu − Giá vốn − Phí shop chịu − Chi phí vận hành\nBán sỉ: Đã thu − Chi phí nguyên liệu\n\nLưu ý: Công nợ chưa thu không được tính vào lợi nhuận ròng.")
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
                    
                    // Top sản phẩm bán chạy
                    let topProducts = getTopSellingProducts(orders: retailOrders, limit: 5)
                    Group {
                        VStack(spacing: 12) {
                            sectionHeader("🔥 Top sản phẩm bán chạy")
                            
                            VStack(spacing: 8) {
                                ForEach(Array(topProducts.enumerated()), id: \.element.id) { index, product in
                                    TopSellingProductMiniRow(
                                        product: product, 
                                        rank: index + 1
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            Button {
                                showTopProductsDetail = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Xem tất cả sản phẩm bán chạy")
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
                            .sheet(isPresented: $showTopProductsDetail) {
                                TopSellingProductsView(
                                    orders: viewModel.pastOrders
                                )
                            }
                        }
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
            }
        }
        .onAppear {
            regenerate()
            Task { await loadProductionTx() }
        }
        .onChange(of: viewModel.pastOrders) { _ in regenerate() }
        .onChange(of: viewModel.operatingExpenses) { _ in regenerate() }
        .onChange(of: viewModel.restockHistory) { _ in regenerate() }
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
        activeRange
    }
    
    private func regenerate() {
        stats = FinancialReportService.shared.generateReport(
            orders: viewModel.pastOrders,
            expenses: viewModel.operatingExpenses,
            restocks: viewModel.restockHistory,
            range: activeRange
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

    private func getRetailOrdersInCurrentRange() -> [Bill] {
        let range = currentRange()
        let (startDate, endDate) = FinancialReportService.shared.getDateRange(range)
        
        return viewModel.pastOrders.filter { order in
            !order.isDeleted &&
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
    
    private func getTopSellingProducts(orders: [Bill], limit: Int) -> [TopSellingProduct] {
        Array(TopSellingProduct.summarize(orders).prefix(limit))
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
                Text(formatCurrency(stat.actualNetProfit))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(stat.actualNetProfit >= 0 ? .green : .red)
            }
            
            VStack(spacing: 6) {
                // Hàng đầu: Doanh thu và Thực thu
                HStack(spacing: 12) {
                    valueBox(title: "Doanh thu bán hàng", value: stat.revenue, color: .blue)
                    valueBox(title: "Thực thu", value: stat.actualReceived, color: .green)
                    if stat.debt > 0 {
                        valueBox(title: "Công nợ", value: stat.debt, color: .red)
                    }
                }
                
                // Hàng thứ hai: Chi phí
                HStack(spacing: 12) {
                    if AuthManager.shared.canViewCostPrice {
                        valueBox(title: "Giá vốn", value: stat.cogs, color: .red)
                    }
                    valueBox(title: "Chi phí vận hành", value: stat.operatingCosts, color: .orange)
                    if !AuthManager.shared.canViewCostPrice || stat.debt == 0 {
                        // Thêm spacer để cân bằng layout
                        Spacer()
                    }
                }
                HStack(spacing: 12) {
                    valueBox(title: "Phí shop chịu", value: stat.shopFees, color: .orange)
                    valueBox(title: "Doanh thu sau phí", value: stat.revenue - stat.shopFees, color: .blue)
                }
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

struct TopSellingProductMiniRow: View {
    let product: TopSellingProduct
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Ranking
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())
            
            // Thông tin sản phẩm
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.themeTextDark)
                    .lineLimit(1)
                
                if !product.category.isEmpty {
                    Text(product.category)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            // Số lượng và doanh thu
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(product.quantitySold)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                    Text("SP")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                
                Text(formatCurrency(product.revenue))
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}// Calendar-based buckets keep empty intervals and preserve the same totals as the cards.
struct FinancialTrendBucket: Identifiable {
    let start: Date
    let end: Date
    var id: Date { start }
    var revenue = 0.0
    var received = 0.0
    var profit = 0.0
}

enum FinancialTrendBuilder {
    static func buckets(orders: [Bill], expenses: [OperatingExpense], start: Date, end: Date, calendar: Calendar = .current) -> [FinancialTrendBucket] {
        guard end >= start else { return [] }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
        let component: Calendar.Component = days == 0 ? .hour : days <= 62 ? .day : days <= 366 ? .weekOfYear : .month
        var result: [FinancialTrendBucket] = []
        var cursor = start
        while cursor <= end {
            guard let interval = calendar.dateInterval(of: component, for: cursor), interval.end > cursor else { break }
            result.append(FinancialTrendBucket(start: cursor, end: min(interval.end, end.addingTimeInterval(0.001))))
            cursor = interval.end
        }
        for order in orders where !order.isDeleted && order.createdAt >= start && order.createdAt <= end {
            guard let i = result.firstIndex(where: { order.createdAt >= $0.start && order.createdAt < $0.end }) else { continue }
            let received = order.paidAmount ?? (order.isPaid ? order.total : 0)
            result[i].revenue += order.salesRevenue
            result[i].received += received
            result[i].profit += received - order.receivedCustomerFees - order.totalCost - order.shopFeeTotal
        }
        for expense in expenses where expense.createdAt >= start && expense.createdAt <= end {
            if let i = result.firstIndex(where: { expense.createdAt >= $0.start && expense.createdAt < $0.end }) {
                result[i].profit -= expense.amount
            }
        }
        return result
    }
}

struct BusinessTrendChart: View {
    let buckets: [FinancialTrendBucket]
    @ObservedObject private var auth = AuthManager.shared
    @State private var metric = Metric.revenue
    @State private var selected: Date?
    private enum Metric: String, CaseIterable {
        case revenue = "Doanh thu", received = "Thực thu", profit = "Lợi nhuận"
        func value(_ bucket: FinancialTrendBucket) -> Double {
            switch self { case .revenue: return bucket.revenue; case .received: return bucket.received; case .profit: return bucket.profit }
        }
    }
    private var selectedBucket: FinancialTrendBucket? { buckets.first { $0.start == selected } }
    private var hours: Bool { guard let a = buckets.first, let b = buckets.last else { return false }; return Calendar.current.isDate(a.start, inSameDayAs: b.start) }
    private func label(_ bucket: FinancialTrendBucket) -> String {
        if hours { return bucket.start.formatted(.dateTime.hour().minute()) }
        let date = bucket.start.formatted(.dateTime.day().month())
        if bucket.end.timeIntervalSince(bucket.start) > 86401 {
            return "\(date) – \(bucket.end.addingTimeInterval(-1).formatted(.dateTime.day().month()))"
        }
        return date
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Xu hướng kinh doanh").font(.headline)
            Picker("Chỉ số", selection: $metric) {
                ForEach(Metric.allCases.filter { $0 != .profit || auth.canViewCostPrice }, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            .onChange(of: metric) { _ in selected = nil }
            if let bucket = selectedBucket {
                Text("\(label(bucket)): \(formatCurrency(metric.value(bucket)))")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("\(metric == .revenue ? "Doanh thu bán hàng" : metric.rawValue) · Chạm cột để xem số tiền")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Chart {
                RuleMark(y: .value("Mốc 0", 0)).foregroundStyle(Color.gray.opacity(0.4))
                ForEach(buckets) { bucket in
                    BarMark(xStart: .value("Từ", bucket.start), xEnd: .value("Đến", bucket.end), y: .value("Số tiền", metric.value(bucket)))
                        .foregroundStyle(metric.value(bucket) < 0 ? Color.red : Color.themePrimary)
                        .opacity(selected == nil || selected == bucket.start ? 1 : 0.35)
                        .accessibilityLabel(label(bucket))
                        .accessibilityValue(formatCurrency(metric.value(bucket)))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(hours ? date.formatted(.dateTime.hour()) : date.formatted(.dateTime.day().month()))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel { if let n = value.as(Double.self) { Text(n.formatted(.number.notation(.compactName))) } }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { event in
                            let frame = geometry[proxy.plotAreaFrame]
                            guard frame.contains(event.location), let date: Date = proxy.value(atX: event.location.x - frame.minX) else { return }
                            selected = buckets.first(where: { date >= $0.start && date < $0.end })?.start
                        })
                }
            }
            .frame(height: 220)
            Text("Đơn vị: đồng. Theo ngày tạo đơn; lợi nhuận tính theo thực thu, đã trừ giá vốn, phí shop chịu, phần phí thu hộ đã thu và chi phí vận hành.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding().background(Color.white).cornerRadius(12)
        .onChange(of: buckets.map(\.start)) { _ in selected = nil }
        .onChange(of: auth.canViewCostPrice) { allowed in if !allowed { metric = .revenue } }
    }
}
