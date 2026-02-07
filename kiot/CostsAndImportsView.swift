import SwiftUI

struct CostsAndImportsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedSubTab: Int // 0: Vận hành, 1: Phát sinh
    
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    
    private func exportReport(_ range: ReportDateRange) {
        if let url = viewModel.exportFinancialReport(range: range) {
            self.exportURL = url
            self.showExportSheet = true
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("CHI PHÍ & NHẬP HÀNG")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    
                    Menu {
                        Button("Hôm nay") { exportReport(.today) }
                        Button("Tuần này") { exportReport(.thisWeek) }
                        Button("Tháng này") { exportReport(.thisMonth) }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .padding()
                .background(Color.white)
                
                // Custom Segmented Control
                HStack(spacing: 0) {
                    CostsTabButton(title: "Vận hành", isSelected: selectedSubTab == 0) { selectedSubTab = 0 }
                    CostsTabButton(title: "Phát sinh", isSelected: selectedSubTab == 1) { selectedSubTab = 1 }
                }
                .background(Color.white)
                
                // Content
                if selectedSubTab == 0 {
                    OperatingCostsList(viewModel: viewModel)
                } else {
                    ImportCostsList(viewModel: viewModel)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

// MARK: - Subviews

struct CostsTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
                
                Rectangle()
                    .fill(isSelected ? Color.themePrimary : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
    }
}

struct OperatingCostsList: View {
    @ObservedObject var viewModel: OrderViewModel
    
    var body: some View {
        List {
            if viewModel.operatingExpenses.isEmpty {
                Text("Chưa có chi phí vận hành nào.")
                    .foregroundStyle(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.operatingExpenses) { expense in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(expense.createdAt))
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(expense.amount))
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        
                        Text(expense.title)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if let note = expense.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteOperatingExpense(viewModel.operatingExpenses[index])
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct ImportCostsList: View {
    @ObservedObject var viewModel: OrderViewModel
    
    var body: some View {
        List {
            if viewModel.restockHistory.isEmpty {
                Text("Chưa có lịch sử nhập hàng.")
                    .foregroundStyle(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.restockHistory) { bill in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(bill.createdAt))
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(bill.totalCost))
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        
                        // Profit Impact Badge
                        let profitImpact = bill.items.reduce(0) { $0 + $1.additionalCost }
                        if profitImpact > 0 {
                            HStack {
                                Spacer()
                                Text("Giảm lợi nhuận: -\(formatCurrency(profitImpact))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(4)
                            }
                            .padding(.top, 2)
                        }
                        
                        Divider()
                        
                        // Itemized List
                        ForEach(bill.items) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundStyle(.gray)
                                VStack(alignment: .leading) {
                                    Text("\(item.name)")
                                        .fontWeight(.medium)
                                    Text("SL: \(item.quantity) x \(formatCurrency(item.unitPrice))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if item.additionalCost > 0 {
                                        Text("+ Chi phí khác: \(formatCurrency(item.additionalCost))")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                // No delete here for now, or add if needed (viewModel.deleteRestockBill)
            }
        }
        .listStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
