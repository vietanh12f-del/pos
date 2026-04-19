import SwiftUI

struct AutoMaterialExportSheetView: View {
    @ObservedObject var viewModel: OrderViewModel
    let defaultHeaderName: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTemplateId: UUID?
    @State private var draftName: String = ""
    
    @State private var headerName: String = ""
    @State private var freshTitle: String = "Nguyên liệu tươi"
    @State private var afterBoilTitle: String = "Còn sau luộc"
    @State private var panCountTitle: String = "Số lượng chảo xào"
    @State private var panWeightTitle: String = "Khối lượng / chảo"
    @State private var autoMaterialsTitle: String = "Nguyên liệu xuất tự động"
    
    @State private var freshSelected: Set<UUID> = []
    @State private var freshExportKgTextById: [UUID: String] = [:]
    
    @State private var afterBoilKgText: String = ""
    @State private var panCountText: String = "1"
    @State private var standardPanWeightKgText: String = ""
    
    @State private var autoSelected: Set<UUID> = []
    @State private var autoStandardPerPanKgTextById: [UUID: String] = [:]
    
    @State private var showTemplatePicker = false
    @State private var showFreshPicker = false
    @State private var showAutoPicker = false
    @State private var isSavingTemplate = false
    @State private var showConfirmAlert = false
    @State private var lastValidationError: String?
    
    init(viewModel: OrderViewModel, defaultHeaderName: String) {
        self.viewModel = viewModel
        self.defaultHeaderName = defaultHeaderName
        _headerName = State(initialValue: defaultHeaderName)
        _draftName = State(initialValue: defaultHeaderName)
        _afterBoilKgText = State(initialValue: "0")
        _standardPanWeightKgText = State(initialValue: "0")
    }
    
    private var materialsById: [UUID: MaterialItem] {
        Dictionary(uniqueKeysWithValues: viewModel.materials.map { ($0.id, $0) })
    }
    
