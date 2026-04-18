import SwiftUI

struct MaterialEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(MaterialItem)
    }
    
    let mode: Mode
    
    @State private var name: String = ""
    @State private var importPrice: String = ""
    @State private var stock: String = "0"
    @State private var showCostWheel = false
    @State private var costWheelSelection = 0
    @State private var costWheelMax = 5000000
    @State private var costWheelBaseSelection = 0
    @State private var costWheelHundredsSelection = 0
    @State private var showStockWheel = false
    @State private var stockWheelSelection = 0
    @State private var stockWheelMax = 1000
    @State private var stockKgSelection = 0
    @State private var stockGramsSelection = 0
    @State private var stockGramsMax = 950
    @State private var selectedCategoryName: String = Category.materials.rawValue
    
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
                        Button {
                            if let v = Double(importPrice) { costWheelSelection = Int(v) }
                            showCostWheel = true
                        } label: {
                            Text(formatCurrency(Double(costWheelSelection > 0 ? costWheelSelection : (Int(Double(importPrice) ?? 0)))))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Tồn kho")
                        Spacer()
                        Button {
                            if let v = Int(stock) { stockWheelSelection = v }
                            showStockWheel = true
                        } label: {
                            Text(FormatUtils.formatWeight(stockWheelSelection > 0 ? stockWheelSelection : (Int(stock) ?? 0)))
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                if case .edit(_) = mode {
                    Section {
                        Button(role: .destructive) {
                            deleteMaterial()
                        } label: {
                            Text("Xóa nguyên liệu")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa giá nhập").font(.headline)
                let step = StoreManager.shared.priceStep
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $costWheelBaseSelection) {
                            ForEach(Array(stride(from: 0, through: costWheelMax, by: step)), id: \.self) { v in
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
                costWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - costWheelBaseSelection)
                costWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
        }
        .sheet(isPresented: $showStockWheel) {
            VStack(spacing: 12) {
                Text("Sửa tồn kho").font(.headline)
                HStack {
                    VStack {
                        Text("Kg").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $stockKgSelection) {
                            ForEach(Array(0...stockWheelMax), id: \.self) { kg in
                                Text("\(kg)").tag(kg)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    VStack {
                        Text("Gam").font(.caption).foregroundStyle(.gray)
                        Picker("", selection: $stockGramsSelection) {
                            ForEach(Array(stride(from: 0, through: stockGramsMax, by: 50)), id: \.self) { g in
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
                    stockGramsSelection = (remainder / 50) * 50
                }
                HStack {
                    Button("Đóng") { showStockWheel = false }
                    Spacer()
                    Button("Lưu") {
                        let total = stockKgSelection * 1000 + stockGramsSelection
                        stockWheelSelection = total
                        stock = String(total)
                        showStockWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
        }
        .onAppear {
            if case .edit(let material) = mode {
                name = material.name
                importPrice = String(Int(material.lastUnitPrice))
                stock = String(material.stockQuantity)
                stockWheelSelection = material.stockQuantity
                costWheelSelection = Int(material.lastUnitPrice)
                selectedCategoryName = material.category
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
            let material = MaterialItem(id: UUID(), name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName)
            Task {
                try? await viewModel.databaseSaveMaterial(material)
                viewModel.addMaterialCategory(selectedCategoryName)
                await viewModel.loadMaterials()
                dismiss()
            }
        case .edit(let m):
            let updated = MaterialItem(id: m.id, name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategoryName)
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

 
