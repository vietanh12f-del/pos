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
    @State private var costWheelMax = 5000000
    @State private var costWheelBaseSelection = 0
    @State private var costWheelHundredsSelection = 0
    @State private var costWheelRangeBase = 0
    @State private var showCostWheelRangePicker = false
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
                }            }
        }
        .sheet(isPresented: $showCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa giá nhập").font(.headline)
                HStack {
                    Button {
                        showCostWheelRangePicker = true
                    } label: {
                        Text(costWheelRangeBase <= 0 ? ">0" : ">\(costWheelRangeBase / 1000)k")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                let step = StoreManager.shared.priceStep
                let rangeMin = max(0, (costWheelRangeBase / step) * step)
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $costWheelBaseSelection) {
                            ForEach(Array(stride(from: rangeMin, through: costWheelMax, by: step)), id: \.self) { v in
                                Text(formatCurrency(Double(v))).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: costWheelBaseSelection) { _, newValue in
                            costWheelSelection = newValue + costWheelHundredsSelection
                            if newValue > costWheelMax - (step * 5) {
                                costWheelMax += step * 100
                            }
                        }
                    }
                    VStack {
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $costWheelHundredsSelection) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: costWheelHundredsSelection) { _, newValue in
                            costWheelSelection = costWheelBaseSelection + newValue
                        }
                    }
                    .frame(width: 110)
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
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, costWheelSelection)
                costWheelRangeBase = (current / 100000) * 100000
                costWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - costWheelBaseSelection)
                costWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showCostWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(costWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        costWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if costWheelBaseSelection < rangeMin { costWheelBaseSelection = rangeMin }
                        showCostWheelRangePicker = false
                    }
                }
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
                    .onChange(of: stockWheelSelection) { _, newValue in
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
                                ForEach(Array(stride(from: 0, through: stockGramsMax, by: 10)), id: \.self) { g in
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
                    .onChange(of: stockKgRangeBase) { _, newValue in
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
    
    private func save() {
        guard let unit = Double(importPrice), let qty = Int(stock) else { return }
        switch mode {
        case .add:
            let material = MaterialItem(id: UUID(), name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName, barcode: barcode.isEmpty ? nil : barcode, unit: selectedUnit, hasVAT: hasVAT)
            Task {
                try? await viewModel.databaseSaveMaterial(material)
                viewModel.addMaterialCategory(selectedCategoryName)
                await viewModel.loadMaterials()
                dismiss()
            }
        case .edit(let m):
            let updated = MaterialItem(id: m.id, name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName, barcode: barcode.isEmpty ? nil : barcode, unit: selectedUnit, hasVAT: hasVAT)
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

 