    private var panCount: Int {
        max(0, Int(panCountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
    }
    
    private var afterBoilGrams: Int {
        max(0, FormatUtils.parseKgDecimalToGrams(afterBoilKgText) ?? 0)
    }
    
    private var standardPanWeightGrams: Int {
        max(0, FormatUtils.parseKgDecimalToGrams(standardPanWeightKgText) ?? 0)
    }
    
    private var actualPanWeightGrams: Double {
        guard panCount > 0 else { return 0 }
        return Double(afterBoilGrams) / Double(panCount)
    }
    
    private var percentChange: Double {
        guard standardPanWeightGrams > 0 else { return 0 }
        return actualPanWeightGrams / Double(standardPanWeightGrams)
    }
    
    private var freshRows: [AutoMaterialExportLogRow] {
        freshSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let grams = max(0, FormatUtils.parseKgDecimalToGrams(freshExportKgTextById[id] ?? "") ?? 0)
            return AutoMaterialExportLogRow(
                id: UUID(),
                materialId: m.id,
                name: m.name,
                stockGrams: m.stockQuantity,
                standardPerPanGrams: nil,
                actualPerPanGrams: nil,
                totalExportGrams: Double(grams)
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    private var autoRows: [AutoMaterialExportLogRow] {
        autoSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let standard = max(0, Double(FormatUtils.parseKgDecimalToGrams(autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            let perPanActual = standard * percentChange
            let total = perPanActual * Double(panCount)
            return AutoMaterialExportLogRow(
                id: UUID(),
                materialId: m.id,
                name: m.name,
                stockGrams: m.stockQuantity,
                standardPerPanGrams: standard,
                actualPerPanGrams: perPanActual,
                totalExportGrams: total
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    private var totalExportByMaterialName: [(name: String, grams: Int, stock: Int, isOver: Bool)] {
        var map: [String: (g: Int, stock: Int)] = [:]
        for r in freshRows {
            let g = Int(max(0, r.totalExportGrams.rounded()))
            map[r.name, default: (0, r.stockGrams)].g += g
            map[r.name, default: (0, r.stockGrams)].stock = r.stockGrams
        }
        for r in autoRows {
            let g = Int(max(0, r.totalExportGrams.rounded()))
            map[r.name, default: (0, r.stockGrams)].g += g
            map[r.name, default: (0, r.stockGrams)].stock = r.stockGrams
        }
        return map.keys.sorted().map { k in
            let v = map[k] ?? (0, 0)
            return (k, v.g, v.stock, v.g > v.stock)
        }
    }
    
    private var canConfirm: Bool {
        if panCount <= 0 { return false }
        if freshSelected.isEmpty && autoSelected.isEmpty { return false }
        if totalExportByMaterialName.contains(where: { $0.grams <= 0 }) { return false }
        if totalExportByMaterialName.contains(where: { $0.isOver }) { return false }
        return true
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    freshSection
                    afterBoilSection
                    panCountSection
                    panWeightSection
                    autoMaterialsSection
                    summarySection
                    confirmSection
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("Xuất tự động")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                await viewModel.loadMaterials()
                await viewModel.loadAutoMaterialExportTemplates()
                if let first = viewModel.autoMaterialExportTemplates.first {
                    applyTemplate(first)
                } else {
                    headerName = defaultHeaderName
                    draftName = defaultHeaderName
                }
            }
        }
        .confirmationDialog("Chọn sheet", isPresented: $showTemplatePicker, titleVisibility: .visible) {
            Button("Tạo sheet mới") {
                createNewTemplate()
            }
            ForEach(viewModel.autoMaterialExportTemplates, id: \.id) { t in
                Button(t.name) {
                    applyTemplate(t)
                }
            }
        }
        .sheet(isPresented: $showFreshPicker) {
            MaterialMultiSelectSheet(
                title: "Chọn nguyên liệu tươi",
                materials: viewModel.materials,
                selected: freshSelected
            ) { selected in
                freshSelected = selected
                for id in selected {
                    if freshExportKgTextById[id] == nil { freshExportKgTextById[id] = "0" }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAutoPicker) {
            MaterialMultiSelectSheet(
                title: "Chọn nguyên liệu xuất tự động",
                materials: viewModel.materials,
                selected: autoSelected
            ) { selected in
                autoSelected = selected
                for id in selected {
                    if autoStandardPerPanKgTextById[id] == nil { autoStandardPerPanKgTextById[id] = "0" }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Xác nhận xuất tự động?", isPresented: $showConfirmAlert) {
            Button("Hủy", role: .cancel) { }
            Button("Xác nhận") {
                Task { await confirmExport() }
            }
        } message: {
            if let err = lastValidationError {
                Text(err)
            } else {
                Text("Hệ thống sẽ trừ kho và ghi lịch sử xuất.")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    showTemplatePicker = true
                } label: {
                    Text(selectedTemplateName)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    Task { await saveTemplate() }
                } label: {
                    if isSavingTemplate {
                        ProgressView()
                    } else {
                        Text("Lưu sheet")
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSavingTemplate)
            }
            
            HStack {
                Text("Tên sheet")
                Spacer()
                TextField("Tên", text: $draftName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
            
            HStack {
                Text("Tên header")
                Spacer()
                TextField("Ví dụ: Khô Gà", text: $headerName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var freshSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Nguyên liệu tươi", text: $freshTitle)
                    .font(.headline)
                Spacer()
                Button {
                    showFreshPicker = true
                } label: {
                    Text("Chọn")
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
            }
            
            if freshSelected.isEmpty {
                Text("Chưa chọn nguyên liệu")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(freshRows) { row in
                        let materialId = row.materialId
                        FreshRowView(
                            name: row.name,
                            stockText: FormatUtils.formatWeight(row.stockGrams),
                            valueText: Binding(
                                get: {
                                    guard let id = materialId else { return "0" }
                                    return freshExportKgTextById[id] ?? "0"
                                },
                                set: { newVal in
                                    guard let id = materialId else { return }
                                    freshExportKgTextById[id] = newVal
                                }
                            )
                        )
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var afterBoilSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Còn sau luộc", text: $afterBoilTitle)
                .font(.headline)
            HStack {
                Text("Khối lượng")
                Spacer()
                TextField("Kg", text: $afterBoilKgText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var panCountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Số lượng chảo xào", text: $panCountTitle)
                .font(.headline)
            HStack {
                Text("Số chảo")
                Spacer()
                TextField("0", text: $panCountText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var panWeightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Khối lượng / chảo", text: $panWeightTitle)
                .font(.headline)
            HStack {
                Text("Chuẩn")
                Spacer()
                TextField("Kg", text: $standardPanWeightKgText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
            }
            HStack {
                Text("Thực tế")
                Spacer()
                Text(FormatUtils.formatKgDecimal(fromGrams: Int(actualPanWeightGrams.rounded())))
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var autoMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Nguyên liệu xuất tự động", text: $autoMaterialsTitle)
                    .font(.headline)
                Spacer()
                Button {
                    showAutoPicker = true
                } label: {
                    Text("Chọn")
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
            }
            
            if autoSelected.isEmpty {
                Text("Chưa chọn nguyên liệu")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 10) {
                    ForEach(autoRows) { row in
                        let materialId = row.materialId
                        AutoRowView(
                            name: row.name,
                            stockText: FormatUtils.formatWeight(row.stockGrams),
                            standardText: Binding(
                                get: {
                                    guard let id = materialId else { return "0" }
                                    return autoStandardPerPanKgTextById[id] ?? "0"
                                },
                                set: { newVal in
                                    guard let id = materialId else { return }
                                    autoStandardPerPanKgTextById[id] = newVal
                                }
                            ),
                            perPanActualText: FormatUtils.formatKgDecimal(fromGrams: Int((row.actualPerPanGrams ?? 0).rounded())),
                            totalText: FormatUtils.formatKgDecimal(fromGrams: Int(row.totalExportGrams.rounded())),
                            isOver: Int(row.totalExportGrams.rounded()) > row.stockGrams
                        )
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tổng khối lượng cần xuất")
                .font(.headline)
            if totalExportByMaterialName.isEmpty {
                Text("—")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(totalExportByMaterialName, id: \.name) { row in
                        HStack {
                            Text(row.name)
                                .lineLimit(1)
                            Spacer()
                            Text(FormatUtils.formatWeight(row.grams))
                                .fontWeight(.bold)
                                .foregroundStyle(row.isOver ? .red : Color.themePrimary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var confirmSection: some View {
        VStack(spacing: 10) {
            Button {
                let err = validate()
                lastValidationError = err
                showConfirmAlert = true
            } label: {
                Text("Xác nhận")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [Color.themePrimary, Color.themePrimary.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            .disabled(!canConfirm)
            
            if !canConfirm {
                Text("Kiểm tra số chảo, số lượng và tồn kho trước khi xác nhận")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    private var selectedTemplateName: String {
        if let id = selectedTemplateId, let t = viewModel.autoMaterialExportTemplates.first(where: { $0.id == id }) {
            return t.name
        }
        return "Chọn sheet"
    }
    
    private func createNewTemplate() {
        selectedTemplateId = nil
        draftName = defaultHeaderName
        headerName = defaultHeaderName
        freshTitle = "Nguyên liệu tươi"
        afterBoilTitle = "Còn sau luộc"
        panCountTitle = "Số lượng chảo xào"
        panWeightTitle = "Khối lượng / chảo"
        autoMaterialsTitle = "Nguyên liệu xuất tự động"
        freshSelected = []
        freshExportKgTextById = [:]
        afterBoilKgText = "0"
        panCountText = "1"
        standardPanWeightKgText = "0"
        autoSelected = []
        autoStandardPerPanKgTextById = [:]
    }
    
    private func applyTemplate(_ t: AutoMaterialExportTemplate) {
        selectedTemplateId = t.id
        draftName = t.name
        headerName = t.data.headerName
        freshTitle = t.data.freshTitle
        afterBoilTitle = t.data.afterBoilTitle
        panCountTitle = t.data.panCountTitle
        panWeightTitle = t.data.panWeightTitle
        autoMaterialsTitle = t.data.autoMaterialsTitle
        
        freshSelected = Set(t.data.freshSelectedMaterialIds)
        var freshMap: [UUID: String] = [:]
        for id in t.data.freshSelectedMaterialIds {
            let g = t.data.freshExportGramsByMaterialId[id.uuidString] ?? 0
            freshMap[id] = FormatUtils.formatKgDecimal(fromGrams: g)
        }
        freshExportKgTextById = freshMap
        
        afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: t.data.afterBoilGrams)
        panCountText = String(t.data.panCount)
        standardPanWeightKgText = FormatUtils.formatKgDecimal(fromGrams: t.data.standardPanWeightGrams)
        
        autoSelected = Set(t.data.autoSelectedMaterialIds)
        var autoMap: [UUID: String] = [:]
        for id in t.data.autoSelectedMaterialIds {
            let g = t.data.autoStandardPerPanGramsByMaterialId[id.uuidString] ?? 0
            autoMap[id] = FormatUtils.formatKgDecimal(fromGrams: g)
        }
        autoStandardPerPanKgTextById = autoMap
    }
    
    private func buildTemplate() -> AutoMaterialExportTemplate {
        let now = Date()
        let id = selectedTemplateId ?? UUID()
        let data = AutoMaterialExportTemplateData(
            headerName: headerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draftName : headerName,
            freshTitle: freshTitle,
            afterBoilTitle: afterBoilTitle,
            panCountTitle: panCountTitle,
            panWeightTitle: panWeightTitle,
            autoMaterialsTitle: autoMaterialsTitle,
            freshSelectedMaterialIds: Array(freshSelected),
            freshExportGramsByMaterialId: freshSelected.reduce(into: [:]) { dict, id in
                dict[id.uuidString] = max(0, FormatUtils.parseKgDecimalToGrams(freshExportKgTextById[id] ?? "") ?? 0)
            },
            afterBoilGrams: afterBoilGrams,
            panCount: panCount,
            standardPanWeightGrams: standardPanWeightGrams,
            autoSelectedMaterialIds: Array(autoSelected),
            autoStandardPerPanGramsByMaterialId: autoSelected.reduce(into: [:]) { dict, id in
                dict[id.uuidString] = max(0, FormatUtils.parseKgDecimalToGrams(autoStandardPerPanKgTextById[id] ?? "") ?? 0)
            }
        )
        let createdAt: Date
        let updatedAt: Date
        if let existing = viewModel.autoMaterialExportTemplates.first(where: { $0.id == id }) {
            createdAt = existing.createdAt
            updatedAt = now
        } else {
            createdAt = now
            updatedAt = now
        }
        return AutoMaterialExportTemplate(id: id, name: draftName.isEmpty ? defaultHeaderName : draftName, data: data, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    private func saveTemplate() async {
        isSavingTemplate = true
        defer { isSavingTemplate = false }
        let template = buildTemplate()
        let ok = await viewModel.upsertAutoMaterialExportTemplate(template)
        if ok {
            selectedTemplateId = template.id
        }
    }
    
    private func validate() -> String? {
        if panCount <= 0 { return "Số chảo phải > 0" }
        if freshSelected.isEmpty && autoSelected.isEmpty { return "Cần chọn ít nhất 1 nguyên liệu" }
        if totalExportByMaterialName.contains(where: { $0.grams <= 0 }) { return "Tổng xuất phải > 0" }
        if totalExportByMaterialName.contains(where: { $0.isOver }) { return "Có nguyên liệu vượt tồn kho" }
        return nil
    }
    
    private func confirmExport() async {
        if let err = validate() {
            lastValidationError = err
            return
        }
        let templateName = draftName.isEmpty ? defaultHeaderName : draftName
        let ok = await viewModel.performAutoMaterialExport(
            mode: "Xuất nguyên liệu",
            templateId: selectedTemplateId,
            templateName: templateName,
            headerName: headerName.isEmpty ? templateName : headerName,
            freshTitle: freshTitle,
            afterBoilTitle: afterBoilTitle,
            panCountTitle: panCountTitle,
            panWeightTitle: panWeightTitle,
            autoMaterialsTitle: autoMaterialsTitle,
            freshRows: freshRows,
            afterBoilGrams: afterBoilGrams,
            panCount: panCount,
            standardPanWeightGrams: standardPanWeightGrams,
            actualPanWeightGrams: actualPanWeightGrams,
            percentChange: percentChange,
            autoRows: autoRows
        )
        if ok {
            await saveTemplate()
            dismiss()
        } else {
            lastValidationError = "Không thể xuất tự động"
        }
    }
}

private struct FreshRowView: View {
    let name: String
    let stockText: String
    @Binding var valueText: String
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                Text("Kho: \(stockText)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            TextField("Kg", text: $valueText)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                .frame(width: 120)
        }
    }
}

private struct AutoRowView: View {
    let name: String
    let stockText: String
    @Binding var standardText: String
    let perPanActualText: String
    let totalText: String
    let isOver: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
                Text("Kho: \(stockText)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chuẩn / chảo")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    TextField("Kg", text: $standardText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("/Chảo (thực tế)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(perPanActualText)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tổng xuất")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(totalText)
                        .fontWeight(.bold)
                        .foregroundStyle(isOver ? .red : Color.themePrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
            }
        }
    }
}

private struct MaterialMultiSelectSheet: View {
    let title: String
    let materials: [MaterialItem]
    let selected: Set<UUID>
    let onDone: (Set<UUID>) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var localSelected: Set<UUID>
    @State private var searchText: String = ""
    
    init(title: String, materials: [MaterialItem], selected: Set<UUID>, onDone: @escaping (Set<UUID>) -> Void) {
        self.title = title
        self.materials = materials
        self.selected = selected
        self.onDone = onDone
        _localSelected = State(initialValue: selected)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.id) { m in
                    Button {
                        if localSelected.contains(m.id) { localSelected.remove(m.id) }
                        else { localSelected.insert(m.id) }
                    } label: {
                        HStack {
                            Text(m.name)
                                .foregroundStyle(Color.themeTextDark)
                            Spacer()
                            if localSelected.contains(m.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.themePrimary)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        onDone(localSelected)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filtered: [MaterialItem] {
        let t = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return materials }
        return materials.filter { $0.name.lowercased().contains(t.lowercased()) }
    }
}
