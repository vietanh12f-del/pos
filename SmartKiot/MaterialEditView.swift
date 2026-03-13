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
    @State private var showStockWheel = false
    @State private var stockWheelSelection = 0
    @State private var stockWheelMax = 1000
    @State private var selectedCategory: Category = .materials
    
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
                    
                    Picker("Danh mục", selection: $selectedCategory) {
                        ForEach(Category.allCases.filter { $0 != .all }, id: \.self) { c in
                            Text(c.displayName).tag(c)
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
                            Text("\(stockWheelSelection > 0 ? stockWheelSelection : (Int(stock) ?? 0))")
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
                Picker("", selection: $costWheelSelection) {
                    ForEach(Array(stride(from: 0, through: costWheelMax, by: StoreManager.shared.priceStep)), id: \.self) { v in
                        Text(formatCurrency(Double(v))).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: costWheelSelection) { _, newValue in
                    let step = StoreManager.shared.priceStep
                    if newValue > costWheelMax - (step * 5) {
                        costWheelMax += step * 100
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
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showStockWheel) {
            VStack(spacing: 12) {
                Text("Sửa tồn kho").font(.headline)
                Picker("", selection: $stockWheelSelection) {
                    ForEach(Array(0...stockWheelMax), id: \.self) { v in
                        Text("\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: stockWheelSelection) { v in
                    if v > stockWheelMax - 10 {
                        stockWheelMax += 500
                    }
                }
                .onAppear {
                    if stockWheelSelection > stockWheelMax - 50 {
                        stockWheelMax = stockWheelSelection + 500
                    }
                }
                HStack {
                    Button("Đóng") { showStockWheel = false }
                    Spacer()
                    Button("Lưu") {
                        stock = String(stockWheelSelection)
                        showStockWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .onAppear {
            if case .edit(let material) = mode {
                name = material.name
                importPrice = String(Int(material.lastUnitPrice))
                stock = String(material.stockQuantity)
                stockWheelSelection = material.stockQuantity
                costWheelSelection = Int(material.lastUnitPrice)
                if let cat = Category(rawValue: material.category) {
                    selectedCategory = cat
                } else {
                    selectedCategory = .materials
                }
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
            let material = MaterialItem(id: UUID(), name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategory.rawValue)
            Task {
                try? await viewModel.databaseSaveMaterial(material)
                await viewModel.loadMaterials()
                dismiss()
            }
        case .edit(let m):
            let updated = MaterialItem(id: m.id, name: name, stockQuantity: qty, lastUnitPrice: unit, category: selectedCategory.rawValue)
            Task {
                try? await viewModel.databaseUpdateMaterial(updated)
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
