import SwiftUI

/// State riêng cho mỗi sub-sheet trong "Xuất tự động"
private struct SubSheetState: Identifiable {
    let id: UUID
    var name: String
    var afterBoilKgText: String = "0"
    var panCountText: String = "1"
    var standardPanWeightKgText: String = "0"
    var surplusThresholdKg: Int = 0
    var autoStandardPerPanKgTextById: [UUID: String] = [:]

    // Popover states
    var showAfterBoilInfo: Bool = false
    var showPanWeightStdInfo: Bool = false
    var showPanCountInfo: Bool = false
    var showPanWeightActualInfo: Bool = false
    var showAutoInfo: Bool = false
    var showSurplusWheel: Bool = false
    var surplusWheelMax: Int = 100

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    var afterBoilGrams: Int { max(0, FormatUtils.parseKgDecimalToGrams(afterBoilKgText) ?? 0) }
    var standardPanWeightGrams: Int { max(0, FormatUtils.parseKgDecimalToGrams(standardPanWeightKgText) ?? 0) }
    var panCount: Int { max(0, Int(panCountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) }

    var surplusGrams: Int {
        guard standardPanWeightGrams > 0, panCount > 0 else { return 0 }
        return max(0, afterBoilGrams - standardPanWeightGrams * panCount)
    }
    var needsExtraPan: Bool {
        guard surplusThresholdKg > 0 else { return false }
        return surplusGrams > surplusThresholdKg * 1000
    }
    var actualPanWeightGrams: Double {
        if needsExtraPan { return Double(standardPanWeightGrams) }
        guard panCount > 0 else { return 0 }
        return Double(afterBoilGrams) / Double(panCount)
    }
    var percentChange: Double {
        guard standardPanWeightGrams > 0 else { return 0 }
        return actualPanWeightGrams / Double(standardPanWeightGrams)
    }

    mutating func autoCalcPanCount() {
        if standardPanWeightGrams > 0 {
            panCountText = String(max(1, afterBoilGrams / standardPanWeightGrams))
        }
    }
}

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
    @State private var surplusThresholdKg: Int = 0  // Khối lượng dư trên (kg)
    
    @State private var autoSelected: Set<UUID> = []
    @State private var autoStandardPerPanKgTextById: [UUID: String] = [:]
    
    @State private var subSheets: [String] = []
    @State private var subSheetStates: [SubSheetState] = []
    
    @State private var showTemplatePicker = false
    @State private var showFreshPicker = false
    @State private var showAutoPicker = false
    @State private var isSavingTemplate = false
    @State private var showConfirmAlert = false
    @State private var isSavingExport = false
    @State private var lastValidationError: String?
    @State private var showTemplateManager = false
    @State private var newTemplateName: String = ""
    @State private var showRenameSheetPrompt = false
    @State private var renameSheetText: String = ""
    @State private var lastSavedTemplateId: UUID?
    @State private var lastSavedTemplateName: String = ""
    @State private var lastSavedTemplateData: AutoMaterialExportTemplateData?
    @State private var savePulse = false
    @State private var freshUseAllStockIds: Set<UUID> = []
    
    @State private var showWeightWheel = false
    @State private var weightWheelKgSelection = 0
    @State private var weightWheelGramsSelection = 0
    @State private var weightWheelKgMax = 200
    @State private var weightWheelKgRangeBase = 0
    @State private var weightWheelTarget: WeightWheelTarget?
    
    @State private var showIntWheel = false
    @State private var intWheelSelection = 1
    @State private var intWheelMax = 200
    @State private var intWheelRangeBase = 0
    
    @State private var showSurplusWheel = false
    @State private var surplusWheelMax = 100
    
    @State private var showUnsavedCloseAlert = false
    @State private var showUnsavedSwitchAlert = false
    @State private var pendingTemplateToSwitch: AutoMaterialExportTemplate?
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showPrintSheet = false
    @State private var resolvedAutoSTT: String? = nil
    @State private var showFreshInfoPopover = false
    @State private var showAutoInfoPopover = false
    @State private var showAfterBoilInfoPopover = false
    @State private var showPanCountInfoPopover = false
    @State private var showPanWeightStdInfoPopover = false
    @State private var showPanWeightActualInfoPopover = false

    init(viewModel: OrderViewModel, defaultHeaderName: String) {
        self.viewModel = viewModel
        self.defaultHeaderName = defaultHeaderName
        _headerName = State(initialValue: defaultHeaderName)
        _draftName = State(initialValue: defaultHeaderName)
        _afterBoilKgText = State(initialValue: "0")
        _standardPanWeightKgText = State(initialValue: "0")
        _lastSavedTemplateName = State(initialValue: defaultHeaderName)
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
        if needsExtraPan {
            return Double(standardPanWeightGrams)
        }
        guard panCount > 0 else { return 0 }
        return Double(afterBoilGrams) / Double(panCount)
    }
    
    private var percentChange: Double {
        guard standardPanWeightGrams > 0 else { return 0 }
        return actualPanWeightGrams / Double(standardPanWeightGrams)
    }
    
    // Số dư sau khi chia đều: afterBoilGrams - standardPanWeightGrams * panCount
    private var surplusGrams: Int {
        guard standardPanWeightGrams > 0, panCount > 0 else { return 0 }
        return max(0, afterBoilGrams - standardPanWeightGrams * panCount)
    }
    
    // Có cần tách chảo thêm không: surplusThresholdKg > 0 và số dư > ngưỡng
    private var needsExtraPan: Bool {
        guard surplusThresholdKg > 0 else { return false }
        return surplusGrams > surplusThresholdKg * 1000
    }
    
    private func autoCalcPanCount() {
        let stdGrams = standardPanWeightGrams
        let boilGrams = afterBoilGrams
        if stdGrams > 0 {
            let count = boilGrams / stdGrams
            panCountText = String(max(1, count))
        }
    }
    
