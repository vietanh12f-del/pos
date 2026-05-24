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
    @State private var unitPriceWheelMax = 5_000_000
    @State private var unitPriceBaseSelection = 0
    @State private var unitPriceHundredsSelection = 0
    
    @State private var showAdditionalCostWheel = false
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostWheelMax = 1_000_000
    @State private var additionalCostBaseSelection = 0
    @State private var additionalCostHundredsSelection = 0
    
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
                    .onChange(of: name) { _, newValue in
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
                                ForEach(Array(quantityKgRangeBase...quantityWheelMax), id: \.self) { kg in
                                    Text("\(kg)").tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: quantityKgSelection) { _, newValue in
                                if newValue >= max(0, quantityWheelMax - 10) {
                                    quantityWheelMax += 200
                                }
                            }
                        }
                        VStack {
                            Text("Gam").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $gramsWheelSelection) {
                                ForEach(Array(stride(from: gramsWheelRangeBase, through: gramsWheelMax, by: 10)), id: \.self) { g in
                                    Text("\(g)").tag(g)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                } else {
                    Picker("", selection: $quantityWheelSelection) {
                        ForEach(Array(1...quantityWheelMax), id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: quantityWheelSelection) { _, newValue in
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
                .onChange(of: quantityKgRangeBase) { _, newValue in
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
                .onChange(of: gramsWheelRangeBase) { _, newValue in
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
                let step = StoreManager.shared.priceStep
                HStack {
                    VStack {
                        Text("Giá").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $unitPriceBaseSelection) {
                            ForEach(Array(stride(from: 0, through: unitPriceWheelMax, by: step)), id: \.self) { v in
                                Text(formatCurrency(Double(v))).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: unitPriceBaseSelection) { _, newValue in
                            unitPriceWheelSelection = newValue + unitPriceHundredsSelection
                            if newValue > unitPriceWheelMax - (step * 5) {
                                unitPriceWheelMax += step * 100
                            }
                        }
                    }
                    VStack {
                        Text("Trăm").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $unitPriceHundredsSelection) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: unitPriceHundredsSelection) { _, newValue in
                            unitPriceWheelSelection = unitPriceBaseSelection + newValue
                        }
                    }
                    .frame(width: 110)
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
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, unitPriceWheelSelection)
                unitPriceBaseSelection = (current / step) * step
                let remainder = max(0, current - unitPriceBaseSelection)
                unitPriceHundredsSelection = min(900, (remainder / 100) * 100)
            }
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa chi phí").font(.headline)
                let step = StoreManager.shared.priceStep
                HStack {
                    VStack {
                        Text("Giá").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $additionalCostBaseSelection) {
                            ForEach(Array(stride(from: 0, through: additionalCostWheelMax, by: step)), id: \.self) { v in
                                Text(formatCurrency(Double(v))).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: additionalCostBaseSelection) { _, newValue in
                            additionalCostWheelSelection = newValue + additionalCostHundredsSelection
                            if newValue > additionalCostWheelMax - (step * 5) {
                                additionalCostWheelMax += step * 100
                            }
                        }
                    }
                    VStack {
                        Text("Trăm").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $additionalCostHundredsSelection) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: additionalCostHundredsSelection) { _, newValue in
                            additionalCostWheelSelection = additionalCostBaseSelection + newValue
                        }
                    }
                    .frame(width: 110)
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
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, additionalCostWheelSelection)
                additionalCostBaseSelection = (current / step) * step
                let remainder = max(0, current - additionalCostBaseSelection)
                additionalCostHundredsSelection = min(900, (remainder / 100) * 100)
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

