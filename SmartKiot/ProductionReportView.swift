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
                materials: materials
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
        manualExports = allExports.filter { $0.createdAt >= start && $0.createdAt < end }

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

// MARK: - Material Export Report View

struct MaterialExportReportView: View {
    let selectedDate: Date
    let autoLogs: [AutoMaterialExportLog]
    let manualExports: [ProductionTransaction]
    let materials: [MaterialItem]

    @Environment(\.dismiss) private var dismiss

    // Aggregate all exported materials (auto + manual) by name
    private var aggregated: [(name: String, grams: Int, cost: Double)] {
        var map: [String: (grams: Int, materialId: UUID?)] = [:]

        // From auto logs: fresh + autoMaterials
        for log in autoLogs {
            for row in log.data.fresh + log.data.autoMaterials {
                let key = row.name.lowercased()
                let g = Int(max(0, row.totalExportGrams.rounded()))
                map[key] = (
                    (map[key]?.grams ?? 0) + g,
                    map[key]?.materialId ?? row.materialId
                )
            }
        }

        // From manual exports
        for tx in manualExports {
            for item in tx.items {
                let key = item.name.lowercased()
                let g = item.quantity
                let mid = materials.first(where: { $0.name.lowercased() == key })?.id
                map[key] = (
                    (map[key]?.grams ?? 0) + g,
                    map[key]?.materialId ?? mid
                )
            }
        }

        return map.keys.sorted().map { key in
            let entry = map[key]!
            let pricePerKg = materials.first(where: { $0.id == entry.materialId })?.lastUnitPrice
                ?? materials.first(where: { $0.name.lowercased() == key })?.lastUnitPrice
                ?? 0
            let cost = pricePerKg * (Double(entry.grams) / 1000.0)
            // Capitalize display name
            let displayName = map.keys.first(where: { $0 == key }).map { _ in
                autoLogs.flatMap { $0.data.fresh + $0.data.autoMaterials }
                    .first(where: { $0.name.lowercased() == key })?.name
                ?? manualExports.flatMap { $0.items }
                    .first(where: { $0.name.lowercased() == key })?.name
                ?? key
            } ?? key
            return (displayName, entry.grams, cost)
        }
    }

    private var totalCost: Double {
        aggregated.reduce(0) { $0 + $1.cost }
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary counts
                    HStack(spacing: 12) {
                        summaryTile(
                            icon: "wand.and.stars",
                            label: "Xuất tự động",
                            value: "\(autoLogs.count) lần",
                            color: .purple
                        )
                        summaryTile(
                            icon: "hand.point.up.fill",
                            label: "Xuất thủ công",
                            value: "\(manualExports.count) lần",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // Material breakdown
                    if aggregated.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray.opacity(0.4))
                            Text("Không có dữ liệu xuất nguyên liệu")
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row
                            HStack {
                                Text("Nguyên liệu")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Khối lượng")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .frame(width: 90, alignment: .trailing)
                                Text("Thành tiền")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.06))

                            ForEach(aggregated, id: \.name) { item in
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(FormatUtils.formatWeight(item.grams))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.themePrimary)
                                            .frame(width: 90, alignment: .trailing)
                                        Text(formatCurrency(item.cost))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 90, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    Divider().padding(.leading, 12)
                                }
                            }

                            // Total row
                            HStack {
                                Text("Tổng cộng")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("")
                                    .frame(width: 90)
                                Text(formatCurrency(totalCost))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themePrimary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary.opacity(0.05))
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)

                        // Auto logs detail
                        if !autoLogs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Xuất tự động (\(autoLogs.count) lần)")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(autoLogs.sorted { $0.createdAt > $1.createdAt }) { log in
                                    autoLogRow(log)
                                }
                            }
                        }

                        // Manual exports detail
                        if !manualExports.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Xuất thủ công (\(manualExports.count) lần)")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(manualExports.sorted { $0.createdAt > $1.createdAt }) { tx in
                                    manualExportRow(tx)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Xuất nguyên liệu \(formatDateOnly(selectedDate))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    private func summaryTile(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func autoLogRow(_ log: AutoMaterialExportLog) -> some View {
        let totalFresh = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
        let totalAuto = log.data.autoMaterials.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text(log.templateName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatTime(log.createdAt))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            HStack(spacing: 16) {
                Label(FormatUtils.formatWeight(totalFresh), systemImage: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label(FormatUtils.formatWeight(totalAuto), systemImage: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                if let creator = log.creatorName, !creator.isEmpty {
                    Label(creator, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    private func manualExportRow(_ tx: ProductionTransaction) -> some View {
        let total = tx.items.reduce(0) { $0 + $1.quantity }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "hand.point.up.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Xuất thủ công")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatTime(tx.createdAt))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            HStack(spacing: 8) {
                ForEach(tx.items.prefix(3)) { item in
                    Text(item.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.1)))
                        .foregroundStyle(.orange)
                }
                if tx.items.count > 3 {
                    Text("+\(tx.items.count - 3)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            HStack(spacing: 16) {
                Label(FormatUtils.formatWeight(total), systemImage: "scalemass.fill")
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                if let creator = tx.creatorName, !creator.isEmpty {
                    Label(creator, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
