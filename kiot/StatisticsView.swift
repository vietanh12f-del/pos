import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: OrderViewModel
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
    
    enum StatType {
        case today, week, month, quarter
    }
    
    init(viewModel: OrderViewModel) {
        self.viewModel = viewModel
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
                    Button {
                        let range = currentRange()
                        if let url = viewModel.exportFinancialReport(range: range) {
                            exportURL = url
                            let exists = FileManager.default.fileExists(atPath: url.path)
                            if exists {
                                showExportSheet = true
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showExportSheet = true
                                }
                            }
                        }
                    } label: {
                        Text("Xuất báo cáo")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themePrimary)
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
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Doanh thu", value: formatCurrency(totalRevenue), icon: "arrow.down.left", trend: "", isPositive: true)
                        StatCard(title: "Giá vốn", value: formatCurrency(totalCOGS), icon: "arrow.up.right", trend: "", isPositive: false)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Chi phí vận hành", value: formatCurrency(totalOpEx), icon: "arrow.up.right", trend: "", isPositive: false)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Lợi nhuận ròng")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                            Spacer()
                            Text(formatCurrency(totalNet))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(totalNet >= 0 ? .green : .red)
                        }
                        .padding(.horizontal)
                        
                        ForEach(stats) { s in
                            StatisticsRow(stat: s)
                                .padding(.horizontal)
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
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                } else {
                    Text("Vui lòng tải lại")
                        .padding()
                }
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
            }
            }
        .onAppear {
            regenerate()
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
                valueBox(title: "Giá vốn", value: stat.cogs, color: .red)
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
