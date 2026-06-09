import SwiftUI

struct MaterialEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(MaterialItem)
    }
    
    let mode: Mode
    let allowEditPriceAndStock: Bool
    
    @State private var name: String = ""
    @State private var importPrice: String = ""
    @State private var stock: String = "0"
    @State private var showCostWheel = false
    @State private var costWheelSelection = 0
    @State private var costWheelHundredsSelection = 0
    @State private var costWheelHundredsRangeBase = 0
    @State private var showCostWheelHundredsRangePicker = false
    @State private var costWheelMillionsSelection = 0
    @State private var costWheelMillionsRangeBase = 0
    @State private var showCostWheelMillionsRangePicker = false
    @State private var costWheelThousandsSelection = 0
    @State private var costWheelThousandsRangeBase = 0
    @State private var showCostWheelThousandsRangePicker = false
    @State private var showStockWheel = false
    @State private var stockWheelSelection = 0
    @State private var stockWheelMax = 1000
    @State private var stockKgSelection = 0
    @State private var stockGramsSelection = 0
    @State private var stockGramsMax = 990
    @State private var stockKgRangeBase = 0
    @State private var showStockKgRangePicker = false
    @State private var selectedCategoryName: String = Category.materials.rawValue
    @State private var selectedUnit: String = "kg"
    @State private var barcode: String = ""
    @State private var showBarcodeScanner = false
    @State private var showPrintBarcode = false
    @State private var hasVAT: Bool = false
    @State private var minStockAlertThreshold: Int? = nil
    @State private var showSetThresholdSheet = false
    
    // MARK: - Summary Section State
    @State private var summaryStartDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var summaryEndDate: Date = Date()
    @State private var showSummaryDatePicker: Bool = false
    @State private var isEditingSummaryStart: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Hủy") { dismiss() }
                Spacer()
                Text(title).font(.headline)
                Spacer()
                Button("Lưu") {
                    save()
                }
                .disabled(name.isEmpty)
                .foregroundStyle(name.isEmpty ? Color.gray : Color.themePrimary)
            }
            .padding()
            .background(Color.white)
            
            Form {
                Section(header: Text("Chi tiết nguyên liệu")) {
                    TextField("Tên nguyên liệu", text: $name)
                    
                    Picker("Danh mục", selection: $selectedCategoryName) {
                        let baseCats = Category.allCases.filter { $0 != .all }.map { $0.rawValue }
                        let dynamicCats = Array(viewModel.materialCategories)
                        let allCats = Array(Set(baseCats + dynamicCats)).sorted()
                        ForEach(allCats, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    
                    HStack {
                        Text("Giá nhập")
                        Spacer()
                        if allowEditPriceAndStock {
                            Button {
                                if let v = Double(importPrice) { costWheelSelection = Int(v) }
                                showCostWheel = true
                            } label: {
                                Text(formatCurrency(Double(costWheelSelection > 0 ? costWheelSelection : (Int(Double(importPrice) ?? 0)))))
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Text(formatCurrency(Double(costWheelSelection > 0 ? costWheelSelection : (Int(Double(importPrice) ?? 0)))))
                                .fontWeight(.semibold)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    HStack {
                        Text("Tồn kho")
                        Spacer()
                        Text(FormatUtils.formatWeight(stockWheelSelection > 0 ? stockWheelSelection : (Int(stock) ?? 0), unit: selectedUnit))
                            .fontWeight(.semibold)
                            .foregroundStyle(.gray)
                        Button {
                            showSetThresholdSheet = true
                        } label: {
                            Image(systemName: minStockAlertThreshold != nil ? "bell.fill" : "bell")
                                .foregroundStyle(minStockAlertThreshold != nil ? .orange : .gray)
                        }
                    }
                    
                    Toggle(isOn: $hasVAT) {
                        HStack(spacing: 4) {
                            Text("Có VAT")
                            InfoPopoverButton(text: "Đánh dấu nếu nguyên liệu này nhập có hoá đơn VAT.")
                        }
                    }
                    .tint(Color.themePrimary)
                }
                
                if case .edit(_) = mode, StoreManager.shared.currentMember?.role == .owner {
                    Section {
                        Button(role: .destructive) {
                            deleteMaterial()
                        } label: {
                            Text("Xóa nguyên liệu")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                
                Section(header: Text("Mã vạch")) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Nhập hoặc quét mã", text: $barcode)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: { showBarcodeScanner = true }) {
                                        Image(systemName: "barcode.viewfinder")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            )
                    }
                    if barcode.isEmpty {
                        Button("Tạo mã vạch tự động") {
                            barcode = BarcodeGenerator.shared.generateRandomBarcode()
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    } else {
                        Button {
                            showPrintBarcode = true
                        } label: {
                            Label("In mã vạch", systemImage: "printer")
                                .font(.caption)
                        }
                    }
                }
                
                // MARK: - Material Import Summary Section
                if case .edit(let material) = mode {
                    Section(header: 
                        HStack {
                            Text("Tổng nhập nguyên liệu")
                            Spacer()
                            Button {
                                showSummaryDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(summaryDateRangeText)
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tổng số lượng nhập")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text(FormatUtils.formatWeight(totalImportedQuantity, unit: selectedUnit))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Số lần nhập")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text("\(importTransactionCount)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.green)
                                }
                            }
                            
                            if totalImportedCost > 0 {
                                HStack {
                                    Text("Tổng giá trị nhập:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Text(formatCurrency(totalImportedCost))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.themeTextDark)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Material Export Summary Section
                    Section(header: 
                        HStack {
                            Text("Tổng xuất nguyên liệu")
                            Spacer()
                            Button {
                                showSummaryDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(summaryDateRangeText)
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tổng số lượng xuất")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text(FormatUtils.formatWeight(totalExportedQuantity, unit: selectedUnit))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.orange)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Số lần xuất")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text("\(exportTransactionCount)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.red)
                                }
                            }
                            
                            if totalExportedCost > 0 {
                                HStack {
                                    Text("Tổng giá trị xuất:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Text(formatCurrency(totalExportedCost))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.themeTextDark)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa giá nhập").font(.headline)
                Text(formatCurrency(Double(costWheelSelection)))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                HStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Button {
                            showCostWheelMillionsRangePicker = true
                        } label: {
                            Text(costWheelMillionsRangeBase <= 0 ? ">0" : ">\(costWheelMillionsRangeBase)tr")
                                .fontWeight(.bold)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        Text("Triệu")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        let millionsRangeMin = costWheelMillionsRangeBase
                        Picker("", selection: $costWheelMillionsSelection) {
                            ForEach(Array(millionsRangeMin...max(millionsRangeMin, millionsRangeMin + 500)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: costWheelMillionsSelection) { newValue in
                            costWheelSelection = newValue * 1_000_000 + costWheelThousandsSelection * 1_000 + costWheelHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button {
                            showCostWheelThousandsRangePicker = true
                        } label: {
                            Text(costWheelThousandsRangeBase <= 0 ? ">0" : ">\(costWheelThousandsRangeBase)")
                                .fontWeight(.bold)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        Text("Ngàn")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        let thousandsRangeMin = costWheelThousandsRangeBase
                        Picker("", selection: $costWheelThousandsSelection) {
                            ForEach(Array(stride(from: thousandsRangeMin, through: min(thousandsRangeMin + 99, 999), by: 1)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: costWheelThousandsSelection) { newValue in
                            costWheelSelection = costWheelMillionsSelection * 1_000_000 + newValue * 1_000 + costWheelHundredsSelection
                        }
                    }
                    VStack(spacing: 2) {
                        Button {
                            showCostWheelHundredsRangePicker = true
                        } label: {
                            Text(costWheelHundredsRangeBase <= 0 ? ">0" : "\(costWheelHundredsRangeBase)")
                                .fontWeight(.bold)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        let hundredsRangeMin = costWheelHundredsRangeBase
                        Picker("", selection: $costWheelHundredsSelection) {
                            ForEach(Array(stride(from: hundredsRangeMin, through: min(hundredsRangeMin + 99, 999), by: 1)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: costWheelHundredsSelection) { newValue in
                            costWheelSelection = costWheelMillionsSelection * 1_000_000 + costWheelThousandsSelection * 1_000 + newValue
                        }
                    }
                }
                HStack {
                    Button("Đóng") { showCostWheel = false }
                    Spacer()
                    Button("Lưu") {
                        importPrice = String(costWheelSelection)
                        showCostWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .onAppear {
                let current = max(0, costWheelSelection)
                costWheelMillionsSelection = current / 1_000_000
                costWheelMillionsRangeBase = (costWheelMillionsSelection / 10) * 10
                let remainder1 = current % 1_000_000
                costWheelThousandsSelection = remainder1 / 1_000
                costWheelThousandsRangeBase = (costWheelThousandsSelection / 100) * 100
                let remainder2 = remainder1 % 1_000
                costWheelHundredsRangeBase = (remainder2 / 100) * 100
                costWheelHundredsSelection = (remainder2 / 10) * 10
            }
            .sheet(isPresented: $showCostWheelMillionsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng triệu").font(.headline)
                    Picker("", selection: $costWheelMillionsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    Button {
                        if costWheelMillionsSelection < costWheelMillionsRangeBase {
                            costWheelMillionsSelection = costWheelMillionsRangeBase
                        }
                        showCostWheelMillionsRangePicker = false
                    } label: {
                        Text("Xong")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showCostWheelThousandsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng ngàn").font(.headline)
                    Picker("", selection: $costWheelThousandsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    Button {
                        if costWheelThousandsSelection < costWheelThousandsRangeBase || costWheelThousandsSelection > costWheelThousandsRangeBase + 99 {
                            costWheelThousandsSelection = costWheelThousandsRangeBase
                        }
                        showCostWheelThousandsRangePicker = false
                    } label: {
                        Text("Xong")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showCostWheelHundredsRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng trăm").font(.headline)
                    Picker("", selection: $costWheelHundredsRangeBase) {
                        ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                            Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    Button {
                        if costWheelHundredsSelection < costWheelHundredsRangeBase || costWheelHundredsSelection > costWheelHundredsRangeBase + 99 {
                            costWheelHundredsSelection = costWheelHundredsRangeBase
                        }
                        showCostWheelHundredsRangePicker = false
                    } label: {
                        Text("Xong")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themePrimary)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .presentationDetents([.height(300)])
            }
        }
        .sheet(isPresented: $showStockWheel) {
            VStack(spacing: 12) {
                Text("Sửa tồn kho").font(.headline)
                HStack {
                    Button {
                        showStockKgRangePicker = true
                    } label: {
                        Text(stockKgRangeBase <= 0 ? ">0" : ">\(stockKgRangeBase)")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                if selectedUnit.lowercased() == "cái" {
                    Picker("", selection: $stockWheelSelection) {
                        ForEach(Array(0...stockWheelMax), id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: stockWheelSelection) { newValue in
                        if newValue >= stockWheelMax - 10 {
                            stockWheelMax += 200
                        }
                    }
                } else {
                    HStack {
                        VStack {
                            Text("Kg").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $stockKgSelection) {
                                ForEach(Array(stockKgRangeBase...stockWheelMax), id: \.self) { kg in
                                    Text("\(kg)").tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        VStack {
                            Text("Gam").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $stockGramsSelection) {
                                ForEach(Array(stride(from: 0, through: stockGramsMax, by: 1)), id: \.self) { g in
                                    Text("\(g)").tag(g)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    .onAppear {
                        let current = stockWheelSelection > 0 ? stockWheelSelection : (Int(stock) ?? 0)
                        stockKgSelection = max(0, current / 1000)
                        let remainder = max(0, current % 1000)
                        stockGramsSelection = (remainder / 10) * 10
                        stockKgRangeBase = (stockKgSelection / 100) * 100
                    }
                }
                HStack {
                    Button("Đóng") { showStockWheel = false }
                    Spacer()
                    Button("Lưu") {
                        let total = selectedUnit.lowercased() == "cái" ? stockWheelSelection : stockKgSelection * 1000 + stockGramsSelection
                        stockWheelSelection = total
                        stock = String(total)
                        showStockWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .sheet(isPresented: $showStockKgRangePicker) {
                VStack(spacing: 16) {
                    Text("Chọn vùng giá trị").font(.headline)
                    Picker("", selection: $stockKgRangeBase) {
                        ForEach(Array(stride(from: 0, through: stockWheelMax, by: 100)), id: \.self) { v in
                            Text(v == 0 ? ">0" : ">\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: stockKgRangeBase) { newValue in
                        if newValue >= stockWheelMax - 100 {
                            stockWheelMax += 500
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            if stockKgSelection < stockKgRangeBase { stockKgSelection = stockKgRangeBase }
                            showStockKgRangePicker = false
                        } label: {
                            Text("Xong")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.themePrimary)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .presentationDetents([.height(320)])
            }
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(onScan: { code in
                barcode = code
                showBarcodeScanner = false
            })
        }
        .sheet(isPresented: $showPrintBarcode) {
            let tempProduct = Product(
                id: { if case .edit(let m) = mode { return m.id } else { return UUID() } }(),
                name: name,
                price: Double(importPrice) ?? 0,
                costPrice: Double(importPrice) ?? 0,
                category: selectedCategoryName,
                imageName: "shippingbox.fill",
                color: "gray",
                stockQuantity: stockWheelSelection,
                barcode: barcode
            )
            BarcodePrintView(product: tempProduct)
        }
        .sheet(isPresented: $showSummaryDatePicker) {
            VStack(spacing: 16) {
                Text("Chọn khoảng thời gian").font(.headline)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Từ ngày").font(.caption).foregroundStyle(.gray)
                        DatePicker("", selection: $summaryStartDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Đến ngày").font(.caption).foregroundStyle(.gray)
                        DatePicker("", selection: $summaryEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
                
                // Quick range buttons
                HStack(spacing: 8) {
                    Button("7 ngày") {
                        summaryEndDate = Date()
                        summaryStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Button("30 ngày") {
                        summaryEndDate = Date()
                        summaryStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Button("3 tháng") {
                        summaryEndDate = Date()
                        summaryStartDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Button("1 năm") {
                        summaryEndDate = Date()
                        summaryStartDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                .font(.caption)
                
                Spacer()
                
                Button("Xong") {
                    showSummaryDatePicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSetThresholdSheet) {
            SetMinStockThresholdSheet(
                currentThreshold: minStockAlertThreshold,
                unit: selectedUnit,
                onSave: { threshold in
                    minStockAlertThreshold = threshold
                    showSetThresholdSheet = false
                },
                onCancel: {
                    showSetThresholdSheet = false
                }
            )
        }
        .onAppear {
            if case .edit(let material) = mode {
                name = material.name
                importPrice = String(Int(material.lastUnitPrice))
                stock = String(material.stockQuantity)
                stockWheelSelection = material.stockQuantity
                costWheelSelection = Int(material.lastUnitPrice)
                selectedCategoryName = material.category
                selectedUnit = material.unit ?? "kg"
                barcode = material.barcode ?? ""
                hasVAT = material.hasVAT
                minStockAlertThreshold = material.minStockAlertThreshold
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private var title: String {
        switch mode {
        case .add: return "Thêm nguyên liệu"
        case .edit: return "Sửa nguyên liệu"
        }
    }
    
    // MARK: - Material Import Summary Computed Properties
    private var summaryDateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM"
        return "\(formatter.string(from: summaryStartDate)) - \(formatter.string(from: summaryEndDate))"
    }
    
    private var totalImportedQuantity: Int {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        let importTxs = viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("nhập") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return importTxs.reduce(0) { total, tx in
            total + tx.items
                .filter { $0.name == materialName }
                .reduce(0) { $0 + $1.quantity }
        }
    }
    
    private var totalImportedCost: Double {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        let importTxs = viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("nhập") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return importTxs.reduce(0) { total, tx in
            total + tx.items
                .filter { $0.name == materialName }
                .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
        }
    }
    
    private var importTransactionCount: Int {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        return viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("nhập") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate &&
            tx.items.contains { $0.name == materialName }
        }.count
    }
    
    // MARK: - Material Export Summary Computed Properties
    private var totalExportedQuantity: Int {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        let exportTxs = viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("xuất") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return exportTxs.reduce(0) { total, tx in
            total + tx.items
                .filter { $0.name == materialName }
                .reduce(0) { $0 + $1.quantity }
        }
    }
    
    private var totalExportedCost: Double {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        let exportTxs = viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("xuất") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return exportTxs.reduce(0) { total, tx in
            total + tx.items
                .filter { $0.name == materialName }
                .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
        }
    }
    
    private var exportTransactionCount: Int {
        guard case .edit(let material) = mode else { return 0 }
        let materialName = material.name
        return viewModel.productionHistory.filter { tx in
            tx.mode.lowercased().contains("xuất") &&
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate &&
            tx.items.contains { $0.name == materialName }
        }.count
    }
    
    private func save() {
        guard let unit = Double(importPrice), let qty = Int(stock) else { return }
        switch mode {
        case .add:
            let material = MaterialItem(id: UUID(), name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName, barcode: barcode.isEmpty ? nil : barcode, unit: selectedUnit, hasVAT: hasVAT, minStockAlertThreshold: minStockAlertThreshold)
            Task {
                try? await viewModel.databaseSaveMaterial(material)
                viewModel.addMaterialCategory(selectedCategoryName)
                await viewModel.loadMaterials()
                dismiss()
            }
        case .edit(let m):
            let updated = MaterialItem(id: m.id, name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName, barcode: barcode.isEmpty ? nil : barcode, unit: selectedUnit, hasVAT: hasVAT, minStockAlertThreshold: minStockAlertThreshold)
            Task {
                try? await viewModel.databaseUpdateMaterial(updated)
                viewModel.addMaterialCategory(selectedCategoryName)
                await viewModel.loadMaterials()
                dismiss()
            }
        }
    }
    
    private func deleteMaterial() {
        if case .edit(let m) = mode {
            Task {
                try? await viewModel.databaseDeleteMaterial(m.id)
                await viewModel.loadMaterials()
                dismiss()
            }
        }
    }
}

struct SetMinStockThresholdSheet: View {
    let currentThreshold: Int?
    let unit: String
    let onSave: (Int?) -> Void
    let onCancel: () -> Void
    
    @State private var thresholdValue: Int = 0
    @State private var isThresholdEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Bật cảnh báo tồn kho thấp", isOn: $isThresholdEnabled)
                        .tint(.orange)
                    
                    if isThresholdEnabled {
                        HStack {
                            Text("Cảnh báo khi còn")
                            Spacer()
                            if unit.lowercased() == "cái" {
                                Stepper("\(thresholdValue) cái", value: $thresholdValue, in: 0...10000)
                            } else {
                                HStack(spacing: 4) {
                                    let kg = thresholdValue / 1000
                                    let grams = thresholdValue % 1000
                                    if kg > 0 {
                                        Text("\(kg) kg")
                                            .fontWeight(.semibold)
                                    }
                                    if grams > 0 {
                                        Text("\(grams) gam")
                                            .fontWeight(.semibold)
                                    }
                                    if kg == 0 && grams == 0 {
                                        Text("0 gam")
                                            .fontWeight(.semibold)
                                    }
                                    Stepper("", value: $thresholdValue, in: 0...1000000, step: 100)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cài đặt cảnh báo")
                } footer: {
                    Text("Khi tồn kho của nguyên liệu đạt mức này, sẽ có cảnh báo trên Trang chủ và được đánh dấu màu đỏ.")
                }
            }
            .navigationTitle("Cảnh báo tồn kho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Lưu") {
                        if isThresholdEnabled {
                            onSave(thresholdValue)
                        } else {
                            onSave(nil)
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let current = currentThreshold {
                    isThresholdEnabled = true
                    thresholdValue = current
                }
            }
        }
    }
}

 
