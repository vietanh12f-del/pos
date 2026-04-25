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
    
    // Selected finished good name to filter
    @State private var selectedFinishedGoodName: String? = nil
    @State private var showFinishedGoodPicker = false

    // Material export report
    @State private var showMaterialExportReport = false
    @State private var manualExports: [ProductionTransaction] = []
    
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
            .confirmationDialog("Chọn thành phẩm", isPresented: $showFinishedGoodPicker, titleVisibility: .visible) {
                ForEach(allFinishedGoodNamesInDay, id: \.self) { name in
                    Button(name) { selectedFinishedGoodName = name }
                }
                if selectedFinishedGoodName != nil {
                    Button("Tất cả thành phẩm", role: .destructive) {
                        selectedFinishedGoodName = nil
                    }
                }
                Button("Huỷ", role: .cancel) { }
            }
        }
        .sheet(isPresented: $showMaterialExportReport) {
            MaterialExportReportView(
                selectedDate: selectedDate,
                autoLogs: autoLogs,
                manualExports: manualExports,
                materials: materials,
                finishedImports: finishedImports
            )
        }
    }
    
    // All unique finished good names imported today
    private var allFinishedGoodNamesInDay: [String] {
        let names = finishedImports.flatMap { $0.items.map { $0.name } }
        return Array(Set(names)).sorted()
    }
    
    // Total grams for selected finished good (or all) across the whole day
    private var totalFinishedImportGramsInDay: Int {
        let allItems = finishedImports.flatMap { $0.items }
        if let name = selectedFinishedGoodName {
            return allItems.filter { $0.name == name }.reduce(0) { $0 + $1.quantity }
        }
        return allItems.reduce(0) { $0 + $1.quantity }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
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

            Button {
                showMaterialExportReport = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.subheadline)
                    Text("Báo cáo xuất nguyên liệu")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .foregroundStyle(Color.themePrimary)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.themePrimary.opacity(0.06))
            }
            .buttonStyle(.plain)
        }
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
                            ProductionReportCard(
                                row: row,
                                selectedFinishedGoodName: selectedFinishedGoodName,
                                totalFinishedImportGramsInDay: totalFinishedImportGramsInDay,
                                hasMultipleFinishedGoods: allFinishedGoodNamesInDay.count > 1,
                                onSelectFinishedGood: { showFinishedGoodPicker = true }
                            )
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
                return ProductionReportRow(
                    log: log,
                    freshTotalGrams: freshTotal,
                    afterBoilGrams: afterBoil,
                    yieldPercent: ratio,
                    finishedImportTx: importTx,
                    materials: materials
                )
            }
    }
    
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        
        materials = await viewModel.fetchMaterials()
        
        let logs = await viewModel.fetchAutoMaterialExportLogs(limit: 500)
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        
        autoLogs = logs.filter { $0.createdAt >= start && $0.createdAt < end }
        
        let imports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        finishedImports = imports.filter { $0.createdAt >= start && $0.createdAt < end }
        
        // Fetch manual exports (Xuất nguyên liệu - not auto)
        let allExports = await viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
        // Filter out transactions that were created by auto export (linked via autoLogs)
        let autoTransactionIds = Set(autoLogs.map { $0.productionTransactionId })
        manualExports = allExports.filter {
            $0.createdAt >= start && $0.createdAt < end && !autoTransactionIds.contains($0.id)
        }

        // Reset selection when date changes
        selectedFinishedGoodName = nil
    }
    
    private func findFinishedImport(for log: AutoMaterialExportLog) -> ProductionTransaction? {
        let candidates = finishedImports.filter { $0.createdAt >= log.createdAt }
        return candidates.min(by: { $0.createdAt < $1.createdAt })
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

// MARK: - Row Model

private struct ProductionReportRow {
    let log: AutoMaterialExportLog
    let freshTotalGrams: Int
    let afterBoilGrams: Int
    let yieldPercent: Double
    let finishedImportTx: ProductionTransaction?
    let materials: [MaterialItem]
    
    func finishedProductLossPercent(importGrams: Int) -> Double {
        guard freshTotalGrams > 0, importGrams > 0 else { return 0 }
        return (Double(importGrams) / Double(freshTotalGrams)) * 100
    }
    
    func getMaterialPrice(materialId: UUID?) -> Double {
        guard let id = materialId else { return 0 }
        return materials.first(where: { $0.id == id })?.lastUnitPrice ?? 0
    }
    
    var allMaterials: [AutoMaterialExportLogRow] {
        return log.data.fresh + log.data.autoMaterials
    }
    
    var totalMaterialCost: Double {
        allMaterials.reduce(0.0) { sum, material in
            let pricePerKg = getMaterialPrice(materialId: material.materialId)
            let weightKg = material.totalExportGrams / 1000.0
            return sum + (pricePerKg * weightKg)
        }
    }
}

// MARK: - Card View

private struct ProductionReportCard: View {
    let row: ProductionReportRow
    let selectedFinishedGoodName: String?
    let totalFinishedImportGramsInDay: Int
    let hasMultipleFinishedGoods: Bool
    let onSelectFinishedGood: () -> Void
    
    @State private var showMaterialDetails = false
    
    private var lossPercent: Double {
        row.finishedProductLossPercent(importGrams: totalFinishedImportGramsInDay)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
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
                    Text("•").font(.caption).foregroundStyle(.gray)
                    Text(name).font(.subheadline).foregroundStyle(.gray)
                }
            }
            
            Divider()
            
            // Stats grid
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
                    // Label with optional picker button
                    HStack(spacing: 6) {
                        Text("Nhập thành phẩm")
                            .foregroundStyle(.gray)
                        if hasMultipleFinishedGoods {
                            Button {
                                onSelectFinishedGood()
                            } label: {
                                HStack(spacing: 2) {
                                    Text(selectedFinishedGoodName ?? "Tất cả")
                                        .font(.caption)
                                        .foregroundStyle(Color.themePrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.themePrimary.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        } else if let name = selectedFinishedGoodName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.gray.opacity(0.1)))
                        }
                    }
                    Spacer()
                    Text(totalFinishedImportGramsInDay > 0
                         ? FormatUtils.formatWeight(totalFinishedImportGramsInDay)
                         : "—")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                GridRow {
                    Text("Tỉ lệ hao hụt thành phẩm")
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.2f%%", lossPercent))
                        .fontWeight(.bold)
                        .foregroundStyle(lossPercent > 0 ? Color.green : Color.gray)
                }
            }
            .font(.subheadline)
            
            Divider()
            
            // Material details toggle
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
    
    // MARK: Material details
    
    private var materialDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !row.log.data.fresh.isEmpty {
                Text(row.log.data.freshTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                    .padding(.bottom, 4)
                ForEach(row.log.data.fresh) { material in
                    materialRow(material)
                }
            }
            
            if !row.log.data.autoMaterials.isEmpty {
                if !row.log.data.fresh.isEmpty {
                    Divider().padding(.vertical, 4)
                }
                Text(row.log.data.autoMaterialsTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                    .padding(.bottom, 4)
                ForEach(row.log.data.autoMaterials) { material in
                    materialRow(material)
                }
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
    
    private func materialRow(_ material: AutoMaterialExportLogRow) -> some View {
        let pricePerKg = row.getMaterialPrice(materialId: material.materialId)
        let weightKg = material.totalExportGrams / 1000.0
        let totalCost = pricePerKg * weightKg
        
        return VStack(alignment: .leading, spacing: 4) {
            Text(material.name)
                .font(.subheadline)
                .fontWeight(.medium)
            HStack {
                Text("Khối lượng:").font(.caption).foregroundStyle(.gray)
                Text(FormatUtils.formatWeight(Int(material.totalExportGrams))).font(.caption).fontWeight(.semibold)
            }
            HStack {
                Text("Đơn giá:").font(.caption).foregroundStyle(.gray)
                Text(formatCurrency(pricePerKg) + "/kg").font(.caption).fontWeight(.semibold)
            }
            HStack {
                Text("Tổng tiền:").font(.caption).foregroundStyle(.gray)
                Text(formatCurrency(totalCost)).font(.caption).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Manual Export Card (same style as ProductionReportCard)

private struct ManualExportCard: View {
    let tx: ProductionTransaction
    let materials: [MaterialItem]

    @State private var showDetails = false

    private func getMaterialPrice(for name: String) -> Double {
        materials.first(where: { $0.name.lowercased() == name.lowercased() })?.lastUnitPrice ?? 0
    }

    private var totalCost: Double {
        tx.items.reduce(0.0) { sum, item in
            let pricePerKg = getMaterialPrice(for: item.name)
            let weightKg = Double(item.quantity) / 1000.0
            return sum + (pricePerKg * weightKg)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(alignment: .top) {
                Label("Xuất thủ công", systemImage: "hand.point.up.fill")
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
            }

            HStack(spacing: 6) {
                Text(formatTime(tx.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                if let name = tx.creatorName, !name.isEmpty {
                    Text("•").font(.caption).foregroundStyle(.gray)
                    Text(name).font(.subheadline).foregroundStyle(.gray)
                }
            }

            Divider()

            // Items summary
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(tx.items) { item in
                    GridRow {
                        Text(item.name)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(FormatUtils.formatWeight(item.quantity))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
            }
            .font(.subheadline)

            Divider()

            // Detail toggle
            Button {
                showDetails.toggle()
            } label: {
                HStack {
                    Text("Chi tiết nguyên liệu xuất")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.themePrimary)
            }
            .buttonStyle(.plain)

            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tx.items) { item in
                        let pricePerKg = getMaterialPrice(for: item.name)
                        let weightKg = Double(item.quantity) / 1000.0
                        let itemCost = pricePerKg * weightKg

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack {
                                Text("Khối lượng:").font(.caption).foregroundStyle(.gray)
                                Text(FormatUtils.formatWeight(item.quantity)).font(.caption).fontWeight(.semibold)
                            }
                            HStack {
                                Text("Đơn giá:").font(.caption).foregroundStyle(.gray)
                                Text(formatCurrency(pricePerKg) + "/kg").font(.caption).fontWeight(.semibold)
                            }
                            HStack {
                                Text("Tổng tiền:").font(.caption).foregroundStyle(.gray)
                                Text(formatCurrency(itemCost)).font(.caption).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
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
                        Text(formatCurrency(totalCost))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Material Export Report View

struct MaterialExportReportView: View {
    let selectedDate: Date
    let autoLogs: [AutoMaterialExportLog]
    let manualExports: [ProductionTransaction]
    let materials: [MaterialItem]
    let finishedImports: [ProductionTransaction]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFinishedGoodName: String? = nil
    @State private var showFinishedGoodPicker = false

    private var allFinishedGoodNamesInDay: [String] {
        let names = finishedImports.flatMap { $0.items.map { $0.name } }
        return Array(Set(names)).sorted()
    }

    private var totalFinishedImportGramsInDay: Int {
        let allItems = finishedImports.flatMap { $0.items }
        if let name = selectedFinishedGoodName {
            return allItems.filter { $0.name == name }.reduce(0) { $0 + $1.quantity }
        }
        return allItems.reduce(0) { $0 + $1.quantity }
    }

    private var reportRows: [ProductionReportRow] {
        autoLogs.sorted { $0.createdAt > $1.createdAt }.map { log in
            let freshTotal = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
            let afterBoil = max(0, log.data.afterBoilGrams)
            let ratio: Double = freshTotal > 0 ? (Double(afterBoil) / Double(freshTotal) * 100) : 0
            let importTx = finishedImports
                .filter { $0.createdAt >= log.createdAt }
                .min(by: { $0.createdAt < $1.createdAt })
            return ProductionReportRow(
                log: log,
                freshTotalGrams: freshTotal,
                afterBoilGrams: afterBoil,
                yieldPercent: ratio,
                finishedImportTx: importTx,
                materials: materials
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Báo cáo xuất tự động ──
                    HStack {
                        Label("Báo cáo xuất tự động", systemImage: "wand.and.stars")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    if autoLogs.isEmpty {
                        Text("Không có dữ liệu xuất tự động")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(reportRows, id: \.log.id) { row in
                                ProductionReportCard(
                                    row: row,
                                    selectedFinishedGoodName: selectedFinishedGoodName,
                                    totalFinishedImportGramsInDay: totalFinishedImportGramsInDay,
                                    hasMultipleFinishedGoods: allFinishedGoodNamesInDay.count > 1,
                                    onSelectFinishedGood: { showFinishedGoodPicker = true }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }

                    Divider().padding(.horizontal)

                    // ── Báo cáo xuất thủ công ──
                    HStack {
                        Label("Báo cáo xuất thủ công", systemImage: "hand.point.up.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    if manualExports.isEmpty {
                        Text("Không có")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(manualExports.sorted { $0.createdAt > $1.createdAt }) { tx in
                                ManualExportCard(tx: tx, materials: materials)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Xuất nguyên liệu \(formatDateOnly(selectedDate))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .confirmationDialog("Chọn thành phẩm", isPresented: $showFinishedGoodPicker, titleVisibility: .visible) {
                ForEach(allFinishedGoodNamesInDay, id: \.self) { name in
                    Button(name) { selectedFinishedGoodName = name }
                }
                if selectedFinishedGoodName != nil {
                    Button("Tất cả thành phẩm", role: .destructive) { selectedFinishedGoodName = nil }
                }
                Button("Huỷ", role: .cancel) { }
            }
        }
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

}
