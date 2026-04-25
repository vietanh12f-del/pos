import SwiftUI

struct ProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showMaterialExportReport = false
    @State private var showMaterialImportReport = false
    @State private var showFinishedImportReport = false
    @State private var showFinishedExportReport = false

    private struct ReportButton {
        let title: String
        let icon: String
        let color: Color
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                reportButton(title: "Báo cáo xuất nguyên liệu",
                             icon: "arrow.up.doc.fill", color: .purple) {
                    showMaterialExportReport = true
                }
                Divider()
                reportButton(title: "Báo cáo nhập nguyên liệu",
                             icon: "arrow.down.doc.fill", color: .green) {
                    showMaterialImportReport = true
                }
                Divider()
                reportButton(title: "Báo cáo nhập thành phẩm",
                             icon: "tray.and.arrow.down.fill", color: .blue) {
                    showFinishedImportReport = true
                }
                Divider()
                reportButton(title: "Báo cáo xuất thành phẩm",
                             icon: "tray.and.arrow.up.fill", color: .orange) {
                    showFinishedExportReport = true
                }
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
        .sheet(isPresented: $showMaterialImportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Xuất Nguyên liệu",  // fetch mode
                title: "Nhập nguyên liệu",
                accentColor: .green,
                reportKind: .materialImport
            )
        }
        .sheet(isPresented: $showFinishedImportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Nhập Thành Phẩm",
                title: "Nhập thành phẩm",
                accentColor: .blue,
                reportKind: .finishedImport
            )
        }
        .sheet(isPresented: $showFinishedExportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Xuất Thành Phẩm",
                title: "Xuất thành phẩm",
                accentColor: .orange,
                reportKind: .finishedExport
            )
        }
    }

    @ViewBuilder
    private func reportButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(color.opacity(0.04))
        }
        .buttonStyle(.plain)
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

// MARK: - Generic Production Report View
// Used for: Nhập nguyên liệu, Nhập thành phẩm, Xuất thành phẩm

enum ProductionReportKind {
    case materialImport   // Nhập nguyên liệu
    case finishedImport   // Nhập thành phẩm
    case finishedExport   // Xuất thành phẩm
}

