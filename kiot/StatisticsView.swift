import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @State private var selectedRange: ReportDateRange = .thisMonth
    @State private var stats: [DailyFinancialStats] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Khoảng thời gian", selection: $selectedRange) {
                        Text("Hôm nay").tag(ReportDateRange.today)
                        Text("Tuần này").tag(ReportDateRange.thisWeek)
                        Text("Tháng này").tag(ReportDateRange.thisMonth)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedRange) { _ , _ in
                        regenerate()
                    }
                    
                    let totalRevenue = stats.reduce(0) { $0 + $1.revenue }
                    let totalCOGS = stats.reduce(0) { $0 + $1.cogs }
                    let totalOpEx = stats.reduce(0) { $0 + $1.operatingCosts }
                    let totalFees = stats.reduce(0) { $0 + $1.incurredFees }
                    let totalNet = stats.reduce(0) { $0 + $1.netProfit }
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Doanh thu", value: formatCurrency(totalRevenue), icon: "arrow.down.left", trend: "", isPositive: true)
                        StatCard(title: "Giá vốn", value: formatCurrency(totalCOGS), icon: "arrow.up.right", trend: "", isPositive: false)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Chi phí", value: formatCurrency(totalOpEx), icon: "arrow.up.right", trend: "", isPositive: false)
                        StatCard(title: "Phát sinh", value: formatCurrency(totalFees), icon: "arrow.up.right", trend: "", isPositive: false)
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
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Thống kê")
        }
        .onAppear {
            regenerate()
        }
    }
    
    private func regenerate() {
        stats = FinancialReportService.shared.generateReport(
            orders: viewModel.pastOrders,
            expenses: viewModel.operatingExpenses,
            restocks: viewModel.restockHistory,
            range: selectedRange
        )
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
                valueBox(title: "Chi phí", value: stat.operatingCosts, color: .orange)
                valueBox(title: "Phát sinh", value: stat.incurredFees, color: .pink)
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