    private var freshRows: [AutoMaterialExportLogRow] {
        freshSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let value: Double
            if m.unit?.lowercased() == "cái" {
                value = Double(max(0, Int(freshExportKgTextById[id] ?? "") ?? 0))
            } else {
                value = Double(max(0, FormatUtils.parseKgDecimalToGrams(freshExportKgTextById[id] ?? "") ?? 0))
            }
            return AutoMaterialExportLogRow(
                id: UUID(),
                materialId: m.id,
                name: m.name,
                stockGrams: m.stockQuantity,
                standardPerPanGrams: nil,
                actualPerPanGrams: nil,
                totalExportGrams: value
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    private var autoRows: [AutoMaterialExportLogRow] {
        autoSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let standard: Double
            if m.unit?.lowercased() == "cái" {
                standard = Double(max(0, Int(autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            } else {
                standard = Double(max(0, FormatUtils.parseKgDecimalToGrams(autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            }
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
    
    // Nguyên liệu xuất cho chảo xào thêm: tỉ lệ = surplusGrams / standardPanWeightGrams
    private var autoRowsForExtraPan: [AutoMaterialExportLogRow] {
        guard needsExtraPan, standardPanWeightGrams > 0 else { return [] }
        let ratio = Double(surplusGrams) / Double(standardPanWeightGrams)
        return autoSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let standard: Double
            if m.unit?.lowercased() == "cái" {
                standard = Double(max(0, Int(autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            } else {
                standard = Double(max(0, FormatUtils.parseKgDecimalToGrams(autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            }
            let total = standard * ratio
            return AutoMaterialExportLogRow(
                id: UUID(),
                materialId: m.id,
                name: m.name,
                stockGrams: m.stockQuantity,
                standardPerPanGrams: standard,
                actualPerPanGrams: total,
                totalExportGrams: total
            )
        }
        .sorted { $0.name < $1.name }
    }

    // Auto rows cho một sub-sheet cụ thể
    private func autoRowsForSubSheet(_ i: Int) -> [AutoMaterialExportLogRow] {
        guard i < subSheetStates.count else { return [] }
        let s = subSheetStates[i]
        return autoSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let standard: Double
            if m.unit?.lowercased() == "cái" {
                standard = Double(max(0, Int(s.autoStandardPerPanKgTextById[id] ?? autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            } else {
                standard = Double(max(0, FormatUtils.parseKgDecimalToGrams(s.autoStandardPerPanKgTextById[id] ?? autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            }
            let perPanActual = standard * s.percentChange
            let total = perPanActual * Double(s.panCount)
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

    // Extra pan rows cho một sub-sheet
    private func autoRowsForExtraPanSubSheet(_ i: Int) -> [AutoMaterialExportLogRow] {
        guard i < subSheetStates.count else { return [] }
        let s = subSheetStates[i]
        guard s.needsExtraPan, s.standardPanWeightGrams > 0 else { return [] }
        let ratio = Double(s.surplusGrams) / Double(s.standardPanWeightGrams)
        return autoSelected.compactMap { id in
            guard let m = materialsById[id] else { return nil }
            let standard: Double
            if m.unit?.lowercased() == "cái" {
                standard = Double(max(0, Int(s.autoStandardPerPanKgTextById[id] ?? autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            } else {
                standard = Double(max(0, FormatUtils.parseKgDecimalToGrams(s.autoStandardPerPanKgTextById[id] ?? autoStandardPerPanKgTextById[id] ?? "") ?? 0))
            }
            let total = standard * ratio
            return AutoMaterialExportLogRow(
                id: UUID(),
                materialId: m.id,
                name: m.name,
                stockGrams: m.stockQuantity,
                standardPerPanGrams: standard,
                actualPerPanGrams: total,
                totalExportGrams: total
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    private var totalExportByMaterialName: [(name: String, grams: Int, stock: Int, isOver: Bool)] {
        var map: [String: (g: Int, stock: Int)] = [:]

        func addRows(_ rows: [AutoMaterialExportLogRow]) {
            for r in rows {
                let g = Int(max(0, r.totalExportGrams.rounded()))
                map[r.name, default: (0, r.stockGrams)].g += g
                map[r.name, default: (0, r.stockGrams)].stock = r.stockGrams
            }
        }

        if subSheetStates.isEmpty {
            // Không có sub-sheet: dùng state chính
            addRows(freshRows)
            addRows(autoRows)
            addRows(autoRowsForExtraPan)
        } else {
            // Có sub-sheet: cộng fresh từ state chính + auto từ từng sub-sheet
            addRows(freshRows)
            for i in subSheetStates.indices {
                addRows(autoRowsForSubSheet(i))
                addRows(autoRowsForExtraPanSubSheet(i))
            }
        }

        return map.keys.sorted().map { k in
            let v = map[k] ?? (0, 0)
            return (k, v.g, v.stock, v.g > v.stock)
        }
    }
    
    private var canConfirm: Bool {
        validationIssues.isEmpty
    }

    private var validationIssues: [String] {
        var issues: [String] = []

        if freshSelected.isEmpty && autoSelected.isEmpty {
            issues.append("Cần chọn ít nhất 1 nguyên liệu.")
        }

        if afterBoilGrams <= 0 {
            issues.append("Còn sau luộc phải > 0 kg.")
        }

        let zeroFreshNames = freshRows
            .filter { Int($0.totalExportGrams.rounded()) <= 0 }
            .map { $0.name }
        if !zeroFreshNames.isEmpty {
            issues.append("Nguyên liệu tươi chưa nhập số lượng: \(zeroFreshNames.joined(separator: ", ")).")
        }

        if subSheetStates.isEmpty {
            // Validation cho mode không có sub-sheet
            if standardPanWeightGrams <= 0 {
                issues.append("Khối lượng/chảo (Chuẩn) phải > 0 kg để tính số lượng chảo.")
            }
            if panCount <= 0 {
                issues.append("Số lượng chảo xào phải > 0 (được tính từ Còn sau luộc / Chuẩn).")
            }
            let zeroAutoNames = autoRows
                .filter { Int($0.totalExportGrams.rounded()) <= 0 }
                .map { $0.name }
            if !zeroAutoNames.isEmpty {
                issues.append("Nguyên liệu xuất tự động chưa hợp lệ (tổng xuất = 0): \(zeroAutoNames.joined(separator: ", ")).")
            }
        } else {
            // Validation cho từng sub-sheet
            for (i, s) in subSheetStates.enumerated() {
                let label = s.name.isEmpty ? "Sub-sheet \(i + 1)" : s.name
                if s.afterBoilGrams <= 0 {
                    issues.append("\(label): Khối lượng sau luộc cần dùng phải > 0 kg.")
                }
                if s.standardPanWeightGrams <= 0 {
                    issues.append("\(label): Khối lượng chuẩn/chảo phải > 0 kg.")
                }
                if s.panCount <= 0 {
                    issues.append("\(label): Số chảo xào phải > 0.")
                }
                if !autoSelected.isEmpty {
                    let zeroNames = autoRowsForSubSheet(i)
                        .filter { Int($0.totalExportGrams.rounded()) <= 0 }
                        .map { $0.name }
                    if !zeroNames.isEmpty {
                        issues.append("\(label): Nguyên liệu chưa hợp lệ (tổng = 0): \(zeroNames.joined(separator: ", ")).")
                    }
                }
            }
            // Kiểm tra tổng afterBoil sub-sheets ≈ main afterBoil
            let totalSub = subSheetStates.reduce(0) { $0 + $1.afterBoilGrams }
            if abs(totalSub - afterBoilGrams) > 100 { // sai lệch > 100g
                issues.append("Tổng khối lượng sau luộc của các sub-sheet (\(FormatUtils.formatKgDecimal(fromGrams: totalSub)) kg) chưa khớp với còn sau luộc (\(FormatUtils.formatKgDecimal(fromGrams: afterBoilGrams)) kg).")
            }
        }

        let overRows = totalExportByMaterialName.filter { $0.isOver }
        if !overRows.isEmpty {
            let msg = overRows
                .prefix(3)
                .map { "\($0.name) (cần: \(FormatUtils.formatWeight($0.grams)), kho: \(FormatUtils.formatWeight($0.stock)))" }
                .joined(separator: "; ")
            issues.append("Có nguyên liệu vượt tồn kho: \(msg).")
        }

        return issues
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    headerSection
                    freshSection
                    afterBoilSection
                    if subSheetStates.isEmpty {
                        // Không có sub-sheet: layout cũ
                        panWeightStandardSection
                        panCountSection
                        panWeightActualSection
                        autoMaterialsSection
                    } else {
                        // Có sub-sheet: mỗi sub-sheet có block riêng
                        ForEach(subSheetStates.indices, id: \.self) { i in
                            subSheetBlock(i)
                        }
                    }
                    summarySection
                    confirmSection
                }
                .animation(.none, value: needsExtraPan)
                .animation(.none, value: surplusThresholdKg)
                .animation(.none, value: subSheetStates.map(\.surplusThresholdKg))
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("Xuất tự động")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isSavingExport {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(.white)
                            Text("Đang lưu phiếu...")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(28)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.7)))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        if hasTemplateChanges {
                            showUnsavedCloseAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveTemplate() }
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(saveButtonTint)
                    .scaleEffect(saveButtonScaleEffect)
                    .opacity(saveButtonOpacity)
                    .shadow(color: saveButtonShadowColor, radius: saveButtonShadowRadius, x: 0, y: saveButtonShadowY)
                    .disabled(isSavingTemplate || !hasTemplateChanges)
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
                    syncSavedSnapshot()
                }
            }
        }
        .onChange(of: afterBoilKgText) { _ in
            autoCalcPanCount()
            // Khi main afterBoil thay đổi, phân bổ lại đều cho tất cả sub-sheets
            guard !subSheetStates.isEmpty else { return }
            let total = afterBoilGrams
            let count = subSheetStates.count
            let perSheet = total / count
            let leftover = total - perSheet * count
            for i in subSheetStates.indices {
                let extra = i == 0 ? leftover : 0
                subSheetStates[i].afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: perSheet + extra)
                subSheetStates[i].autoCalcPanCount()
            }
        }
        .onChange(of: standardPanWeightKgText) { _ in autoCalcPanCount() }
        .onChange(of: hasTemplateChanges) { newValue in
            if newValue {
                savePulse = false
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    savePulse = true
                }
            } else {
                savePulse = false
            }
        }
        .sheet(isPresented: $showTemplateManager) {
            TemplateManagerSheet(
                templates: viewModel.autoMaterialExportTemplates,
                selectedTemplateId: selectedTemplateId,
                newName: $newTemplateName,
                onSelect: { t in
                    if hasTemplateChanges && t.id != selectedTemplateId {
                        pendingTemplateToSwitch = t
                        showUnsavedSwitchAlert = true
                    } else {
                        applyTemplate(t)
                        showTemplateManager = false
                    }
                },
                onCreateAndSave: { name, subs in
                    Task {
                        if hasTemplateChanges {
                            await saveTemplate()
                        }
                        await MainActor.run {
                            createNewTemplate(named: name, subSheets: subs)
                        }
                        await saveTemplate()
                        await MainActor.run {
                            showTemplateManager = false
                        }
                    }
                },
                onDelete: { id in
                    Task { await viewModel.deleteAutoMaterialExportTemplate(id: id) }
                },
                onDeleteSubSheet: { templateId, subIndex in
                    Task {
                        // Tìm template, xoá sub-sheet tại index, upsert lại
                        if var t = viewModel.autoMaterialExportTemplates.first(where: { $0.id == templateId }) {
                            guard subIndex < t.data.subSheets.count else { return }
                            t.data.subSheets.remove(at: subIndex)
                            t.updatedAt = Date()
                            _ = await viewModel.upsertAutoMaterialExportTemplate(t)
                            await viewModel.loadAutoMaterialExportTemplates()
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .sheet(isPresented: $showWeightWheel) {
            WeightWheelSheet(
                kgRangeBase: $weightWheelKgRangeBase,
                kgMax: $weightWheelKgMax,
                kgSelection: $weightWheelKgSelection,
                gramsSelection: $weightWheelGramsSelection,
                onSave: {
                    let grams = weightWheelKgSelection * 1000 + weightWheelGramsSelection
                    applyWeightWheelResult(grams)
                    showWeightWheel = false
                },
                onClose: { showWeightWheel = false }
            )
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $showIntWheel) {
            IntWheelSheet(
                title: "Chỉnh số lượng",
                rangeBase: $intWheelRangeBase,
                maxValue: $intWheelMax,
                selection: $intWheelSelection,
                onSave: {
                    // Kiểm tra nếu đang chỉnh cho sub-sheet
                    if case .subPanCount(let i) = weightWheelTarget, i < subSheetStates.count {
                        subSheetStates[i].panCountText = String(intWheelSelection)
                    } else if case let .fresh(id) = weightWheelTarget {
                        // Handle "cái" units for fresh material
                        freshExportKgTextById[id] = String(intWheelSelection)
                        if let stock = materialsById[id]?.stockQuantity {
                            if intWheelSelection == stock {
                                freshUseAllStockIds.insert(id)
                            } else {
                                freshUseAllStockIds.remove(id)
                            }
                        }
                    } else if case let .autoStandard(id) = weightWheelTarget {
                        // Handle "cái" units for auto standard material
                        autoStandardPerPanKgTextById[id] = String(intWheelSelection)
                    } else if case let .subAfterBoil(i) = weightWheelTarget, i < subSheetStates.count {
                        // sub after boil for "cái"
                        // Wait after boil should still be in kg probably, but just in case
                        subSheetStates[i].afterBoilKgText = String(intWheelSelection)
                        subSheetStates[i].autoCalcPanCount()
                    } else if case let .subStandardPanWeight(i) = weightWheelTarget, i < subSheetStates.count {
                        // sub standard for "cái"
                        subSheetStates[i].standardPanWeightKgText = String(intWheelSelection)
                        subSheetStates[i].autoCalcPanCount()
                    } else if case let .subAutoStandard(i, id) = weightWheelTarget, i < subSheetStates.count {
                        // sub auto standard for "cái"
                        subSheetStates[i].autoStandardPerPanKgTextById[id] = String(intWheelSelection)
                    } else {
                        // Regular pan count
                        panCountText = String(intWheelSelection)
                    }
                    weightWheelTarget = nil
                    showIntWheel = false
                },
                onClose: {
                    weightWheelTarget = nil
                    showIntWheel = false
                }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSurplusWheel) {
            VStack(spacing: 16) {
                Text("Khối lượng dư trên").font(.headline)
                Picker("", selection: $surplusThresholdKg) {
                    ForEach(Array(0...surplusWheelMax), id: \.self) { v in
                        Text(v == 0 ? "Không giới hạn" : "\(v) kg").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: surplusThresholdKg) { v in
                    if v >= surplusWheelMax - 5 { surplusWheelMax += 20 }
                }
                Text("nếu trên thì xào thêm 1 chảo")
                    .font(.caption).foregroundStyle(.gray).italic()
                HStack {
                    Button("Đóng") { showSurplusWheel = false }
                    Spacer()
                    Button("Lưu") { showSurplusWheel = false }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .alert("Đổi tên sheet", isPresented: $showRenameSheetPrompt) {
            TextField("Tên sheet", text: $renameSheetText)
            Button("Hủy", role: .cancel) { }
            Button("Lưu") {
                let trimmed = renameSheetText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    draftName = trimmed
                    headerName = trimmed
                }
            }
        }
        .alert("Lưu thay đổi?", isPresented: $showUnsavedCloseAlert) {
            Button("Không lưu", role: .destructive) { dismiss() }
            Button("Hủy", role: .cancel) { }
            Button("Lưu") {
                Task {
                    await saveTemplate()
                    dismiss()
                }
            }
        } message: {
            Text("Sheet hiện tại có thay đổi chưa lưu. Bạn có muốn lưu lại trước khi đóng không?")
        }
        .alert("Lưu thay đổi?", isPresented: $showUnsavedSwitchAlert) {
            Button("Không lưu", role: .destructive) {
                if let t = pendingTemplateToSwitch { applyTemplate(t) }
                showTemplateManager = false
            }
            Button("Hủy", role: .cancel) { }
            Button("Lưu") {
                Task {
                    await saveTemplate()
                    if let t = pendingTemplateToSwitch { applyTemplate(t) }
                    showTemplateManager = false
                }
            }
        } message: {
            Text("Sheet hiện tại có thay đổi chưa lưu. Bạn có muốn lưu lại trước khi chuyển sang sheet khác không?")
        }
        .alert("Lỗi", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(selectedTemplateName)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Button {
                        renameSheetText = draftName
                        showRenameSheetPrompt = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color.themePrimary, Color.themePrimary.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                Button {
                    newTemplateName = ""
                    showTemplateManager = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var freshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Nguyên liệu tươi", text: $freshTitle)
                    .font(.headline)
                Button {
                    showFreshInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFreshInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cần nhập thủ công", systemImage: "hand.point.up.left.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Nhập khối lượng thực tế của từng nguyên liệu tươi cần xuất kho cho mẻ sản xuất này.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    showFreshPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if freshSelected.isEmpty {
                Text("Chưa chọn nguyên liệu")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(freshRows) { row in
                        Group {
                            if let mid = row.materialId, let m = materialsById[mid] {
                                if m.unit?.lowercased() == "cái" {
                                    let count = max(0, Int(freshExportKgTextById[m.id] ?? "") ?? 0)
                                    FreshRowWheelView(
                                        name: row.name,
                                        stockText: "\(m.stockQuantity) cái",
                                        valueText: "\(count) cái",
                                        isOver: count > m.stockQuantity,
                                        isAll: freshUseAllStockIds.contains(m.id),
                                        onToggleAll: {
                                            if freshUseAllStockIds.contains(m.id) {
                                                freshUseAllStockIds.remove(m.id)
                                            } else {
                                                freshUseAllStockIds.insert(m.id)
                                                freshExportKgTextById[m.id] = String(m.stockQuantity)
                                            }
                                        },
                                        onTap: {
                                            openWeightWheel(target: .fresh(m.id), currentText: freshExportKgTextById[m.id] ?? "0")
                                        }
                                    )
                                } else {
                                    let grams = max(0, FormatUtils.parseKgDecimalToGrams(freshExportKgTextById[m.id] ?? "") ?? 0)
                                    FreshRowWheelView(
                                        name: row.name,
                                        stockText: FormatUtils.formatWeight(m.stockQuantity),
                                        valueText: freshExportKgTextById[m.id] ?? "0",
                                        isOver: grams > m.stockQuantity,
                                        isAll: freshUseAllStockIds.contains(m.id),
                                        onToggleAll: {
                                            if freshUseAllStockIds.contains(m.id) {
                                                freshUseAllStockIds.remove(m.id)
                                            } else {
                                                freshUseAllStockIds.insert(m.id)
                                                freshExportKgTextById[m.id] = FormatUtils.formatKgDecimal(fromGrams: m.stockQuantity)
                                            }
                                        },
                                        onTap: {
                                            openWeightWheel(target: .fresh(m.id), currentText: freshExportKgTextById[m.id] ?? "0")
                                        }
                                    )
                                }
                            } else {
                                FreshRowWheelView(
                                    name: row.name,
                                    stockText: FormatUtils.formatWeight(0),
                                    valueText: "0",
                                    isOver: false,
                                    isAll: false,
                                    onToggleAll: {},
                                    onTap: {}
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var afterBoilSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Còn sau luộc", text: $afterBoilTitle)
                    .font(.headline)
                Button {
                    showAfterBoilInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAfterBoilInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cần nhập thủ công", systemImage: "hand.point.up.left.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Tổng khối lượng nguyên liệu tươi còn lại sau khi luộc/sơ chế. Dùng để tính số chảo xào và khối lượng thực tế mỗi chảo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    openWeightWheel(target: .afterBoil, currentText: afterBoilKgText)
                } label: {
                    Text(FormatUtils.formatKgDecimal(fromGrams: afterBoilGrams))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var panCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Số lượng chảo xào", text: $panCountTitle)
                    .font(.headline)
                Button {
                    showPanCountInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPanCountInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính / có thể chỉnh", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Số chảo được tính tự động từ [Còn sau luộc] ÷ [Khối lượng chuẩn/chảo]. Bạn có thể bấm vào giá trị để chỉnh tay nếu cần.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    intWheelSelection = max(1, panCount)
                    intWheelMax = max(20, intWheelSelection + 200)
                    showIntWheel = true
                } label: {
                    Text("\(panCount)")
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("cái")
                    .font(.caption)
                    .foregroundStyle(.gray)
                // Button setting khối lượng dư trên
                Button {
                    showSurplusWheel = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(surplusThresholdKg > 0 ? Color.orange : Color.gray.opacity(0.5))
                        .padding(8)
                        .background(Circle().fill(surplusThresholdKg > 0 ? Color.orange.opacity(0.12) : Color.gray.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var panWeightStandardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Khối lượng chuẩn / chảo")
                    .font(.headline)
                Button {
                    showPanWeightStdInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPanWeightStdInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cần nhập thủ công", systemImage: "hand.point.up.left.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Khối lượng nguyên liệu tươi tiêu chuẩn cho một chảo xào. Dùng để tính số chảo tự động và làm cơ sở tính định mức nguyên liệu xuất tự động.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    openWeightWheel(target: .standardPanWeight, currentText: standardPanWeightKgText)
                } label: {
                    Text(FormatUtils.formatKgDecimal(fromGrams: standardPanWeightGrams))
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var panWeightActualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Khối lượng thực tế / chảo")
                    .font(.headline)
                Button {
                    showPanWeightActualInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPanWeightActualInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Được tính tự động: [Còn sau luộc] ÷ [Số chảo xào]. Phản ánh khối lượng thực tế mỗi chảo trong mẻ này, dùng để tính lượng nguyên liệu xuất tự động theo tỉ lệ thực tế.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Text(FormatUtils.formatKgDecimal(fromGrams: Int(actualPanWeightGrams.rounded())))
                    .foregroundStyle(Color.themeTextDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            if needsExtraPan {
                Divider()
                
                HStack(spacing: 10) {
                    Text("Số lượng chảo xào thêm")
                        .font(.subheadline)
                        .foregroundStyle(Color.orange)
                    Spacer()
                    Text("1")
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                    Text("cái")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                HStack(spacing: 10) {
                    Text("Khối lượng xào thêm")
                        .font(.subheadline)
                        .foregroundStyle(Color.orange)
                    Spacer()
                    Text(FormatUtils.formatKgDecimal(fromGrams: surplusGrams))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var autoMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Nguyên liệu xuất tự động", text: $autoMaterialsTitle)
                    .font(.headline)
                Button {
                    showAutoInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAutoInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính toán", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        Text("Hệ thống tự tính lượng xuất dựa trên định mức chuẩn/chảo và số chảo thực tế. Bạn chỉ cần nhập định mức chuẩn cho mỗi nguyên liệu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    showAutoPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if autoSelected.isEmpty {
                Text("Chưa chọn nguyên liệu")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 10) {
                    ForEach(autoRows) { row in
                        Group {
                            if let mid = row.materialId, let m = materialsById[mid] {
                                if m.unit?.lowercased() == "cái" {
                                    let standardCount = Int(autoStandardPerPanKgTextById[m.id] ?? "") ?? 0
                                    let perPanActualCount = Int((row.actualPerPanGrams ?? 0).rounded())
                                    let totalCount = Int(row.totalExportGrams.rounded())
                                    AutoRowWheelView(
                                        name: row.name,
                                        stockText: "\(m.stockQuantity) cái",
                                        standardText: "\(standardCount) cái",
                                        perPanActualText: "\(perPanActualCount) cái",
                                        totalText: "\(totalCount) cái",
                                        isOver: totalCount > m.stockQuantity,
                                        onTapStandard: {
                                            openWeightWheel(target: .autoStandard(m.id), currentText: autoStandardPerPanKgTextById[m.id] ?? "0")
                                        }
                                    )
                                } else {
                                    AutoRowWheelView(
                                        name: row.name,
                                        stockText: FormatUtils.formatWeight(row.stockGrams),
                                        standardText: autoStandardPerPanKgTextById[m.id] ?? "0",
                                        perPanActualText: FormatUtils.formatKgDecimal(fromGrams: Int((row.actualPerPanGrams ?? 0).rounded())),
                                        totalText: FormatUtils.formatKgDecimal(fromGrams: Int(row.totalExportGrams.rounded())),
                                        isOver: Int(row.totalExportGrams.rounded()) > row.stockGrams,
                                        onTapStandard: {
                                            openWeightWheel(target: .autoStandard(m.id), currentText: autoStandardPerPanKgTextById[m.id] ?? "0")
                                        }
                                    )
                                }
                            } else {
                                AutoRowWheelView(
                                    name: row.name,
                                    stockText: FormatUtils.formatWeight(0),
                                    standardText: "0",
                                    perPanActualText: "0",
                                    totalText: "0",
                                    isOver: false,
                                    onTapStandard: {}
                                )
                            }
                        }
                    }
                }
                
                // Phần xào thêm — chỉ hiện khi needsExtraPan
                if needsExtraPan && !autoRowsForExtraPan.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.orange)
                            .font(.subheadline)
                        Text("Nguyên liệu xuất tự động cho phần xào thêm")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.orange)
                    }
                    
                    VStack(spacing: 10) {
                        ForEach(autoRowsForExtraPan) { row in
                            Group {
                                if let mat = row.materialId.flatMap({ materialsById[$0] }) {
                                    if mat.unit?.lowercased() == "cái" {
                                        let totalCount = Int(row.totalExportGrams.rounded())
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(row.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.orange)
                                                Text("Kho: \(mat.stockQuantity) cái")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            Spacer()
                                            Text("\(totalCount) cái")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                        }
                                    } else {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(row.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.orange)
                                                Text("Kho: \(FormatUtils.formatWeight(row.stockGrams))")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            Spacer()
                                            Text(FormatUtils.formatKgDecimal(fromGrams: Int(row.totalExportGrams.rounded())))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                            Text("kg")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                } else {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.name)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.orange)
                                            Text("Kho: \(FormatUtils.formatWeight(0))")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text("0")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .animation(.none, value: needsExtraPan)
    }

    // MARK: - Sub-sheet block

    @ViewBuilder
    private func subSheetBlock(_ i: Int) -> some View {
        let s = subSheetStates[i]

        // Header button cho sub-sheet
        Button {
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 14, weight: .semibold))
                Text(s.name.isEmpty ? "Sub-sheet \(i + 1)" : s.name)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color.themePrimary.opacity(0.75), Color.themePrimary.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)

        // Khối lượng sau luộc cần dùng
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Khối lượng sau luộc cần dùng")
                    .font(.headline)
                Button { subSheetStates[i].showAfterBoilInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $subSheetStates[i].showAfterBoilInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cần nhập thủ công", systemImage: "hand.point.up.left.fill")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                        Text("Khối lượng nguyên liệu tươi còn lại sau luộc dành riêng cho sub-sheet này. Dùng để tính số chảo và khối lượng thực tế/chảo.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    openWeightWheel(target: .subAfterBoil(i), currentText: s.afterBoilKgText)
                } label: {
                    Text(FormatUtils.formatKgDecimal(fromGrams: s.afterBoilGrams))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("kg").font(.caption).foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

        // Khối lượng chuẩn / chảo
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Khối lượng chuẩn / chảo")
                    .font(.headline)
                Button { subSheetStates[i].showPanWeightStdInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $subSheetStates[i].showPanWeightStdInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cần nhập thủ công", systemImage: "hand.point.up.left.fill")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                        Text("Khối lượng nguyên liệu tươi tiêu chuẩn cho một chảo xào. Dùng để tính số chảo tự động và làm cơ sở tính định mức nguyên liệu xuất tự động.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    openWeightWheel(target: .subStandardPanWeight(i), currentText: s.standardPanWeightKgText)
                } label: {
                    Text(FormatUtils.formatKgDecimal(fromGrams: s.standardPanWeightGrams))
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("kg").font(.caption).foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

        // Số lượng chảo xào
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Số lượng chảo xào")
                    .font(.headline)
                Button { subSheetStates[i].showPanCountInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $subSheetStates[i].showPanCountInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính / có thể chỉnh", systemImage: "sparkles")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                        Text("Số chảo được tính tự động từ [Khối lượng sau luộc cần dùng] ÷ [Khối lượng chuẩn/chảo]. Bạn có thể bấm vào giá trị để chỉnh tay nếu cần.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Button {
                    intWheelSelection = max(1, s.panCount)
                    intWheelMax = max(20, intWheelSelection + 200)
                    weightWheelTarget = .subPanCount(i)
                    showIntWheel = true
                } label: {
                    Text("\(s.panCount)")
                        .foregroundStyle(Color.themeTextDark)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text("cái").font(.caption).foregroundStyle(.gray)
                // Button setting khối lượng dư trên
                Button { subSheetStates[i].showSurplusWheel = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(s.surplusThresholdKg > 0 ? Color.orange : Color.gray.opacity(0.5))
                        .padding(8)
                        .background(Circle().fill(s.surplusThresholdKg > 0 ? Color.orange.opacity(0.12) : Color.gray.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $subSheetStates[i].showSurplusWheel) {
                    VStack(spacing: 16) {
                        Text("Khối lượng dư trên").font(.headline)
                        Picker("", selection: $subSheetStates[i].surplusThresholdKg) {
                            ForEach(Array(0...subSheetStates[i].surplusWheelMax), id: \.self) { v in
                                Text(v == 0 ? "Không giới hạn" : "\(v) kg").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: subSheetStates[i].surplusThresholdKg) { v in
                            if v >= subSheetStates[i].surplusWheelMax - 5 {
                                subSheetStates[i].surplusWheelMax += 20
                            }
                        }
                        Text("nếu trên thì xào thêm 1 chảo")
                            .font(.caption).foregroundStyle(.gray).italic()
                        HStack {
                            Button("Đóng") { subSheetStates[i].showSurplusWheel = false }
                            Spacer()
                            Button("Lưu") { subSheetStates[i].showSurplusWheel = false }
                        }
                        .font(.headline)
                    }
                    .padding()
                    .presentationDetents([.height(300)])
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

        // Khối lượng thực tế / chảo
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Khối lượng thực tế / chảo")
                    .font(.headline)
                Button { subSheetStates[i].showPanWeightActualInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $subSheetStates[i].showPanWeightActualInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính", systemImage: "sparkles")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                        Text("Được tính tự động: [Khối lượng sau luộc cần dùng] ÷ [Số chảo xào]. Dùng để tính lượng nguyên liệu xuất tự động theo tỉ lệ thực tế.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Text(FormatUtils.formatKgDecimal(fromGrams: Int(s.actualPanWeightGrams.rounded())))
                    .foregroundStyle(Color.themeTextDark)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                Text("kg").font(.caption).foregroundStyle(.gray)
            }

            if s.needsExtraPan {
                Divider()
                HStack(spacing: 10) {
                    Text("Số lượng chảo xào thêm").font(.subheadline).foregroundStyle(Color.orange)
                    Spacer()
                    Text("1").foregroundStyle(Color.orange)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                    Text("cái").font(.caption).foregroundStyle(.gray)
                }
                HStack(spacing: 10) {
                    Text("Khối lượng xào thêm").font(.subheadline).foregroundStyle(Color.orange)
                    Spacer()
                    Text(FormatUtils.formatKgDecimal(fromGrams: s.surplusGrams))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                    Text("kg").font(.caption).foregroundStyle(.gray)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

        // Nguyên liệu xuất tự động
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(autoMaterialsTitle)
                    .font(.headline)
                Button { subSheetStates[i].showAutoInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $subSheetStates[i].showAutoInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tự động tính toán", systemImage: "sparkles")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                        Text("Hệ thống tự tính lượng xuất dựa trên định mức chuẩn/chảo và số chảo thực tế. Bạn chỉ cần nhập định mức chuẩn cho mỗi nguyên liệu.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14).frame(width: 260)
                    .presentationCompactAdaptation(.popover)
                }
                Spacer()
                // Icon setting để chọn nguyên liệu (dùng chung showAutoPicker)
                Button { showAutoPicker = true } label: {
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            if autoSelected.isEmpty {
                Text("Chưa chọn nguyên liệu").foregroundStyle(.gray)
            } else {
                let rows = autoRowsForSubSheet(i)
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        Group {
                            if let mid = row.materialId, let m = materialsById[mid] {
                                if m.unit?.lowercased() == "cái" {
                                    let standardCount = Int(subSheetStates[i].autoStandardPerPanKgTextById[m.id] ?? autoStandardPerPanKgTextById[m.id] ?? "") ?? 0
                                    let perPanActualCount = Int((row.actualPerPanGrams ?? 0).rounded())
                                    let totalCount = Int(row.totalExportGrams.rounded())
                                    AutoRowWheelView(
                                        name: row.name,
                                        stockText: "\(m.stockQuantity) cái",
                                        standardText: "\(standardCount) cái",
                                        perPanActualText: "\(perPanActualCount) cái",
                                        totalText: "\(totalCount) cái",
                                        isOver: totalCount > m.stockQuantity,
                                        onTapStandard: {
                                            openWeightWheel(target: .subAutoStandard(i, m.id), currentText: subSheetStates[i].autoStandardPerPanKgTextById[m.id] ?? autoStandardPerPanKgTextById[m.id] ?? "0")
                                        }
                                    )
                                } else {
                                    AutoRowWheelView(
                                        name: row.name,
                                        stockText: FormatUtils.formatWeight(row.stockGrams),
                                        standardText: subSheetStates[i].autoStandardPerPanKgTextById[m.id] ?? autoStandardPerPanKgTextById[m.id] ?? "0",
                                        perPanActualText: FormatUtils.formatKgDecimal(fromGrams: Int((row.actualPerPanGrams ?? 0).rounded())),
                                        totalText: FormatUtils.formatKgDecimal(fromGrams: Int(row.totalExportGrams.rounded())),
                                        isOver: Int(row.totalExportGrams.rounded()) > row.stockGrams,
                                        onTapStandard: {
                                            openWeightWheel(target: .subAutoStandard(i, m.id), currentText: subSheetStates[i].autoStandardPerPanKgTextById[m.id] ?? autoStandardPerPanKgTextById[m.id] ?? "0")
                                        }
                                    )
                                }
                            } else {
                                AutoRowWheelView(
                                    name: row.name,
                                    stockText: FormatUtils.formatWeight(0),
                                    standardText: "0",
                                    perPanActualText: "0",
                                    totalText: "0",
                                    isOver: false,
                                    onTapStandard: {}
                                )
                            }
                        }
                    }
                }

                let extraRows = autoRowsForExtraPanSubSheet(i)
                if s.needsExtraPan && !extraRows.isEmpty {
                    Divider().padding(.vertical, 4)
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.orange).font(.subheadline)
                        Text("Nguyên liệu xuất tự động cho phần xào thêm")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.orange)
                    }
                    VStack(spacing: 10) {
                        ForEach(extraRows) { row in
                            Group {
                                if let m = row.materialId.flatMap({ materialsById[$0] }) {
                                    if m.unit?.lowercased() == "cái" {
                                        let totalCount = Int(row.totalExportGrams.rounded())
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(row.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.orange)
                                                Text("Kho: \(m.stockQuantity) cái")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            Spacer()
                                            Text("\(totalCount) cái")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                        }
                                    } else {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(row.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.orange)
                                                Text("Kho: \(FormatUtils.formatWeight(row.stockGrams))")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            Spacer()
                                            Text(FormatUtils.formatKgDecimal(fromGrams: Int(row.totalExportGrams.rounded())))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.orange)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                            Text("kg")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                } else {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.name)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.orange)
                                            Text("Kho: \(FormatUtils.formatWeight(0))")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text("0")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
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
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var confirmSection: some View {
        VStack(spacing: 10) {
            // Print button
            Button {
                let issues = validationIssues
                if !issues.isEmpty {
                    errorAlertMessage = "Vui lòng kiểm tra:\n• " + issues.joined(separator: "\n• ")
                    showErrorAlert = true
                    return
                }
                Task {
                    // Resolve STT XNL trước khi in
                    if resolvedAutoSTT == nil {
                        let n = await SupabaseDatabaseService().nextSequenceNumber(type: SequenceType.materialExport)
                        let base = viewModel.currentSequenceNumber ?? FormatUtils.generateSequenceNumber()
                        let parts = base.split(separator: "-", maxSplits: 2).map(String.init)
                        let dt = parts.count >= 2 ? "\(parts[0])-\(parts[1])" : base
                        resolvedAutoSTT = "\(dt)-\(SequenceType.materialExport)-\(n)"
                        viewModel.currentSequenceNumber = resolvedAutoSTT
                    }
                    showPrintSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "printer.fill")
                    Text("In phiếu xuất")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.12))
                .foregroundStyle(Color.themeTextDark)
                .cornerRadius(16)
            }
            .disabled(isSavingTemplate)

            // Confirm button
            Button {
                let issues = validationIssues
                if !issues.isEmpty {
                    errorAlertMessage = "Vui lòng kiểm tra:\n• " + issues.joined(separator: "\n• ")
                    showErrorAlert = true
                    return
                }
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
            .disabled(isSavingTemplate)
            
            if !canConfirm {
                Text("Kiểm tra số chảo, số lượng và tồn kho trước khi xác nhận")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .sheet(isPresented: $showPrintSheet) {
            ExportSlipShareSheet(
                templateName: resolvedTemplateName,
                creatorName: AuthManager.shared.currentUserProfile?.fullName ?? "",
                date: Date(),
                freshTitle: freshTitle,
                freshRows: freshRows,
                afterBoilTitle: afterBoilTitle,
                afterBoilGrams: afterBoilGrams,
                panCountTitle: panCountTitle,
                panCount: panCount,
                panWeightTitle: panWeightTitle,
                standardPanWeightGrams: standardPanWeightGrams,
                actualPanWeightGrams: actualPanWeightGrams,
                autoMaterialsTitle: autoMaterialsTitle,
                autoRows: subSheetStates.isEmpty ? autoRows : [],
                extraPanRows: subSheetStates.isEmpty ? autoRowsForExtraPan : [],
                subSheetSlips: subSheetStates.indices.map { i in
                    SubSheetSlipData(
                        name: subSheetStates[i].name,
                        afterBoilGrams: subSheetStates[i].afterBoilGrams,
                        panCount: subSheetStates[i].panCount,
                        standardPanWeightGrams: subSheetStates[i].standardPanWeightGrams,
                        actualPanWeightGrams: subSheetStates[i].actualPanWeightGrams,
                        autoRows: autoRowsForSubSheet(i),
                        extraPanRows: autoRowsForExtraPanSubSheet(i)
                    )
                },
                sequenceNumber: resolvedAutoSTT,
                onConfirmAfterShare: {
                    Task { await confirmExport() }
                }
            )
        }
    }
    
    private var selectedTemplateName: String {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let id = selectedTemplateId, let t = viewModel.autoMaterialExportTemplates.first(where: { $0.id == id }) {
            return t.name
        }
        return defaultHeaderName
    }
    
    private func createNewTemplate(named name: String? = nil, subSheets newSubSheets: [String] = []) {
        selectedTemplateId = nil
        draftName = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? name! : defaultHeaderName
        headerName = draftName
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
        surplusThresholdKg = 0
        autoSelected = []
        autoStandardPerPanKgTextById = [:]
        subSheets = newSubSheets
        subSheetStates = newSubSheets.map { name in
            var s = SubSheetState(name: name)
            // Default afterBoil = half của main (hiện tại = 0 vì mới tạo, sẽ cập nhật khi user nhập)
            s.afterBoilKgText = "0"
            return s
        }
        syncSavedSnapshot()
    }
    
    private func applyTemplate(_ t: AutoMaterialExportTemplate) {
        selectedTemplateId = t.id
        draftName = t.name
        headerName = t.data.headerName.isEmpty ? t.name : t.data.headerName
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
        surplusThresholdKg = t.data.surplusThresholdKg
        
        autoSelected = Set(t.data.autoSelectedMaterialIds)
        var autoMap: [UUID: String] = [:]
        for id in t.data.autoSelectedMaterialIds {
            let g = t.data.autoStandardPerPanGramsByMaterialId[id.uuidString] ?? 0
            autoMap[id] = FormatUtils.formatKgDecimal(fromGrams: g)
        }
        autoStandardPerPanKgTextById = autoMap
        subSheets = t.data.subSheets
        // Load sub-sheet states từ subSheetData nếu có, fallback về tên từ subSheets
        let savedData = t.data.subSheetData
        subSheetStates = t.data.subSheets.enumerated().map { (i, name) in
            var s = SubSheetState(name: name)
            if i < savedData.count {
                let d = savedData[i]
                s.afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: d.afterBoilGrams)
                s.panCountText = String(d.panCount)
                s.standardPanWeightKgText = FormatUtils.formatKgDecimal(fromGrams: d.standardPanWeightGrams)
                s.surplusThresholdKg = d.surplusThresholdKg
                var autoMap: [UUID: String] = [:]
                for id in t.data.autoSelectedMaterialIds {
                    let g = d.autoStandardPerPanGramsByMaterialId[id.uuidString] ?? 0
                    autoMap[id] = FormatUtils.formatKgDecimal(fromGrams: g)
                }
                s.autoStandardPerPanKgTextById = autoMap
            } else {
                // Default: afterBoil = half của main afterBoil
                let half = t.data.afterBoilGrams / max(1, t.data.subSheets.count)
                s.afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: half)
                s.standardPanWeightKgText = FormatUtils.formatKgDecimal(fromGrams: t.data.standardPanWeightGrams)
                s.autoCalcPanCount()
            }
            return s
        }
        syncSavedSnapshot()
    }
    
    private var resolvedTemplateName: String {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultHeaderName : trimmed
    }
    
    private var currentTemplateData: AutoMaterialExportTemplateData {
        AutoMaterialExportTemplateData(
            headerName: resolvedTemplateName,
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
            surplusThresholdKg: surplusThresholdKg,
            autoSelectedMaterialIds: Array(autoSelected),
            autoStandardPerPanGramsByMaterialId: autoSelected.reduce(into: [:]) { dict, id in
                dict[id.uuidString] = max(0, FormatUtils.parseKgDecimalToGrams(autoStandardPerPanKgTextById[id] ?? "") ?? 0)
            },
            subSheets: subSheets,
            subSheetData: subSheetStates.map { s in
                SubSheetTemplateData(
                    name: s.name,
                    afterBoilGrams: s.afterBoilGrams,
                    panCount: s.panCount,
                    standardPanWeightGrams: s.standardPanWeightGrams,
                    surplusThresholdKg: s.surplusThresholdKg,
                    autoStandardPerPanGramsByMaterialId: autoSelected.reduce(into: [:]) { dict, id in
                        let text = s.autoStandardPerPanKgTextById[id] ?? autoStandardPerPanKgTextById[id] ?? ""
                        dict[id.uuidString] = max(0, FormatUtils.parseKgDecimalToGrams(text) ?? 0)
                    }
                )
            }
        )
    }
    
    private var hasTemplateChanges: Bool {
        guard let savedData = lastSavedTemplateData else { return true }
        if lastSavedTemplateId != selectedTemplateId { return true }
        if lastSavedTemplateName != resolvedTemplateName { return true }
        return savedData != currentTemplateData
    }
    
    @ViewBuilder
    private var saveButtonLabel: some View {
        if isSavingTemplate {
            ProgressView()
        } else {
            Text("Lưu")
                .fontWeight(.bold)
        }
    }
    
    private var saveButtonTint: Color {
        hasTemplateChanges ? .blue : .gray
    }
    
    private var saveButtonScaleEffect: CGFloat {
        hasTemplateChanges ? (savePulse ? 1.14 : 0.92) : 1
    }
    
    private var saveButtonOpacity: Double {
        hasTemplateChanges ? (savePulse ? 1 : 0.75) : 1
    }
    
    private var saveButtonShadowColor: Color {
        hasTemplateChanges ? Color.blue.opacity(savePulse ? 0.55 : 0.18) : .clear
    }
    
    private var saveButtonShadowRadius: CGFloat {
        savePulse ? 10 : 4
    }
    
    private var saveButtonShadowY: CGFloat {
        savePulse ? 6 : 2
    }
    
    private func syncSavedSnapshot() {
        lastSavedTemplateId = selectedTemplateId
        lastSavedTemplateName = resolvedTemplateName
        lastSavedTemplateData = currentTemplateData
    }
    
    private func buildTemplate() -> AutoMaterialExportTemplate {
        let now = Date()
        let id = selectedTemplateId ?? UUID()
        let resolvedName = resolvedTemplateName
        let data = currentTemplateData
        let createdAt: Date
        let updatedAt: Date
        if let existing = viewModel.autoMaterialExportTemplates.first(where: { $0.id == id }) {
            createdAt = existing.createdAt
            updatedAt = now
        } else {
            createdAt = now
            updatedAt = now
        }
        return AutoMaterialExportTemplate(id: id, name: resolvedName, data: data, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    private func saveTemplate() async {
        isSavingTemplate = true
        defer { isSavingTemplate = false }
        let template = buildTemplate()
        let ok = await viewModel.upsertAutoMaterialExportTemplate(template)
        if ok {
            selectedTemplateId = template.id
            syncSavedSnapshot()
        }
    }
    
    private func confirmExport() async {
        let issues = validationIssues
        if !issues.isEmpty {
            errorAlertMessage = "Vui lòng kiểm tra:\n• " + issues.joined(separator: "\n• ")
            showErrorAlert = true
            return
        }
        isSavingExport = true
        let templateName = draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultHeaderName : draftName
        // Chạy song song: export + save template
        async let exportTask = viewModel.performAutoMaterialExport(
            mode: "Xuất nguyên liệu",
            templateId: selectedTemplateId,
            templateName: templateName,
            headerName: templateName,
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
            autoRows: subSheetStates.isEmpty ? autoRows : [],
            extraPanRows: subSheetStates.isEmpty ? autoRowsForExtraPan : [],
            subSheetSlips: subSheetStates.indices.map { i in
                SubSheetSlipForLog(
                    name: subSheetStates[i].name,
                    afterBoilGrams: subSheetStates[i].afterBoilGrams,
                    panCount: subSheetStates[i].panCount,
                    standardPanWeightGrams: subSheetStates[i].standardPanWeightGrams,
                    actualPanWeightGrams: subSheetStates[i].actualPanWeightGrams,
                    autoRows: autoRowsForSubSheet(i),
                    extraPanRows: autoRowsForExtraPanSubSheet(i)
                )
            },
            resolvedSequenceNumber: resolvedAutoSTT
        )
        async let templateTask: Bool = saveTemplateAsync()
        let (ok, _) = await (exportTask, templateTask)
        isSavingExport = false
        if ok {
            dismiss()
        } else {
            lastValidationError = "Không thể xuất tự động"
        }
    }

    /// Lưu template và trả về Bool (để dùng với async let)
    private func saveTemplateAsync() async -> Bool {
        await saveTemplate()
        return true
    }
    
    private func openWeightWheel(target: WeightWheelTarget, currentText: String) {
        // Check if the target is for a material and that material is in "cái" units
        if case let .fresh(id) = target, let mat = materialsById[id], mat.unit?.lowercased() == "cái" {
            // Open IntWheel for "cái" units
            weightWheelTarget = target
            let count = max(0, Int(currentText) ?? 0)
            intWheelSelection = count
            intWheelMax = max(200, count + 200)
            intWheelRangeBase = (count / 100) * 100
            showIntWheel = true
            return
        }
        if case let .autoStandard(id) = target, let mat = materialsById[id], mat.unit?.lowercased() == "cái" {
            // Open IntWheel for "cái" units
            weightWheelTarget = target
            let count = max(0, Int(currentText) ?? 0)
            intWheelSelection = count
            intWheelMax = max(200, count + 200)
            intWheelRangeBase = (count / 100) * 100
            showIntWheel = true
            return
        }
        if case let .subAutoStandard(_, id) = target, let mat = materialsById[id], mat.unit?.lowercased() == "cái" {
            // Open IntWheel for "cái" units
            weightWheelTarget = target
            let count = max(0, Int(currentText) ?? 0)
            intWheelSelection = count
            intWheelMax = max(200, count + 200)
            intWheelRangeBase = (count / 100) * 100
            showIntWheel = true
            return
        }
        // Otherwise, use WeightWheel for weight-based units
        weightWheelTarget = target
        let grams = max(0, FormatUtils.parseKgDecimalToGrams(currentText) ?? 0)
        weightWheelKgSelection = max(0, grams / 1000)
        let remainder = max(0, grams % 1000)
        weightWheelGramsSelection = (remainder / 50) * 50
        weightWheelKgMax = max(200, weightWheelKgSelection + 200)
        weightWheelKgRangeBase = (weightWheelKgSelection / 100) * 100
        showWeightWheel = true
    }
    
    private func applyWeightWheelResult(_ grams: Int) {
        let text = FormatUtils.formatKgDecimal(fromGrams: max(0, grams))
        guard let target = weightWheelTarget else { return }
        switch target {
        case .afterBoil:
            afterBoilKgText = text
        case .standardPanWeight:
            standardPanWeightKgText = text
        case .fresh(let id):
            freshExportKgTextById[id] = text
            if let stock = materialsById[id]?.stockQuantity {
                if grams == stock {
                    freshUseAllStockIds.insert(id)
                } else {
                    freshUseAllStockIds.remove(id)
                }
            } else {
                freshUseAllStockIds.remove(id)
            }
        case .autoStandard(let id):
            autoStandardPerPanKgTextById[id] = text
        case .subAfterBoil(let i):
            guard i < subSheetStates.count else { return }
            // Ràng buộc: tổng afterBoil các sub-sheets = afterBoilGrams (main)
            let newGrams = max(0, min(grams, afterBoilGrams))
            subSheetStates[i].afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: newGrams)
            subSheetStates[i].autoCalcPanCount()
            // Phân bổ phần còn lại đều cho các sub-sheets khác
            let remaining = max(0, afterBoilGrams - newGrams)
            let others = subSheetStates.indices.filter { $0 != i }
            if !others.isEmpty {
                let perOther = remaining / others.count
                let leftover = remaining - perOther * others.count
                for (offset, j) in others.enumerated() {
                    let extra = offset == 0 ? leftover : 0
                    subSheetStates[j].afterBoilKgText = FormatUtils.formatKgDecimal(fromGrams: perOther + extra)
                    subSheetStates[j].autoCalcPanCount()
                }
            }
        case .subStandardPanWeight(let i):
            guard i < subSheetStates.count else { return }
            subSheetStates[i].standardPanWeightKgText = text
            subSheetStates[i].autoCalcPanCount()
        case .subPanCount(let i):
            guard i < subSheetStates.count else { return }
            subSheetStates[i].panCountText = String(grams) // grams reused as int count
        case .subAutoStandard(let i, let id):
            guard i < subSheetStates.count else { return }
            subSheetStates[i].autoStandardPerPanKgTextById[id] = text
        }
    }
}

private enum WeightWheelTarget: Equatable {
    case afterBoil
    case standardPanWeight
    case fresh(UUID)
    case autoStandard(UUID)
    case subAfterBoil(Int)           // sub-sheet index
    case subStandardPanWeight(Int)   // sub-sheet index
    case subPanCount(Int)            // sub-sheet index
    case subAutoStandard(Int, UUID)  // sub-sheet index, material id
}

private struct FreshRowWheelView: View {
    let name: String
    let stockText: String
    let valueText: String
    let isOver: Bool
    let isAll: Bool
    let onToggleAll: () -> Void
    let onTap: () -> Void
    
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
            Button(action: onToggleAll) {
                Text("all")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(isAll ? .white : Color.themePrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isAll ? Color.themePrimary : Color.gray.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            Button(action: onTap) {
                BlinkingContainer(isActive: isOver) {
                    Text(valueText)
                        .fontWeight(.bold)
                        .foregroundStyle(isOver ? .red : Color.themeTextDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isOver ? Color.red.opacity(0.15) : Color.yellow.opacity(0.18))
                        )
                        .frame(width: 120, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            Text("kg")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}

private struct AutoRowWheelView: View {
    let name: String
    let stockText: String
    let standardText: String
    let perPanActualText: String
    let totalText: String
    let isOver: Bool
    let onTapStandard: () -> Void
    
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
                    Button(action: onTapStandard) {
                        Text(standardText)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
                            .frame(minWidth: 100, alignment: .leading)
                    }
                    .buttonStyle(.plain)
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
                    BlinkingContainer(isActive: isOver) {
                        Text(totalText)
                            .fontWeight(.bold)
                            .foregroundStyle(isOver ? .red : Color.themePrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isOver ? Color.red.opacity(0.15) : Color.yellow.opacity(0.18))
                            )
                    }
                }
            }
        }
    }
}

private struct BlinkingContainer<Content: View>: View {
    let isActive: Bool
    let content: Content
    
    @State private var blinkOn: Bool = false
    
    init(isActive: Bool, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(isActive && blinkOn ? 0.35 : 1)
            .animation(isActive ? nil : .none, value: blinkOn)
            .onAppear {
                guard isActive else { return }
                blinkOn = false
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    blinkOn = true
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    blinkOn = false
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        blinkOn = true
                    }
                } else {
                    // Dừng animation ngay lập tức, không transition
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { blinkOn = false }
                }
            }
    }
}

private struct TemplateManagerSheet: View {
    let templates: [AutoMaterialExportTemplate]
    let selectedTemplateId: UUID?
    @Binding var newName: String
    let onSelect: (AutoMaterialExportTemplate) -> Void
    let onCreateAndSave: (String, [String]) -> Void
    let onDelete: (UUID) -> Void
    let onDeleteSubSheet: (UUID, Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var subSheetEnabled: Bool = false
    @State private var subSheetNames: [String] = ["", ""]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Chọn sheet có sẵn") {
                    ForEach(filteredTemplates, id: \.id) { t in
                        // Sheet chính
                        Button {
                            onSelect(t)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(Color.themePrimary)
                                Text(t.name)
                                    .fontWeight(.medium)
                                Spacer()
                                if t.id == selectedTemplateId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                        }
                        
                        // Sub-sheets của template này
                        if !t.data.subSheets.isEmpty {
                            ForEach(t.data.subSheets.indices, id: \.self) { i in
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                    Text(t.data.subSheets[i])
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        onDeleteSubSheet(t.id, i)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red.opacity(0.7))
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                    .onDelete { indices in
                        let ids = indices.map { filteredTemplates[$0].id }
                        for id in ids {
                            localDeletedIds.insert(id)
                            onDelete(id)
                        }
                    }
                }
                
                Section("Tạo sheet mới") {
                    TextField("Tên sheet mới", text: $newName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    // Sub-sheet toggle
                    Toggle(isOn: $subSheetEnabled) {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.split.3x1")
                                .foregroundStyle(Color.themePrimary)
                            Text("Sub-sheet")
                                .fontWeight(.medium)
                        }
                    }
                    .tint(Color.themePrimary)
                    
                    if subSheetEnabled {
                        ForEach(subSheetNames.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                TextField("Tên sub-sheet \(i + 1)", text: $subSheetNames[i])
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                if subSheetNames.count > 1 {
                                    Button {
                                        subSheetNames.remove(at: i)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Button {
                            subSheetNames.append("")
                        } label: {
                            Label("New row", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.themePrimary)
                                .font(.subheadline)
                        }
                    }
                    
                    Button("Tạo & lưu") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let subs = subSheetEnabled
                                ? subSheetNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                : []
                            onCreateAndSave(trimmed, subs)
                            dismiss()
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Sheet xuất tự động")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
    
    @State private var localDeletedIds: Set<UUID> = []
    
    private var filteredTemplates: [AutoMaterialExportTemplate] {
        let t = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = templates.filter { !localDeletedIds.contains($0.id) }
        if t.isEmpty { return base }
        return base.filter { $0.name.lowercased().contains(t.lowercased()) }
    }
}

private struct WeightWheelSheet: View {
    @Binding var kgRangeBase: Int
    @Binding var kgMax: Int
    @Binding var kgSelection: Int
    @Binding var gramsSelection: Int
    let onSave: () -> Void
    let onClose: () -> Void
    
    @State private var showRangePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showRangePicker = true
                } label: {
                    Text(kgRangeBase <= 0 ? ">0" : ">\(kgRangeBase)")
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Text("Chỉnh khối lượng").font(.headline)
            HStack {
                VStack {
                    Text("Kg")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Picker("", selection: $kgSelection) {
                        ForEach(Array(kgRangeBase...kgMax), id: \.self) { kg in
                            Text("\(kg)").tag(kg)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: kgSelection) { newValue in
                        if newValue >= max(0, kgMax - 10) { kgMax += 200 }
                    }
                }
                VStack {
                    Text("Gam")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Picker("", selection: $gramsSelection) {
                        ForEach(Array(stride(from: 0, through: 990, by: 10)), id: \.self) { g in
                            Text("\(g)").tag(g)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            HStack {
                Button("Đóng") { onClose() }
                Spacer()
                Button("Lưu") { onSave() }
            }
            .font(.headline)
        }
        .padding()
        .confirmationDialog("Chọn vùng giá trị", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(Array(stride(from: 0, through: kgMax, by: 100)), id: \.self) { v in
                Button(v == 0 ? ">0" : ">\(v)") {
                    kgRangeBase = v
                    if kgSelection < v { kgSelection = v }
                    showRangePicker = false
                }
            }
        }
    }
}

private struct IntWheelSheet: View {
    let title: String
    @Binding var rangeBase: Int
    @Binding var maxValue: Int
    @Binding var selection: Int
    let onSave: () -> Void
    let onClose: () -> Void
    
    @State private var showRangePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showRangePicker = true
                } label: {
                    Text(rangeBase <= 0 ? ">0" : ">\(rangeBase)")
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Text(title).font(.headline)
            Picker("", selection: $selection) {
                let minValue = Swift.max(1, rangeBase)
                ForEach(Array(minValue...maxValue), id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: selection) { newValue in
                if newValue >= maxValue - 10 { maxValue += 200 }
            }
            HStack {
                Button("Đóng") { onClose() }
                Spacer()
                Button("Lưu") { onSave() }
            }
            .font(.headline)
        }
        .padding()
        .confirmationDialog("Chọn vùng giá trị", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(Array(stride(from: 0, through: maxValue, by: 100)), id: \.self) { v in
                Button(v == 0 ? ">0" : ">\(v)") {
                    rangeBase = v
                    let minValue = Swift.max(1, rangeBase)
                    if selection < minValue { selection = minValue }
                    showRangePicker = false
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

// MARK: - Export Slip Share Sheet

/// Dữ liệu một sub-sheet để hiển thị trên phiếu in
private struct SubSheetSlipData: Identifiable {
    let id = UUID()
    let name: String
    let afterBoilGrams: Int
    let panCount: Int
    let standardPanWeightGrams: Int
    let actualPanWeightGrams: Double
    let autoRows: [AutoMaterialExportLogRow]
    let extraPanRows: [AutoMaterialExportLogRow]
}

private struct ExportSlipShareSheet: View {
    let templateName: String
    let creatorName: String
    let date: Date
    let freshTitle: String
    let freshRows: [AutoMaterialExportLogRow]
    let afterBoilTitle: String
    let afterBoilGrams: Int
    let panCountTitle: String
    let panCount: Int
    let panWeightTitle: String
    let standardPanWeightGrams: Int
    let actualPanWeightGrams: Double
    let autoMaterialsTitle: String
    let autoRows: [AutoMaterialExportLogRow]
    var extraPanRows: [AutoMaterialExportLogRow] = []
    var subSheetSlips: [SubSheetSlipData] = []   // Dữ liệu sub-sheets để in
    var sequenceNumber: String? = nil
    var onConfirmAfterShare: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var shareImage: UIImage? = nil
    @State private var didConfirm = false

    private var freshTotalGrams: Int {
        freshRows.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    slipContent
                        .padding()

                    // Button "In và kết thúc bill" ở cuối
                    Button {
                        Task { await shareSlip() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSharing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up").font(.title3)
                            }
                            Text(isSharing ? "Đang xử lý..." : "In và kết thúc bill")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(
                            colors: [Color.themePrimary, Color.themePrimary.opacity(0.85)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.themePrimary.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSharing)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Phiếu xuất nguyên liệu")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear {
            guard !didConfirm else { return }
            didConfirm = true
            onConfirmAfterShare?()
        }
    }

    private var totalExportSummary: [(name: String, grams: Int)] {
        var map: [String: Int] = [:]
        for r in freshRows { map[r.name, default: 0] += Int(max(0, r.totalExportGrams.rounded())) }
        if subSheetSlips.isEmpty {
            for r in autoRows { map[r.name, default: 0] += Int(max(0, r.totalExportGrams.rounded())) }
            for r in extraPanRows { map[r.name, default: 0] += Int(max(0, r.totalExportGrams.rounded())) }
        } else {
            for slip in subSheetSlips {
                for r in slip.autoRows { map[r.name, default: 0] += Int(max(0, r.totalExportGrams.rounded())) }
                for r in slip.extraPanRows { map[r.name, default: 0] += Int(max(0, r.totalExportGrams.rounded())) }
            }
        }
        return map.keys.sorted().map { ($0, map[$0] ?? 0) }
    }

    // The printable slip content
    private var slipContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(templateName)
                    .font(.title2)
                    .fontWeight(.bold)
                if let stt = sequenceNumber {
                    Text("STT: \(stt)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                HStack(spacing: 8) {
                    if !creatorName.isEmpty {
                        Label(creatorName, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    Label(formatDateTime(date), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }

            Divider()

            // Fresh materials
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(freshTitle)
                        .font(.headline)
                    Spacer()
                    Text("Tổng: \(FormatUtils.formatWeight(freshTotalGrams))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                ForEach(freshRows) { row in
                    HStack {
                        Text(row.name)
                            .font(.subheadline)
                        Spacer()
                        Text(FormatUtils.formatWeight(Int(max(0, row.totalExportGrams.rounded()))))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.06)))

            // Auto materials hoặc sub-sheets
            if subSheetSlips.isEmpty {
                // Không có sub-sheet: hiển thị như cũ
                if !autoRows.isEmpty {
                    autoRowsBlock(title: autoMaterialsTitle, rows: autoRows, extraRows: extraPanRows, tint: Color.gray.opacity(0.06))
                }
            } else {
                // Có sub-sheet: mỗi sub-sheet một block riêng
                ForEach(subSheetSlips) { slip in
                    VStack(alignment: .leading, spacing: 8) {
                        // Sub-sheet header
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.split.3x1")
                                .font(.caption)
                                .foregroundStyle(Color.themePrimary)
                            Text(slip.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        HStack(spacing: 16) {
                            Label("\(FormatUtils.formatKgDecimal(fromGrams: slip.afterBoilGrams)) kg", systemImage: "scalemass")
                                .font(.caption).foregroundStyle(.gray)
                            Label("\(slip.panCount) chảo", systemImage: "flame")
                                .font(.caption).foregroundStyle(.gray)
                            Label("\(FormatUtils.formatKgDecimal(fromGrams: Int(slip.actualPanWeightGrams.rounded()))) kg/chảo", systemImage: "chart.bar")
                                .font(.caption).foregroundStyle(.gray)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.themePrimary.opacity(0.07)))

                    if !slip.autoRows.isEmpty {
                        autoRowsBlock(title: autoMaterialsTitle, rows: slip.autoRows, extraRows: slip.extraPanRows, tint: Color.gray.opacity(0.06))
                    }
                }
            }

            // Tổng khối lượng cần xuất
            if !totalExportSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tổng khối lượng cần xuất")
                        .font(.headline)
                    Divider()
                    ForEach(totalExportSummary, id: \.name) { row in
                        HStack {
                            Text(row.name)
                                .font(.subheadline)
                            Spacer()
                            Text(FormatUtils.formatWeight(row.grams))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.themePrimary.opacity(0.06)))
            }

            // Footer info
            VStack(alignment: .leading, spacing: 6) {
                slipInfoRow(label: afterBoilTitle, value: FormatUtils.formatWeight(afterBoilGrams))
                if subSheetSlips.isEmpty {
                    if actualPanWeightGrams > 0 {
                        slipInfoRow(label: "Khối lượng chảo xào", value: FormatUtils.formatWeight(Int(actualPanWeightGrams.rounded())))
                    }
                    let extraTotal = extraPanRows.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
                    if extraTotal > 0 {
                        slipInfoRow(label: "Khối lượng xào thêm", value: FormatUtils.formatWeight(extraTotal))
                    }
                } else {
                    let extraTotal = subSheetSlips.reduce(0) { sum, slip in
                        sum + slip.extraPanRows.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
                    }
                    if extraTotal > 0 {
                        slipInfoRow(label: "Khối lượng xào thêm", value: FormatUtils.formatWeight(extraTotal))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.06)))

            // Chữ ký
            Divider()
            HStack(alignment: .top) {
                VStack(spacing: 4) {
                    Text("Người thực hiện")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.gray)
                    Text(creatorName.isEmpty ? " " : creatorName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Người xác nhận")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.gray)
                    Text(" ")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func autoRowsBlock(title: String, rows: [AutoMaterialExportLogRow], extraRows: [AutoMaterialExportLogRow], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            HStack {
                Text("Nguyên liệu").font(.caption).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)
                Text("/Chảo (TT)").font(.caption).foregroundStyle(.gray).frame(width: 90, alignment: .trailing)
                Text("Tổng xuất").font(.caption).foregroundStyle(.gray).frame(width: 80, alignment: .trailing)
            }
            .padding(.bottom, 2)
            Divider()
            ForEach(rows) { row in
                HStack {
                    Text(row.name).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    Text(FormatUtils.formatKgDecimal(fromGrams: Int((row.actualPerPanGrams ?? 0).rounded())))
                        .font(.subheadline).fontWeight(.semibold).frame(width: 90, alignment: .trailing)
                    Text(FormatUtils.formatWeight(Int(max(0, row.totalExportGrams.rounded()))))
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
            if !extraRows.isEmpty {
                Divider().padding(.top, 4)
                Text("Xào thêm").font(.caption).fontWeight(.semibold).foregroundStyle(Color.orange)
                ForEach(extraRows) { row in
                    HStack {
                        Text(row.name).font(.subheadline).foregroundStyle(Color.orange).frame(maxWidth: .infinity, alignment: .leading)
                        Text("—").font(.subheadline).frame(width: 90, alignment: .trailing)
                        Text(FormatUtils.formatWeight(Int(max(0, row.totalExportGrams.rounded()))))
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.orange)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint))
    }

    private func slipInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    @MainActor
    private func shareSlip() async {
        isSharing = true
        defer { isSharing = false }

        let renderer = ImageRenderer(content:
            slipContent
                .padding(20)
                .background(Color.white)
                .frame(width: 390)
        )
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        av.completionWithItemsHandler = { [self] _, _, _, _ in
            DispatchQueue.main.async {
                self.didConfirm = true
                self.dismiss()
                self.onConfirmAfterShare?()
            }
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            av.popoverPresentationController?.sourceView = top.view
            top.present(av, animated: true)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }
}
