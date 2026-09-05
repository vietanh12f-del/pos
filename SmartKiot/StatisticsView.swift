import SwiftUI

struct StatisticsExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct StatisticsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedTab: Int
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var quickRange: QuickRange = .today
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
                        StatCard(title: "Doanh thu", value: formatCurrency(totalRevenue), icon: "arrow.down.left", trend: "", isPositive: true,
                            info: "Tổng giá trị các đơn hàng bán lẻ trong kỳ (bao gồm cả phần chưa thu).")
                        
                        StatCard(title: "Thực thu", value: formatCurrency(totalActualReceived), icon: "checkmark.circle", trend: "", isPositive: true,
                            info: "Tổng số tiền thực tế đã thu được từ khách hàng.")
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        if totalDebt > 0 {
                            StatCard(title: "Công nợ", value: formatCurrency(totalDebt), icon: "clock", trend: "", isPositive: false,
                                info: "Tổng số tiền khách hàng còn nợ chưa thanh toán.")
                        }
                        
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
                    
                    // Tính lợi nhuận ròng dựa trên thực thu
                    let actualNetProfit = totalActualReceived - totalCOGS - totalOpEx
                    
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
                                    Text("Lợi nhuận ròng = Thực thu − Giá vốn − Chi phí vận hành\n\nThực thu: số tiền thực tế đã nhận từ khách hàng.\nGiá vốn (COGS): tính theo giá nhập bình quân AVCO tại thời điểm bán.\nChi phí vận hành (OPEX): các khoản chi phí nhập thủ công (thuê mặt bằng, lương, điện nước...).\n\nLưu ý: Công nợ chưa thu không được tính vào lợi nhuận ròng.")
                                }
                            }
                            Spacer()
                            Text(formatCurrency(actualNetProfit))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(actualNetProfit >= 0 ? .green : .red)
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
                                    Text("Tổng lợi nhuận ròng = Lợi nhuận bán lẻ + Lợi nhuận bán sỉ\n\nBán lẻ: Thực thu − Giá vốn − Chi phí vận hành\nBán sỉ: Đã thu − Chi phí nguyên liệu\n\nLưu ý: Công nợ chưa thu không được tính vào lợi nhuận ròng.")
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
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Danh sách công nợ")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.themeTextDark)
                                        
                                        HStack(spacing: 12) {
                                            Text("\(debtCustomers) khách hàng")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                            
                                            if overdueOrders > 0 {
                                                Text("• \(overdueOrders) quá hạn")
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatCurrency(totalDebt))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.red)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.red.opacity(0.03))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
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
                    if !topProducts.isEmpty {
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
                                    orders: retailOrders,
                                    dateRange: getDateRangeString()
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
        var productStats: [String: (quantity: Int, revenue: Double, prices: [Double])] = [:]
        
        // Tính toán thống kê cho từng sản phẩm
        for order in orders {
            if !order.isDeleted {
                for item in order.items {
                    let key = item.name
                    let current = productStats[key] ?? (quantity: 0, revenue: 0, prices: [])
                    
                    productStats[key] = (
                        quantity: current.quantity + item.quantity,
                        revenue: current.revenue + (Double(item.quantity) * item.price),
                        prices: current.prices + [item.price]
                    )
                }
            }
        }
        
        // Chuyển đổi thành TopSellingProduct và sắp xếp
        let products = productStats.compactMap { (productName, stats) in
            let avgPrice = stats.prices.isEmpty ? 0 : stats.prices.reduce(0, +) / Double(stats.prices.count)
            
            return TopSellingProduct(
                name: productName,
                quantitySold: stats.quantity,
                revenue: stats.revenue,
                category: "",
                averagePrice: avgPrice
            )
        }
        
        return Array(products.sorted { $0.quantitySold > $1.quantitySold }.prefix(limit))
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
                    valueBox(title: "Doanh thu", value: stat.revenue, color: .blue)
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
}