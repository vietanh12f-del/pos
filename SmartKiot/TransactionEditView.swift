import SwiftUI

struct TransactionEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    let original: ProductionTransaction
    @Environment(\.dismiss) var dismiss
    
    @State private var items: [RestockItem] = []
    @State private var editingIndex: Int?
    @State private var showQuantityWheel = false
    @State private var showUnitPriceWheel = false
    @State private var showAdditionalCostWheel = false
    @State private var quantityWheelSelection = 1
    @State private var quantityWheelMax = 500
    @State private var quantityKgSelection = 0
    @State private var gramsWheelSelection = 0
    @State private var gramsWheelMax = 950
    @State private var unitPriceWheelSelection = 0
    @State private var unitPriceWheelMax = 5000000
    @State private var unitPriceWheelBaseSelection = 0
    @State private var unitPriceWheelHundredsSelection = 0
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostWheelMax = 1000000
    @State private var additionalCostWheelBaseSelection = 0
    @State private var additionalCostWheelHundredsSelection = 0
    @State private var noteText: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Sản phẩm")) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(it.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.themeTextDark)
                                Spacer()
                            }
                            HStack {
                                Text("SL")
                                Spacer()
                                Text(FormatUtils.formatWeight(it.quantity))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        quantityWheelSelection = it.quantity
                                        showQuantityWheel = true
                                    }
                            }
                            HStack {
                                Text("Đơn giá")
                                Spacer()
                                Text(formatCurrency(it.unitPrice))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        unitPriceWheelSelection = Int(it.unitPrice)
                                        showUnitPriceWheel = true
                                    }
                            }
                            HStack {
                                Text("Chi phí")
                                Spacer()
                                Text(formatCurrency(it.additionalCost))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.themePrimary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingIndex = idx
                                        additionalCostWheelSelection = Int(it.additionalCost)
                                        showAdditionalCostWheel = true
                                    }
                            }
                            HStack {
                                Text("Đơn giá gồm chi phí")
                                Spacer()
                                let total = (it.unitPrice * Double(it.quantity)) + it.additionalCost
                                let unitIncl = it.quantity > 0 ? (total / Double(it.quantity)) : it.unitPrice
                                Text(formatCurrency(unitIncl))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                        
                    }
                }
                
                Section(header: Text("Ghi chú chỉnh sửa")) {
                    TextField("Nhập ghi chú", text: Binding(
                        get: { noteText },
                        set: { noteText = $0 }
                    ))
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                }
            }
            .navigationTitle("Sửa giao dịch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let total = items.reduce(0) { $0 + ($1.unitPrice * Double($1.quantity)) + $1.additionalCost }
                        var updated = ProductionTransaction(id: original.id, createdAt: original.createdAt, mode: original.mode, items: items, totalCost: total)
                        updated.note = noteText.isEmpty ? original.note : noteText
                        Task {
                            _ = await viewModel.updateProductionTransaction(original: original, updated: updated)
                            dismiss()
                        }
                    }
                    .disabled(items.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                }
            }
        }
        .onAppear {
            items = original.items
            noteText = original.note ?? ""
        }
        .sheet(isPresented: $showQuantityWheel) {
            NavigationStack {
                Form {
                    Section {
                        HStack {
                            VStack {
                                Text("Kg")
                                    .font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $quantityKgSelection) {
                                    ForEach(Array(0...quantityWheelMax), id: \.self) { kg in
                                        Text("\(kg)").tag(kg)
                                    }
                                }
                                .pickerStyle(.wheel)
                            }
                            VStack {
                                Text("Gam")
                                    .font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $gramsWheelSelection) {
                                    ForEach(Array(stride(from: 0, through: gramsWheelMax, by: 50)), id: \.self) { g in
                                        Text("\(g)").tag(g)
                                    }
                                }
                                .pickerStyle(.wheel)
                            }
                        }
                        .onAppear {
                            let current = quantityWheelSelection
                            quantityKgSelection = max(0, current / 1000)
                            let remainder = max(0, current % 1000)
                            gramsWheelSelection = (remainder / 50) * 50
                        }
                    }
                }
                .navigationTitle("Sửa số lượng")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showQuantityWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex {
                                let total = quantityKgSelection * 1000 + gramsWheelSelection
                                items[i].quantity = total
                                quantityWheelSelection = total
                            }
                            showQuantityWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $showUnitPriceWheel) {
            NavigationStack {
                Form {
                    Section {
                        let step = StoreManager.shared.priceStep
                        HStack {
                            VStack {
                                Text("Giá")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $unitPriceWheelBaseSelection) {
                                    ForEach(Array(stride(from: 0, through: unitPriceWheelMax, by: step)), id: \.self) { v in
                                        Text(formatCurrency(Double(v))).tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: unitPriceWheelBaseSelection) { _, newValue in
                                    unitPriceWheelSelection = newValue + unitPriceWheelHundredsSelection
                                    if newValue > unitPriceWheelMax - (step * 5) {
                                        unitPriceWheelMax += step * 100
                                    }
                                }
                            }
                            VStack {
                                Text("Trăm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $unitPriceWheelHundredsSelection) {
                                    ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: unitPriceWheelHundredsSelection) { _, newValue in
                                    unitPriceWheelSelection = unitPriceWheelBaseSelection + newValue
                                }
                            }
                            .frame(width: 110)
                        }
                    }
                }
                .navigationTitle("Sửa giá nhập")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showUnitPriceWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex { items[i].unitPrice = Double(unitPriceWheelSelection) }
                            showUnitPriceWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, unitPriceWheelSelection)
                unitPriceWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - unitPriceWheelBaseSelection)
                unitPriceWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            NavigationStack {
                Form {
                    Section {
                        let step = StoreManager.shared.priceStep
                        HStack {
                            VStack {
                                Text("Giá")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $additionalCostWheelBaseSelection) {
                                    ForEach(Array(stride(from: 0, through: additionalCostWheelMax, by: step)), id: \.self) { v in
                                        Text(formatCurrency(Double(v))).tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: additionalCostWheelBaseSelection) { _, newValue in
                                    additionalCostWheelSelection = newValue + additionalCostWheelHundredsSelection
                                    if newValue > additionalCostWheelMax - (step * 5) {
                                        additionalCostWheelMax += step * 100
                                    }
                                }
                            }
                            VStack {
                                Text("Trăm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Picker("", selection: $additionalCostWheelHundredsSelection) {
                                    ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: additionalCostWheelHundredsSelection) { _, newValue in
                                    additionalCostWheelSelection = additionalCostWheelBaseSelection + newValue
                                }
                            }
                            .frame(width: 110)
                        }
                    }
                }
                .navigationTitle("Sửa chi phí")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Đóng") { showAdditionalCostWheel = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if let i = editingIndex { items[i].additionalCost = Double(additionalCostWheelSelection) }
                            showAdditionalCostWheel = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, additionalCostWheelSelection)
                additionalCostWheelBaseSelection = (current / step) * step
                let remainder = max(0, current - additionalCostWheelBaseSelection)
                additionalCostWheelHundredsSelection = min(900, (remainder / 100) * 100)
            }
        }
    }
}

 
