import SwiftUI

struct CostsAndImportsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedSubTab: Int // 0: Vận hành, 1: Phát sinh
    @Binding var showNewOperatingExpense: Bool
    @ObservedObject private var storeManager = StoreManager.shared
    
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    
    private func exportReport(_ range: ReportDateRange) {
        if let url = viewModel.exportFinancialReport(range: range) {
            self.exportURL = url
            self.showExportSheet = true
        }
    }
    
    private var canViewOperatingCosts: Bool {
        storeManager.hasPermission(.viewExpenses)
    }
    
    private var canViewImportCosts: Bool {
        storeManager.hasPermission(.viewExpenses) || storeManager.hasPermission(.viewInventory)
    }
    
    var body: some View {
        NavigationView {
            if canViewOperatingCosts || canViewImportCosts {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("CHI PHÍ & NHẬP HÀNG")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.themeTextDark)
                        Spacer()
                        
                        if selectedSubTab == 0 && canViewOperatingCosts {
                            // Redundant button removed
                        }
                        
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
                        if canViewOperatingCosts {
                            CostsTabButton(title: "Vận hành", isSelected: selectedSubTab == 0) { selectedSubTab = 0 }
                        }
                        
                        if canViewImportCosts {
                            CostsTabButton(title: "Phát sinh", isSelected: selectedSubTab == 1) { selectedSubTab = 1 }
                        }
                    }
                    .background(Color.white)
                    .onChange(of: canViewOperatingCosts) { newValue in
                        if !newValue && selectedSubTab == 0 { selectedSubTab = 1 }
                    }
                    .onAppear {
                        // Validate initial selection
                        if selectedSubTab == 0 && !canViewOperatingCosts {
                            selectedSubTab = 1
                        } else if selectedSubTab == 1 && !canViewImportCosts {
                            selectedSubTab = 0
                        }
                    }
                    
                    // Content
                    if selectedSubTab == 0 {
                        if canViewOperatingCosts {
                            OperatingCostsList(viewModel: viewModel)
                        } else {
                            AccessDeniedView(title: "Vận hành")
                        }
                    } else {
                        if canViewImportCosts {
                            ImportCostsList(viewModel: viewModel)
                        } else {
                            AccessDeniedView(title: "Phát sinh")
                        }
                    }
                }
                .navigationTitle("Chi phí & Nhập hàng")
                .navigationBarHidden(true)
                .background(Color(UIColor.systemGroupedBackground))
                .sheet(isPresented: $showExportSheet) {
                    if let url = exportURL {
                        ShareSheet(items: [url])
                    }
                }
            } else {
                AccessDeniedView(title: "Chi phí & Nhập hàng")
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct AccessDeniedView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("Không có quyền truy cập")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
            
            Text("Bạn cần quyền 'Xem Chi phí' để xem nội dung này.\nVui lòng liên hệ chủ cửa hàng.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarHidden(true)
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
    @State private var expenseToEdit: OperatingExpense?
    
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
                    .swipeActions(edge: .leading) {
                        Button {
                            expenseToEdit = expense
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteOperatingExpense(viewModel.operatingExpenses[index])
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadData(force: true) }
        .sheet(item: $expenseToEdit) { expense in
            AddOperatingExpenseView(viewModel: viewModel, existingExpense: expense)
        }
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteRestockBill(bill)
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.editRestockBill(bill)
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                // No delete here for now, or add if needed (viewModel.deleteRestockBill)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadData(force: true) }
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
