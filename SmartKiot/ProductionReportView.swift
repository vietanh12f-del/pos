import SwiftUI

struct ProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    
    @State private var autoLogs: [AutoMaterialExportLog] = []
    @State private var finishedImports: [ProductionTransaction] = []
    @State private var materials: [MaterialItem] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .navigationTitle("Báo cáo sản xuất")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task { await reload() }
            .onChange(of: selectedDate) { _, _ in
                Task { await reload() }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker("Chọn ngày", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Thời gian")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("Thời gian")
                .font(.subheadline)
                .foregroundStyle(.gray)
            Spacer()
            Button {
                showDatePicker = true
            } label: {
                Text(formatDateOnly(selectedDate))
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.gray.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.themeBackgroundLight)
    }
    
    private var content: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if reportRows.isEmpty {
                VStack(spacing: 10) {
                    Text("Chưa có dữ liệu trong ngày")
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(reportRows, id: \.log.id) { row in
                            ProductionReportCard(row: row)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color.themeBackgroundLight)
            }
        }
    }
    
    private var reportRows: [ProductionReportRow] {
        autoLogs
            .sorted { $0.createdAt > $1.createdAt }
            .map { log in
                let freshTotal = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
                let afterBoil = max(0, log.data.afterBoilGrams)
                let ratio: Double = freshTotal > 0 ? (Double(afterBoil) / Double(freshTotal) * 100) : 0
                let importTx = findFinishedImport(for: log)
                return ProductionReportRow(log: log, freshTotalGrams: freshTotal, afterBoilGrams: afterBoil, yieldPercent: ratio, finishedImportTx: importTx, materials: materials)
            }
    }
    
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch materials for pricing
        materials = await viewModel.fetchMaterials()
        
        let logs = await viewModel.fetchAutoMaterialExportLogs(limit: 500)
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        
        autoLogs = logs.filter { $0.createdAt >= start && $0.createdAt < end }
        
        let imports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        finishedImports = imports.filter { $0.createdAt >= start && $0.createdAt < end }
    }
    
    private func findFinishedImport(for log: AutoMaterialExportLog) -> ProductionTransaction? {
        let candidates = finishedImports.filter { $0.createdAt >= log.createdAt }
        if let first = candidates.min(by: { $0.createdAt < $1.createdAt }) {
            return first
        }
        return nil
    }
    
    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

private struct ProductionReportRow {
    let log: AutoMaterialExportLog
    let freshTotalGrams: Int
    let afterBoilGrams: Int
    let yieldPercent: Double
    let finishedImportTx: ProductionTransaction?
    let materials: [MaterialItem]
    
    var finishedImportGrams: Int {
        guard let tx = finishedImportTx else { return 0 }
        return tx.items.reduce(0) { $0 + $1.quantity }
    }
    
    var finishedProductLossPercent: Double {
        guard freshTotalGrams > 0, finishedImportGrams > 0 else { return 0 }
        return (Double(finishedImportGrams) / Double(freshTotalGrams)) * 100
    }
    
    func getMaterialPrice(materialId: UUID?) -> Double {
        guard let id = materialId else { return 0 }
        return materials.first(where: { $0.id == id })?.lastUnitPrice ?? 0
    }
    
    var totalMaterialCost: Double {
        log.data.fresh.reduce(0.0) { sum, material in
            let pricePerKg = getMaterialPrice(materialId: material.materialId)
            let weightKg = material.totalExportGrams / 1000.0
            return sum + (pricePerKg * weightKg)
        }
    }
}

private struct ProductionReportCard: View {
    let row: ProductionReportRow
    @State private var showMaterialDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(row.log.templateName)
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
            }
            
            HStack(spacing: 6) {
                Text(formatTime(row.log.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                if let name = row.log.creatorName, !name.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Nguyên liệu tươi")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(FormatUtils.formatWeight(row.freshTotalGrams))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                GridRow {
                    Text("Còn sau luộc")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(FormatUtils.formatWeight(row.afterBoilGrams))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                GridRow {
                    Text("Tỉ lệ hao hụt")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.2f%%", row.yieldPercent))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                GridRow {
                    Text("Nhập thành phẩm")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(finishedImportText)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                GridRow {
                    Text("Tỉ lệ hao hụt thành phẩm")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.2f%%", row.finishedProductLossPercent))
                        .fontWeight(.bold)
                        .foregroundStyle(row.finishedProductLossPercent > 0 ? Color.green : Color.gray)
                }
            }
            .font(.subheadline)
            
            Divider()
            
            Button {
                showMaterialDetails.toggle()
            } label: {
                HStack {
                    Text("Chi tiết nguyên liệu xuất")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showMaterialDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.themePrimary)
            }
            .buttonStyle(.plain)
            
            if showMaterialDetails {
                materialDetailsSection
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
    
    private var materialDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(row.log.data.fresh) { material in
                let pricePerKg = row.getMaterialPrice(materialId: material.materialId)
                let weightKg = material.totalExportGrams / 1000.0
                let totalCost = pricePerKg * weightKg
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Khối lượng:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(FormatUtils.formatWeight(Int(material.totalExportGrams)))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Đơn giá:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(formatCurrency(pricePerKg) + "/kg")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Tổng tiền:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(formatCurrency(totalCost))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            
            Divider()
            
            HStack {
                Text("Tổng tiền nguyên liệu")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(row.totalMaterialCost))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
            }
        }
        .padding(.top, 4)
    }
    
    private var finishedImportText: String {
        guard let tx = row.finishedImportTx else { return "—" }
        let total = tx.items.reduce(0) { $0 + $1.quantity }
        return FormatUtils.formatWeight(total)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