struct GenericProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    let mode: String
    let title: String
    let accentColor: Color
    let reportKind: ProductionReportKind

    @Environment(\.dismiss) private var dismiss

    // Date
    @State private var selectedDate: Date = Date()
    @State private var isRangeMode = false
    @State private var rangeStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var rangeEnd: Date = Date()
    @State private var showDatePicker = false

    @State private var isLoading = false
    @State private var transactions: [ProductionTransaction] = []
    @State private var materials: [MaterialItem] = []

    // Range mode
    @State private var rangeData: [String: [ProductionTransaction]] = [:]
    @State private var expandedDays: Set<String> = []

    // MARK: - Computed

    private var navTitle: String {
        isRangeMode ? "\(title): \(formatDateOnly(rangeStart)) – \(formatDateOnly(rangeEnd))" : "\(title) \(formatDateOnly(selectedDate))"
    }

    private var sortedRangeDays: [(key: String, date: Date, txs: [ProductionTransaction])] {
        rangeData.map { key, txs in
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let date = f.date(from: key) ?? Date()
            return (key, date, txs)
        }.sorted { $0.date > $1.date }
    }

    // Summary stats for a list of transactions
    private func stats(for txs: [ProductionTransaction]) -> (count: Int, totalCost: Double, totalQty: Int, totalRevenue: Double, totalDebt: Double, unpaidCount: Int) {
        let count = txs.count
        let totalCost = txs.reduce(0) { $0 + $1.totalCost }
        let totalQty = txs.flatMap { $0.items }.reduce(0) { $0 + $1.quantity }
        let totalRevenue = txs.compactMap { $0.grandTotal }.reduce(0, +)
        let totalDebt = txs.compactMap { $0.debtAmount }.reduce(0, +)
        let unpaidCount = txs.filter { !$0.isPaid }.count
        return (count, totalCost, totalQty, totalRevenue, totalDebt, unpaidCount)
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
                            Text(isRangeMode ? "\(formatDateOnly(rangeStart))–\(formatDateOnly(rangeEnd))" : formatDateOnly(selectedDate))
                                .fontWeight(.semibold).lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(isRangeMode ? Color.orange : accentColor)
                    }
                }
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

    // MARK: - Single day

    private var singleDayContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if transactions.isEmpty {
                    emptyView
                } else {
                    summaryCard(txs: transactions)
                    ForEach(transactions.sorted { $0.createdAt > $1.createdAt }) { tx in
                        transactionCard(tx)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Range content

    private var rangeContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Overall summary across all days
                if !rangeData.isEmpty {
                    let allTxs = rangeData.values.flatMap { $0 }
                    if !allTxs.isEmpty {
                        summaryCard(txs: allTxs)
                            .padding(.horizontal)
                    }
                }

                if sortedRangeDays.isEmpty {
                    emptyView.padding(.horizontal)
                } else {
                    ForEach(sortedRangeDays, id: \.key) { item in
                        let isExpanded = expandedDays.contains(item.key)
                        VStack(spacing: 0) {
                            // Day header
                            Button {
                                if isExpanded { expandedDays.remove(item.key) }
                                else { expandedDays.insert(item.key) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption).foregroundStyle(.gray).frame(width: 16)
                                    Text(formatDateOnly(item.date))
                                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    if item.txs.isEmpty {
                                        Text("Không có").font(.caption).foregroundStyle(.gray)
                                    } else {
                                        Text("\(item.txs.count) giao dịch")
                                            .font(.caption).foregroundStyle(accentColor)
                                        let s = stats(for: item.txs)
                                        Text("• \(formatCurrency(s.totalCost))")
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 12).background(Color.white)
                            }
                            .buttonStyle(.plain)

                            if isExpanded && !item.txs.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(item.txs.sorted { $0.createdAt > $1.createdAt }) { tx in
                                        transactionCard(tx)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
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

    // MARK: - Summary card

    private func summaryCard(txs: [ProductionTransaction]) -> some View {
        let s = stats(for: txs)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Tổng kết")
                .font(.headline).fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(label: "Số giao dịch", value: "\(s.count)", icon: "doc.text.fill", color: accentColor)
                statTile(label: isMaterial ? "Tổng chi phí" : "Tổng giá trị", value: formatCurrency(isMaterial ? s.totalCost : s.totalRevenue), icon: "banknote.fill", color: .green)
                if isMaterial {
                    statTile(label: "Tổng khối lượng", value: FormatUtils.formatWeight(s.totalQty), icon: "scalemass.fill", color: .blue)
                } else {
                    statTile(label: "Đã thanh toán", value: formatCurrency(s.totalRevenue - s.totalDebt), icon: "checkmark.circle.fill", color: .green)
                }
                if reportKind == .finishedExport {
                    statTile(label: "Còn nợ", value: formatCurrency(s.totalDebt), icon: "exclamationmark.circle.fill", color: s.totalDebt > 0 ? .red : .gray)
                } else {
                    statTile(label: "Tổng khối lượng", value: FormatUtils.formatWeight(s.totalQty), icon: "scalemass.fill", color: .blue)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private func statTile(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.gray)
                Text(value).font(.subheadline).fontWeight(.bold)
            }
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Transaction card

    @State private var expandedTxIds: Set<UUID> = []

    private func transactionCard(_ tx: ProductionTransaction) -> some View {
        let isExpanded = expandedTxIds.contains(tx.id)
        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(formatTime(tx.createdAt))
                            .font(.subheadline).fontWeight(.semibold)
                        if let name = tx.creatorName, !name.isEmpty {
                            Text("•").font(.caption).foregroundStyle(.gray)
                            Text(name).font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                    if let note = tx.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.gray).lineLimit(1)
                    }
                }
                Spacer()
                // Payment badge for finishedExport
                if reportKind == .finishedExport {
                    Text(tx.isPaid ? "Đã TT" : "Chưa TT")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(tx.isPaid ? .green : .orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(tx.isPaid ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)))
                }
            }

            Divider()

            // Items list
            VStack(spacing: 6) {
                ForEach(tx.items) { item in
                    HStack {
                        Text(item.name).font(.subheadline)
                        Spacer()
                        Text(isMaterial ? FormatUtils.formatWeight(item.quantity) : "\(item.quantity) kg")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(accentColor)
                        Text(formatCurrency(item.unitPrice) + (isMaterial ? "/kg" : ""))
                            .font(.caption).foregroundStyle(.gray)
                    }
                }
            }

            // Buyer info for finishedExport
            if reportKind == .finishedExport, let buyer = tx.buyerName, !buyer.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.fill").font(.caption).foregroundStyle(.gray)
                        Text(buyer).font(.subheadline).fontWeight(.semibold)
                        if let phone = tx.buyerPhone, !phone.isEmpty {
                            Text("•").font(.caption).foregroundStyle(.gray)
                            Text(phone).font(.caption).foregroundStyle(.gray)
                        }
                    }
                    if let addr = tx.buyerAddress, !addr.isEmpty {
                        Text(addr).font(.caption).foregroundStyle(.gray)
                    }
                }
            }

            // Financial summary
            Divider()
            if reportKind == .finishedExport {
                VStack(spacing: 4) {
                    if let vat = tx.vatAmount, vat > 0 {
                        HStack {
                            Text("VAT (\(Int(tx.vatRate ?? 0))%)").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(vat)).font(.caption).fontWeight(.semibold)
                        }
                    }
                    HStack {
                        Text("Tổng cộng").font(.subheadline).fontWeight(.bold)
                        Spacer()
                        Text(formatCurrency(tx.grandTotal ?? tx.totalCost)).font(.subheadline).fontWeight(.bold).foregroundStyle(accentColor)
                    }
                    if let paid = tx.paidAmount {
                        HStack {
                            Text("Đã thanh toán").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(paid)).font(.caption).fontWeight(.semibold).foregroundStyle(.green)
                        }
                    }
                    if let debt = tx.debtAmount, debt > 0 {
                        HStack {
                            Text("Còn nợ").font(.caption).foregroundStyle(.red)
                            Spacer()
                            Text(formatCurrency(debt)).font(.caption).fontWeight(.bold).foregroundStyle(.red)
                        }
                        if let payDate = tx.expectedPayDate {
                            HStack {
                                Text("Dự kiến trả:").font(.caption).foregroundStyle(.gray)
                                Spacer()
                                Text(formatDateOnly(payDate)).font(.caption).fontWeight(.semibold)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Text("Tổng chi phí").font(.subheadline).fontWeight(.bold)
                    Spacer()
                    Text(formatCurrency(tx.totalCost)).font(.subheadline).fontWeight(.bold).foregroundStyle(accentColor)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
            Text("Không có dữ liệu").foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity).padding(40)
    }

    private var isMaterial: Bool { reportKind == .materialImport }

    // MARK: - Data loading

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        materials = await viewModel.fetchMaterials()
        if isRangeMode { await reloadRange() } else { await reloadSingleDay() }
    }

    private func reloadSingleDay() async {
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let all = await viewModel.fetchProductionTransactions(mode: mode)
        transactions = all.filter { $0.createdAt >= start && $0.createdAt < end }
    }

    private func reloadRange() async {
        let start = startOfDay(rangeStart)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(rangeEnd)) ?? startOfDay(rangeEnd)
        let all = await viewModel.fetchProductionTransactions(mode: mode)
        let filtered = all.filter { $0.createdAt >= start && $0.createdAt < end }
        var result: [String: [ProductionTransaction]] = [:]
        var cursor = start
        while cursor < end {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let key = dayKey(cursor)
            result[key] = filtered.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd }
            cursor = dayEnd
        }
        rangeData = result
        if let firstKey = result.keys.sorted().last { expandedDays = [firstKey] }
    }

    // MARK: - Helpers

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}
