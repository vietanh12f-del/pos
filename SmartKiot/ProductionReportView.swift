import SwiftUI

struct ProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showMaterialExportReport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    .padding(.vertical, 14)
                    .background(Color.themePrimary.opacity(0.06))
                }
                .buttonStyle(.plain)
                Divider()
                Spacer()
            }
            .navigationTitle("Báo cáo sản xuất")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showMaterialExportReport) {
            MaterialExportReportView(viewModel: viewModel)
        }
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
    @ObservedObject var viewModel: OrderViewModel

    @Environment(\.dismiss) private var dismiss

    // Date selection
    @State private var selectedDate: Date = Date()
    @State private var isRangeMode: Bool = false
    @State private var rangeStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var rangeEnd: Date = Date()
    @State private var showDatePicker = false

    @State private var isLoading = false

    // Data (single day)
    @State private var autoLogs: [AutoMaterialExportLog] = []
    @State private var manualExports: [ProductionTransaction] = []
    @State private var materials: [MaterialItem] = []
    @State private var finishedImports: [ProductionTransaction] = []
    @State private var selectedFinishedGoodName: String? = nil
    @State private var showFinishedGoodPicker = false

    // Data (range mode)
    @State private var rangeData: [String: DayReportData] = [:]
    @State private var expandedDays: Set<String> = []

    struct DayReportData {
        let date: Date
        var autoLogs: [AutoMaterialExportLog]
        var manualExports: [ProductionTransaction]
        var finishedImports: [ProductionTransaction]
    }

    // MARK: - Computed

    private var allFinishedGoodNamesInDay: [String] {
        Array(Set(finishedImports.flatMap { $0.items.map { $0.name } })).sorted()
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
            let importTx = finishedImports.filter { $0.createdAt >= log.createdAt }.min(by: { $0.createdAt < $1.createdAt })
            return ProductionReportRow(log: log, freshTotalGrams: freshTotal, afterBoilGrams: afterBoil,
                yieldPercent: ratio, finishedImportTx: importTx, materials: materials)
        }
    }

    private var sortedRangeDays: [DayReportData] {
        rangeData.values.sorted { $0.date > $1.date }
    }

    private var navTitle: String {
        isRangeMode ? "\(formatDateOnly(rangeStart)) – \(formatDateOnly(rangeEnd))" : "Xuất nguyên liệu \(formatDateOnly(selectedDate))"
    }

    private var dateButtonLabel: String {
        isRangeMode ? "\(formatDateOnly(rangeStart)) – \(formatDateOnly(rangeEnd))" : formatDateOnly(selectedDate)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack { ProgressView(); Spacer() }.padding()
                } else if isRangeMode {
                    rangeContent
                } else {
                    singleDayContent
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDatePicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isRangeMode ? "calendar.badge.clock" : "calendar")
                            Text(dateButtonLabel)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(isRangeMode ? Color.orange : Color.themePrimary)
                    }
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
            .sheet(isPresented: $showDatePicker) {
                DateRangePickerSheet(
                    isRangeMode: $isRangeMode,
                    selectedDate: $selectedDate,
                    rangeStart: $rangeStart,
                    rangeEnd: $rangeEnd
                ) {
                    showDatePicker = false
                    Task { await reload() }
                }
            }
        }
        .task { await reload() }
    }

    // MARK: - Single day content

    private var singleDayContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                autoSection(logs: reportRows, finishedImports: finishedImports)
                Divider().padding(.horizontal)
                manualSection(exports: manualExports)
            }
        }
    }

    // MARK: - Range content

    private var rangeContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if sortedRangeDays.isEmpty {
                    Text("Không có dữ liệu trong khoảng ngày đã chọn")
                        .foregroundStyle(.gray).padding(40)
                } else {
                    ForEach(sortedRangeDays, id: \.date) { dayData in
                        let key = dayKey(dayData.date)
                        let isExpanded = expandedDays.contains(key)
                        let dayRows = makeRows(logs: dayData.autoLogs, finishedImports: dayData.finishedImports)

                        VStack(spacing: 0) {
                            Button {
                                if isExpanded { expandedDays.remove(key) }
                                else { expandedDays.insert(key) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption).foregroundStyle(.gray).frame(width: 16)
                                    Text(formatDateOnly(dayData.date))
                                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    if !dayData.autoLogs.isEmpty {
                                        Label("\(dayData.autoLogs.count)", systemImage: "wand.and.stars")
                                            .font(.caption).foregroundStyle(.purple)
                                    }
                                    if !dayData.manualExports.isEmpty {
                                        Label("\(dayData.manualExports.count)", systemImage: "hand.point.up.fill")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                    if dayData.autoLogs.isEmpty && dayData.manualExports.isEmpty {
                                        Text("Không có").font(.caption).foregroundStyle(.gray)
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 12).background(Color.white)
                            }
                            .buttonStyle(.plain)

                            if isExpanded {
                                VStack(spacing: 0) {
                                    autoSection(logs: dayRows, finishedImports: dayData.finishedImports)
                                    Divider().padding(.horizontal)
                                    manualSection(exports: dayData.manualExports)
                                }
                                .background(Color.themeBackgroundLight)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Reusable sections

    @ViewBuilder
    private func autoSection(logs: [ProductionReportRow], finishedImports: [ProductionTransaction]) -> some View {
        HStack {
            Label("Báo cáo xuất tự động", systemImage: "wand.and.stars")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.purple)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 6)

        if logs.isEmpty {
            Text("Không có dữ liệu xuất tự động")
                .font(.subheadline).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 10)
        } else {
            let allNames = Array(Set(finishedImports.flatMap { $0.items.map { $0.name } })).sorted()
            let totalGrams = finishedImports.flatMap { $0.items }.reduce(0) { $0 + $1.quantity }
            VStack(spacing: 12) {
                ForEach(logs, id: \.log.id) { row in
                    ProductionReportCard(
                        row: row,
                        selectedFinishedGoodName: selectedFinishedGoodName,
                        totalFinishedImportGramsInDay: totalGrams,
                        hasMultipleFinishedGoods: allNames.count > 1,
                        onSelectFinishedGood: { showFinishedGoodPicker = true }
                    )
                }
            }
            .padding(.horizontal).padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func manualSection(exports: [ProductionTransaction]) -> some View {
        HStack {
            Label("Báo cáo xuất thủ công", systemImage: "hand.point.up.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 6)

        if exports.isEmpty {
            Text("Không có")
                .font(.subheadline).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 12)
        } else {
            VStack(spacing: 12) {
                ForEach(exports.sorted { $0.createdAt > $1.createdAt }) { tx in
                    ManualExportCard(tx: tx, materials: materials)
                }
            }
            .padding(.horizontal).padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private func makeRows(logs: [AutoMaterialExportLog], finishedImports: [ProductionTransaction]) -> [ProductionReportRow] {
        logs.sorted { $0.createdAt > $1.createdAt }.map { log in
            let freshTotal = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
            let afterBoil = max(0, log.data.afterBoilGrams)
            let ratio: Double = freshTotal > 0 ? (Double(afterBoil) / Double(freshTotal) * 100) : 0
            let importTx = finishedImports.filter { $0.createdAt >= log.createdAt }.min(by: { $0.createdAt < $1.createdAt })
            return ProductionReportRow(log: log, freshTotalGrams: freshTotal, afterBoilGrams: afterBoil,
                yieldPercent: ratio, finishedImportTx: importTx, materials: materials)
        }
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        materials = await viewModel.fetchMaterials()
        if isRangeMode { await reloadRange() } else { await reloadSingleDay() }
    }

    private func reloadSingleDay() async {
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let logs = await viewModel.fetchAutoMaterialExportLogs(limit: 500)
        autoLogs = logs.filter { $0.createdAt >= start && $0.createdAt < end }
        let imports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        finishedImports = imports.filter { $0.createdAt >= start && $0.createdAt < end }
        let allExports = await viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
        let autoIds = Set(autoLogs.map { $0.productionTransactionId })
        manualExports = allExports.filter { $0.createdAt >= start && $0.createdAt < end && !autoIds.contains($0.id) }
        selectedFinishedGoodName = nil
    }

    private func reloadRange() async {
        let start = startOfDay(rangeStart)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(rangeEnd)) ?? startOfDay(rangeEnd)
        let allLogs = await viewModel.fetchAutoMaterialExportLogs(limit: 2000)
        let allImports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        let allExports = await viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
        let allAutoIds = Set(allLogs.map { $0.productionTransactionId })
        var result: [String: DayReportData] = [:]
        var cursor = start
        while cursor < end {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let key = dayKey(cursor)
            result[key] = DayReportData(
                date: cursor,
                autoLogs: allLogs.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd },
                manualExports: allExports.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd && !allAutoIds.contains($0.id) },
                finishedImports: allImports.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd }
            )
            cursor = dayEnd
        }
        rangeData = result
        if let firstKey = result.keys.sorted().last { expandedDays = [firstKey] }
    }

    private func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Binding var isRangeMode: Bool
    @Binding var selectedDate: Date
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Chọn khoảng ngày", isOn: $isRangeMode)
                        .tint(Color.themePrimary)
                }

                if isRangeMode {
                    Section(header: Text("Từ ngày")) {
                        DatePicker("", selection: $rangeStart, in: ...rangeEnd, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .onChange(of: rangeStart) { _, newVal in
                                if newVal > rangeEnd { rangeEnd = newVal }
                            }
                    }
                    Section(header: Text("Đến ngày")) {
                        DatePicker("", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    Section {
                        HStack {
                            Image(systemName: "info.circle").foregroundStyle(.gray)
                            Text("Khoảng \(daysBetween(rangeStart, rangeEnd) + 1) ngày")
                                .font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                } else {
                    Section(header: Text("Chọn ngày")) {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
            }
            .navigationTitle("Thời gian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { onDone() }.fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func daysBetween(_ from: Date, _ to: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}
