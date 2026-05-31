import SwiftUI
import UIKit

struct ProductionTransactionItemEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    let modeTitle: String
    let isFinishedGoods: Bool
    let initialItem: RestockItem
    let onSave: (RestockItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var quantityText: String
    @State private var selectedUnit: String
    @State private var priceText: String
    @State private var costText: String
    @State private var selectedCategoryName: String
    
    @State private var showCategorySheet = false
    @State private var newCategoryName: String = ""
    
    @State private var sourceText: String
    @State private var showSourceHistoryPicker = false
    @State private var sourceHistoryOptions: [String] = []
    
    @State private var showDocumentPicker = false
    @State private var showCameraPicker = false
    @State private var showCameraUnavailableAlert = false
    @State private var documentPickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var documentImage: UIImage?
    @State private var documentImageURL: String?
    @State private var isUploadingDocument: Bool = false
    @State private var showDocumentPreview: Bool = false
    
    @State private var showQuantityWheel = false
    @State private var quantityWheelMax = 500
    @State private var quantityWheelSelection = 1
    @State private var quantityKgSelection = 0
    @State private var gramsWheelSelection = 0
    @State private var gramsWheelMax = 990
    @State private var quantityKgRangeBase = 0
    @State private var gramsWheelRangeBase = 0
    @State private var showQuantityKgRangePicker = false
    @State private var showGramsRangePicker = false
    
    @State private var showUnitPriceWheel = false
    @State private var unitPriceWheelSelection = 0
    @State private var unitPriceMillionsSelection = 0
    @State private var unitPriceMillionsRangeBase = 0
    @State private var showUnitPriceMillionsRangePicker = false
    @State private var unitPriceThousandsSelection = 0
    @State private var unitPriceThousandsRangeBase = 0
    @State private var showUnitPriceThousandsRangePicker = false
    @State private var unitPriceHundredsSelection = 0
    @State private var unitPriceHundredsRangeBase = 0
    @State private var showUnitPriceHundredsRangePicker = false

    @State private var showAdditionalCostWheel = false
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostMillionsSelection = 0
    @State private var additionalCostMillionsRangeBase = 0
    @State private var showAdditionalCostMillionsRangePicker = false
    @State private var additionalCostThousandsSelection = 0
    @State private var additionalCostThousandsRangeBase = 0
    @State private var showAdditionalCostThousandsRangePicker = false
    @State private var additionalCostHundredsSelection = 0
    @State private var additionalCostHundredsRangeBase = 0
    @State private var showAdditionalCostHundredsRangePicker = false

    // MARK: - Computed Properties to fix type checking issues
    private var unitPriceMillionsRange: [Int] {
        let millionsMin = unitPriceMillionsRangeBase
        let upperBound = max(millionsMin, millionsMin + 500)
        return Array(millionsMin...upperBound)
    }
    
    private var unitPriceThousandsRange: [Int] {
        let thousandsMin = unitPriceThousandsRangeBase
        let upperBound = min(thousandsMin + 99, 999)
        return Array(thousandsMin...upperBound)
    }
    
    private var unitPriceHundredsRange: [Int] {
        let hundredsMin = unitPriceHundredsRangeBase
        let upperBound = min(hundredsMin + 90, 990)
        return Array(stride(from: hundredsMin, through: upperBound, by: 10))
    }
    
    private var additionalCostMillionsRange: [Int] {
        let millionsMin = additionalCostMillionsRangeBase
        let upperBound = max(millionsMin, millionsMin + 500)
        return Array(millionsMin...upperBound)
    }
    
    private var additionalCostThousandsRange: [Int] {
        let thousandsMin = additionalCostThousandsRangeBase
        let upperBound = min(thousandsMin + 99, 999)
        return Array(thousandsMin...upperBound)
    }
    
    private var additionalCostHundredsRange: [Int] {
        let hundredsMin = additionalCostHundredsRangeBase
        let upperBound = min(hundredsMin + 90, 990)
        return Array(stride(from: hundredsMin, through: upperBound, by: 10))
    }
    
    private var quantityKgRange: [Int] {
        let kgMin = quantityKgRangeBase
        let upperBound = max(kgMin, kgMin + 500)
        return Array(kgMin...upperBound)
    }
    
    private var gramsRange: [Int] {
        let gramsMin = gramsWheelRangeBase
        let upperBound = gramsWheelMax
        return Array(stride(from: gramsMin, through: upperBound, by: 100))
    }
    
    private var quantityKgPickerRange: [Int] {
        Array(quantityKgRangeBase...quantityWheelMax)
    }
    
    private var gramsPickerRange: [Int] {
        Array(stride(from: gramsWheelRangeBase, through: gramsWheelMax, by: 10))
    }
    
    private var quantityPickerRange: [Int] {
        Array(1...quantityWheelMax)
    }
    
    init(viewModel: OrderViewModel, modeTitle: String, isFinishedGoods: Bool, initialItem: RestockItem, onSave: @escaping (RestockItem) -> Void) {
        self.viewModel = viewModel
        self.modeTitle = modeTitle
        self.isFinishedGoods = isFinishedGoods
        self.initialItem = initialItem
        self.onSave = onSave
        
        _name = State(initialValue: initialItem.name)
        let modeLower = modeTitle.lowercased()
        let categoryLower = initialItem.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let materialsLower = Category.materials.rawValue.lowercased()
        let useKgGram = modeLower.contains("nguyên liệu") || modeLower.contains("material") || modeLower.contains("thành phẩm") || modeLower.contains("finished") || categoryLower == materialsLower
        let storedUnit = initialItem.unit ?? (useKgGram ? "kg" : "cái")
        let initialUnit = storedUnit
        _selectedUnit = State(initialValue: initialUnit)
        if useKgGram && initialUnit.lowercased() == "kg" {
            _quantityText = State(initialValue: FormatUtils.formatKgDecimal(fromGrams: initialItem.quantity))
        } else if useKgGram && initialUnit.lowercased() == "cái" && initialItem.quantity >= 1000 {
            _quantityText = State(initialValue: String(initialItem.quantity / 1000))
        } else {
            _quantityText = State(initialValue: String(initialItem.quantity))
        }
        _priceText = State(initialValue: String(Int(initialItem.unitPrice)))
        _costText = State(initialValue: String(Int(initialItem.additionalCost)))
        _selectedCategoryName = State(initialValue: (initialItem.category?.isEmpty == false ? initialItem.category! : (modeTitle.lowercased().contains("nguyên liệu") ? Category.materials.rawValue : Category.others.rawValue)))
        _sourceText = State(initialValue: initialItem.source ?? "")
        _documentImageURL = State(initialValue: initialItem.documentImageURL)
    }
    
    private var useKgGram: Bool {
        let t = modeTitle.lowercased()
        let categoryLower = selectedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.contains("nguyên liệu") || t.contains("material") || t.contains("thành phẩm") || t.contains("finished") || categoryLower == Category.materials.rawValue.lowercased()
    }
    
    private var unitPriceTitle: String {
        let t = modeTitle.lowercased()
        return t.contains("xuất") ? "Đơn giá xuất" : "Đơn giá nhập"
    }
    
    private var isMaterialsCtx: Bool {
        let t = modeTitle.lowercased()
        return t.contains("nguyên liệu") || t.contains("material") || selectedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Category.materials.rawValue.lowercased()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(isFinishedGoods ? "Chi tiết thành phẩm" : "Chi tiết nguyên liệu")) {
                    HStack(spacing: 8) {
                        TextField(isFinishedGoods ? "Tên thành phẩm" : "Tên nguyên liệu", text: $name)
                        Button {
                            if viewModel.isRecordingManualProductName {
                                viewModel.speechRecognizer.stopRecording()
                                let spoken = viewModel.manualRecordedName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !spoken.isEmpty { name = spoken }
                            } else {
                                do {
                                    try viewModel.speechRecognizer.startRecording()
                                    viewModel.isRecordingManualProductName = true
                                    viewModel.manualRecordedName = ""
                                } catch { }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill((viewModel.isRecordingManualProductName ? Color.red : Color.gray).opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: viewModel.isRecordingManualProductName ? "waveform" : "mic.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(viewModel.isRecordingManualProductName ? Color.red : .gray)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onReceive(viewModel.$manualRecordedName) { newText in
                        if viewModel.isRecordingManualProductName {
                            let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { name = t }
                        }
                    }
                    .onChange(of: name) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { return }
                        if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let latest = viewModel.latestSource(for: trimmed) {
                                sourceText = latest
                            }
                        }
                    }
                    
                    HStack {
                        Text("Số lượng")
                        Spacer()
                        Button {
                            if useKgGram {
                                let current = FormatUtils.parseKgDecimalToGrams(quantityText) ?? quantityWheelSelection
                                quantityKgSelection = max(0, current / 1000)
                                let remainder = max(0, current % 1000)
                                gramsWheelSelection = (remainder / 50) * 50
                                if quantityKgSelection > quantityWheelMax {
                                    quantityWheelMax = max(quantityWheelMax, quantityKgSelection + 200)
                                }
                            } else {
                                if let q = Int(quantityText), q > 0 { quantityWheelSelection = q }
                            }
                            showQuantityWheel = true
                        } label: {
                            let gramsVal = FormatUtils.parseKgDecimalToGrams(quantityText) ?? quantityWheelSelection
                            if useKgGram {
                                if selectedUnit.lowercased() == "cái" {
                                    Text("\(quantityText.isEmpty ? String(quantityWheelSelection) : quantityText) cái")
                                        .fontWeight(.semibold)
                                } else {
                                    Text(FormatUtils.formatWeight(gramsVal, unit: selectedUnit))
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Text(quantityText.isEmpty ? String(quantityWheelSelection) : quantityText)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    HStack {
                        Text(unitPriceTitle)
                        Spacer()
                        Button {
                            if let p = parseInt(priceText) { unitPriceWheelSelection = p }
                            showUnitPriceWheel = true
                        } label: {
                            Text(formatCurrency(Double(parseInt(priceText) ?? unitPriceWheelSelection)))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Chi phí phát sinh")
                        Spacer()
                        Button {
                            if let v = parseInt(costText) { additionalCostWheelSelection = v }
                            showAdditionalCostWheel = true
                        } label: {
                            Text(formatCurrency(Double(parseInt(costText) ?? additionalCostWheelSelection)))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Danh mục")
                        Spacer()
                        Button { showCategorySheet = true } label: {
                            Text(selectedCategoryName)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text("Nguồn nhập")
                        Spacer()
                        TextField("Nhập nguồn", text: $sourceText)
                            .multilineTextAlignment(.trailing)
                        Button {
                            if viewModel.isRecordingManualSource {
                                viewModel.speechRecognizer.stopRecording()
                                let spoken = viewModel.manualRecordedSource.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !spoken.isEmpty { sourceText = spoken }
                            } else {
                                do {
                                    try viewModel.speechRecognizer.startRecording()
                                    viewModel.isRecordingManualSource = true
                                    viewModel.manualRecordedSource = ""
                                } catch { }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill((viewModel.isRecordingManualSource ? Color.red : Color.gray).opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: viewModel.isRecordingManualSource ? "waveform" : "mic.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(viewModel.isRecordingManualSource ? Color.red : .gray)
                            }
                        }
                        .buttonStyle(.plain)
                        Button {
                            let options = viewModel.sourceHistory(for: name)
                            if !options.isEmpty {
                                sourceHistoryOptions = options
                                showSourceHistoryPicker = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.sourceHistory(for: name).isEmpty)
                    }
                    .onReceive(viewModel.$manualRecordedSource) { newText in
                        if viewModel.isRecordingManualSource {
                            let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { sourceText = t }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hóa đơn chứng từ")
                            Spacer()
                            if isUploadingDocument {
                                ProgressView()
                            } else if documentImageURL != nil {
                                Text("Đã chọn")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            } else {
                                Text("—")
                                    .foregroundStyle(.gray)
                            }
                        }
                        HStack(spacing: 12) {
                            if documentImage != nil || documentImageURL != nil {
                                Button { showDocumentPreview = true } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.12))
                                            .frame(width: 54, height: 54)
                                        if let img = documentImage {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 54, height: 54)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else if let urlString = documentImageURL, let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                default:
                                                    Image(systemName: "doc.text.image").foregroundStyle(.gray)
                                                }
                                            }
                                            .frame(width: 54, height: 54)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button("Chụp ảnh") {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    documentPickerSource = .camera
                                    showCameraPicker = true
                                } else {
                                    showCameraUnavailableAlert = true
                                }
                            }
                            
                            Button("Thư viện") {
                                documentPickerSource = .photoLibrary
                                showDocumentPicker = true
                            }
                            
                            if documentImageURL != nil {
                                Spacer()
                                Button("Xóa") {
                                    documentImage = nil
                                    documentImageURL = nil
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sửa mặt hàng")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                normalizeLegacyMaterialQuantityIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let q: Int
                        if useKgGram && selectedUnit.lowercased() == "kg" {
                            q = FormatUtils.parseKgDecimalToGrams(quantityText) ?? quantityWheelSelection
                        } else if useKgGram && selectedUnit.lowercased() == "cái" && initialItem.quantity >= 1000 {
                            q = (Int(quantityText) ?? quantityWheelSelection) * 1000
                        } else {
                            q = Int(quantityText) ?? quantityWheelSelection
                        }

                        let p = Double(parseInt(priceText) ?? unitPriceWheelSelection)
                        let extra = Double(parseInt(costText) ?? additionalCostWheelSelection)
                        let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

                        var item = initialItem
                        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.quantity = q
                        item.unitPrice = p
                        item.additionalCost = extra
                        item.category = selectedCategoryName
                        item.source = src.isEmpty ? nil : src
                        item.documentImageURL = documentImageURL
                        item.unit = useKgGram ? selectedUnit : nil
                        item.isConfirmed = true

                        onSave(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .confirmationDialog("Chọn nguồn nhập", isPresented: $showSourceHistoryPicker, titleVisibility: .visible) {
            ForEach(sourceHistoryOptions, id: \.self) { src in
                Button(src) { sourceText = src }
            }
        }
        .sheet(isPresented: $showDocumentPicker, onDismiss: { uploadSelectedDocumentImage() }) {
            ImagePicker(image: $documentImage, sourceType: documentPickerSource)
        }
        .fullScreenCover(isPresented: $showCameraPicker, onDismiss: { uploadSelectedDocumentImage() }) {
            ImagePicker(image: $documentImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .alert("Không thể mở camera", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thiết bị không hỗ trợ camera hoặc ứng dụng chưa được cấp quyền.")
        }
        .sheet(isPresented: $showDocumentPreview) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let img = documentImage {
                        ZoomableMediaView {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    } else if let urlString = documentImageURL, let url = URL(string: urlString) {
                        ZoomableMediaView {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().tint(.white)
                                case .success(let image):
                                    image.resizable().scaledToFit().padding()
                                default:
                                    Text("Không tải được ảnh").foregroundStyle(.white)
                                }
                            }
                        }
                    } else {
                        Text("Không có chứng từ").foregroundStyle(.white)
                    }
                }
                .navigationTitle("Chứng từ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { showDocumentPreview = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showCategorySheet) {
            NavigationStack {
                Form {
                    Section("Chọn danh mục") {
                        let baseCats = Category.allCases.filter { $0 != .all }.map { $0.rawValue }
                        let dynamicCats = isMaterialsCtx ? Array(viewModel.materialCategories) : Array(viewModel.productCategories)
                        let allCats = Array(Set(baseCats + dynamicCats)).sorted()
                        ForEach(allCats, id: \.self) { cat in
                            Button {
                                selectedCategoryName = cat
                                showCategorySheet = false
                            } label: {
                                HStack {
                                    Text(cat)
                                    if selectedCategoryName == cat {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Section("Tạo danh mục mới") {
                        TextField("Tên danh mục", text: $newCategoryName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                        Button("Lưu danh mục") {
                            let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                selectedCategoryName = trimmed
                                if isMaterialsCtx { viewModel.addMaterialCategory(trimmed) }
                                else { viewModel.addProductCategory(trimmed) }
                                newCategoryName = ""
                                showCategorySheet = false
                            }
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationTitle(isMaterialsCtx ? "Danh mục nguyên liệu" : "Danh mục hàng hóa")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { showCategorySheet = false }
                    }
                }
            }
            .presentationDetents([.height(420)])
        }
        .sheet(isPresented: $showQuantityWheel) {
            VStack(spacing: 12) {
                Text("Sửa số lượng").font(.headline)
                
                if useKgGram {
                    Picker("Đơn vị", selection: $selectedUnit) {
                        Text("Kg").tag("kg")
                        Text("Cái").tag("cái")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if useKgGram && selectedUnit.lowercased() == "kg" {
                    HStack {
                        Button {
                            showQuantityKgRangePicker = true
                        } label: {
                            Text(quantityKgRangeBase <= 0 ? ">0" : ">\(quantityKgRangeBase)")
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            showGramsRangePicker = true
                        } label: {
                            Text(gramsWheelRangeBase <= 0 ? ">0" : ">\(gramsWheelRangeBase)")
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        VStack {
                            Text("Kg").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $quantityKgSelection) {
                                ForEach(quantityKgPickerRange, id: \.self) { kg in
                                    Text("\(kg)").tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: quantityKgSelection) { newValue in
                                if newValue >= max(0, quantityWheelMax - 10) {
                                    quantityWheelMax += 200
                                }
                            }
                        }
                        VStack {
                            Text("Gam").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $gramsWheelSelection) {
                                ForEach(gramsPickerRange, id: \.self) { g in
                                    Text("\(g)").tag(g)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                } else {
                    Picker("", selection: $quantityWheelSelection) {
                        ForEach(quantityPickerRange, id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: quantityWheelSelection) { newValue in
                        if newValue >= quantityWheelMax - 10 {
                            quantityWheelMax += 200
                        }
                    }
                }
                HStack {
                    Button("Đóng") { showQuantityWheel = false }
                    Spacer()
                    Button("Lưu") {
                        if useKgGram && selectedUnit.lowercased() == "kg" {
                            let total = quantityKgSelection * 1000 + gramsWheelSelection
                            quantityWheelSelection = total
                            quantityText = FormatUtils.formatKgDecimal(fromGrams: total)
                        } else {
                            quantityText = String(quantityWheelSelection)
                        }
                        showQuantityWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(useKgGram ? 380 : 340)])
        }
        .sheet(isPresented: $showQuantityKgRangePicker) {
            VStack(spacing: 12) {
                Text("Chọn vùng giá trị Kg").font(.headline)
                Picker("", selection: $quantityKgRangeBase) {
                    ForEach(Array(stride(from: 0, through: quantityWheelMax, by: 100)), id: \.self) { v in
                        Text(v == 0 ? ">0" : ">\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: quantityKgRangeBase) { newValue in
                    if quantityKgSelection < newValue { quantityKgSelection = newValue }
                }
                HStack {
                    Button("Đóng") { showQuantityKgRangePicker = false }
                    Spacer()
                    Button("Xong") { showQuantityKgRangePicker = false }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showGramsRangePicker) {
            VStack(spacing: 12) {
                Text("Chọn vùng giá trị Gam").font(.headline)
                Picker("", selection: $gramsWheelRangeBase) {
                    ForEach(Array(stride(from: 0, through: gramsWheelMax, by: 100)), id: \.self) { v in
                        Text(v == 0 ? ">0" : ">\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: gramsWheelRangeBase) { newValue in
                    if gramsWheelSelection < newValue { gramsWheelSelection = newValue }
                }
                HStack {
                    Button("Đóng") { showGramsRangePicker = false }
                    Spacer()
                    Button("Xong") { showGramsRangePicker = false }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showUnitPriceWheel) {
            VStack(spacing: 12) {
                Text("Sửa đơn giá").font(.headline)
                Text(formatCurrency(Double(unitPriceWheelSelection)))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                HStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Button { showUnitPriceMillionsRangePicker = true } label: {
                            Text(unitPriceMillionsRangeBase <= 0 ? ">0" : ">\(unitPriceMillionsRangeBase)tr")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Triệu").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $unitPriceMillionsSelection) {
                            ForEach(unitPriceMillionsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: unitPriceMillionsSelection) { v in
                            unitPriceWheelSelection = v * 1_000_000 + unitPriceThousandsSelection * 1_000 + unitPriceHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button { showUnitPriceThousandsRangePicker = true } label: {
                            Text(unitPriceThousandsRangeBase <= 0 ? ">0" : ">\(unitPriceThousandsRangeBase)")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Ngàn").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $unitPriceThousandsSelection) {
                            ForEach(unitPriceThousandsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: unitPriceThousandsSelection) { v in
                            unitPriceWheelSelection = unitPriceMillionsSelection * 1_000_000 + v * 1_000 + unitPriceHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button { showUnitPriceHundredsRangePicker = true } label: {
                            Text(unitPriceHundredsRangeBase <= 0 ? ">0" : "\(unitPriceHundredsRangeBase)")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Trăm").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $unitPriceHundredsSelection) {
                            ForEach(unitPriceHundredsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: unitPriceHundredsSelection) { v in
                            unitPriceWheelSelection = unitPriceMillionsSelection * 1_000_000 + unitPriceThousandsSelection * 1_000 + v
                        }
                    }
                }
                HStack {
                    Button("Đóng") { showUnitPriceWheel = false }
                    Spacer()
                    Button("Lưu") {
                        priceText = String(unitPriceWheelSelection)
                        showUnitPriceWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .onAppear {
                let current = max(0, unitPriceWheelSelection)
                unitPriceMillionsSelection = current / 1_000_000
                unitPriceMillionsRangeBase = (unitPriceMillionsSelection / 10) * 10
                let rem1 = current % 1_000_000
                unitPriceThousandsSelection = rem1 / 1_000
                unitPriceThousandsRangeBase = (unitPriceThousandsSelection / 100) * 100
                let rem2 = rem1 % 1_000
                unitPriceHundredsRangeBase = (rem2 / 100) * 100
                unitPriceHundredsSelection = (rem2 / 10) * 10
            }
            .sheet(isPresented: $showUnitPriceMillionsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng triệu").font(.headline)
                    Picker("", selection: $unitPriceMillionsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if unitPriceMillionsSelection < unitPriceMillionsRangeBase { unitPriceMillionsSelection = unitPriceMillionsRangeBase }
                        showUnitPriceMillionsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showUnitPriceThousandsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng ngàn").font(.headline)
                    Picker("", selection: $unitPriceThousandsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : "\(v)-\(v+99)").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if unitPriceThousandsSelection < unitPriceThousandsRangeBase || unitPriceThousandsSelection > unitPriceThousandsRangeBase + 99 { unitPriceThousandsSelection = unitPriceThousandsRangeBase }
                        showUnitPriceThousandsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showUnitPriceHundredsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng trăm").font(.headline)
                    Picker("", selection: $unitPriceHundredsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : "\(v)-\(v+90)").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if unitPriceHundredsSelection < unitPriceHundredsRangeBase || unitPriceHundredsSelection > unitPriceHundredsRangeBase + 90 { unitPriceHundredsSelection = unitPriceHundredsRangeBase }
                        showUnitPriceHundredsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa chi phí").font(.headline)
                Text(formatCurrency(Double(additionalCostWheelSelection)))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                HStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Button { showAdditionalCostMillionsRangePicker = true } label: {
                            Text(additionalCostMillionsRangeBase <= 0 ? ">0" : ">\(additionalCostMillionsRangeBase)tr")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Triệu").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $additionalCostMillionsSelection) {
                            ForEach(additionalCostMillionsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: additionalCostMillionsSelection) { v in
                            additionalCostWheelSelection = v * 1_000_000 + additionalCostThousandsSelection * 1_000 + additionalCostHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button { showAdditionalCostThousandsRangePicker = true } label: {
                            Text(additionalCostThousandsRangeBase <= 0 ? ">0" : ">\(additionalCostThousandsRangeBase)")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Ngàn").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $additionalCostThousandsSelection) {
                            ForEach(additionalCostThousandsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: additionalCostThousandsSelection) { v in
                            additionalCostWheelSelection = additionalCostMillionsSelection * 1_000_000 + v * 1_000 + additionalCostHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button { showAdditionalCostHundredsRangePicker = true } label: {
                            Text(additionalCostHundredsRangeBase <= 0 ? ">0" : "\(additionalCostHundredsRangeBase)")
                                .fontWeight(.bold).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }.buttonStyle(.plain)
                        Text("Trăm").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $additionalCostHundredsSelection) {
                            ForEach(additionalCostHundredsRange, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: additionalCostHundredsSelection) { v in
                            additionalCostWheelSelection = additionalCostMillionsSelection * 1_000_000 + additionalCostThousandsSelection * 1_000 + v
                        }
                    }
                }
                HStack {
                    Button("Đóng") { showAdditionalCostWheel = false }
                    Spacer()
                    Button("Lưu") {
                        costText = String(additionalCostWheelSelection)
                        showAdditionalCostWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .onAppear {
                let current = max(0, additionalCostWheelSelection)
                additionalCostMillionsSelection = current / 1_000_000
                additionalCostMillionsRangeBase = (additionalCostMillionsSelection / 10) * 10
                let rem1 = current % 1_000_000
                additionalCostThousandsSelection = rem1 / 1_000
                additionalCostThousandsRangeBase = (additionalCostThousandsSelection / 100) * 100
                let rem2 = rem1 % 1_000
                additionalCostHundredsRangeBase = (rem2 / 100) * 100
                additionalCostHundredsSelection = (rem2 / 10) * 10
            }
            .sheet(isPresented: $showAdditionalCostMillionsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng triệu").font(.headline)
                    Picker("", selection: $additionalCostMillionsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if additionalCostMillionsSelection < additionalCostMillionsRangeBase { additionalCostMillionsSelection = additionalCostMillionsRangeBase }
                        showAdditionalCostMillionsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showAdditionalCostThousandsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng ngàn").font(.headline)
                    Picker("", selection: $additionalCostThousandsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : "\(v)-\(v+99)").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if additionalCostThousandsSelection < additionalCostThousandsRangeBase || additionalCostThousandsSelection > additionalCostThousandsRangeBase + 99 { additionalCostThousandsSelection = additionalCostThousandsRangeBase }
                        showAdditionalCostThousandsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showAdditionalCostHundredsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng trăm").font(.headline)
                    Picker("", selection: $additionalCostHundredsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : "\(v)-\(v+90)").tag(v)
                        }
                    }.pickerStyle(.wheel)
                    Button {
                        if additionalCostHundredsSelection < additionalCostHundredsRangeBase || additionalCostHundredsSelection > additionalCostHundredsRangeBase + 90 { additionalCostHundredsSelection = additionalCostHundredsRangeBase }
                        showAdditionalCostHundredsRangePicker = false
                    } label: {
                        Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.themePrimary).cornerRadius(10)
                    }
                }.padding().presentationDetents([.height(300)])
            }
        }
        .onAppear {
            let currentQ = useKgGram ? (FormatUtils.parseKgDecimalToGrams(quantityText) ?? 0) : (Int(quantityText) ?? 0)
            quantityWheelSelection = max(1, currentQ)
            if useKgGram {
                quantityKgSelection = max(0, currentQ / 1000)
                let remainder = max(0, currentQ % 1000)
                gramsWheelSelection = (remainder / 10) * 10
                quantityKgRangeBase = (quantityKgSelection / 100) * 100
                gramsWheelRangeBase = (gramsWheelSelection / 100) * 100
            }
            unitPriceWheelSelection = parseInt(priceText) ?? 0
            additionalCostWheelSelection = parseInt(costText) ?? 0
            if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let latest = viewModel.latestSource(for: name) {
                    sourceText = latest
                }
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "0 đ"
    }

    private func uploadSelectedDocumentImage() {
        guard let img = documentImage else { return }
        guard let data = img.jpegData(compressionQuality: 0.85) else { return }
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let fileName = "\(initialItem.id.uuidString)-\(UUID().uuidString)"
        
        Task {
            isUploadingDocument = true
            do {
                let url = try await StorageManager.shared.uploadRestockDocumentImage(data: data, fileName: fileName, storeId: storeId)
                await MainActor.run {
                    documentImageURL = url
                    isUploadingDocument = false
                }
            } catch {
                await MainActor.run {
                    isUploadingDocument = false
                }
            }
        }
    }
    
    private func parseInt(_ input: String) -> Int? {
        let clean = input.replacingOccurrences(of: ",", with: "")
        return Int(clean)
    }
    
    private func normalizeLegacyMaterialQuantityIfNeeded() {
        guard useKgGram else { return }
        guard selectedUnit.lowercased() == "cái" else { return }
        guard initialItem.quantity >= 1000 else { return }
        let pieces = initialItem.quantity / 1000
        quantityText = String(pieces)
        quantityWheelSelection = max(1, pieces)
        if quantityWheelSelection > quantityWheelMax {
            quantityWheelMax = max(quantityWheelMax, quantityWheelSelection + 200)
        }
    }
}

private struct ZoomableMediaView<Content: View>: View {
    let content: Content
    
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            }
            .clipped()
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = lastScale * value
                scale = min(max(next, 1), 6)
            }
            .onEnded { _ in
                lastScale = scale
                if scale == 1 {
                    offset = .zero
                    lastOffset = .zero
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

