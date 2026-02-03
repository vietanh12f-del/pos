import SwiftUI

struct RestockEntryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showManualInput = false
    @State private var showScanner = false
    @State private var editingItem: RestockItem?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // List of Items
                    List {
                        if viewModel.restockItems.isEmpty {
                            Text("Nhấn mic để nói hoặc thêm thủ công.")
                                .foregroundStyle(.gray)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.restockItems) { item in
                                HStack {
                                    // Check/Verify Button
                                    Button(action: {
                                        viewModel.toggleRestockItemConfirmation(item)
                                    }) {
                                        Image(systemName: item.isConfirmed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isConfirmed ? .green : .gray)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.themeTextDark)
                                        Text("\(item.quantity) x \(formatCurrency(item.unitPrice))")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(item.totalCost))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themeTextDark)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItem = item
                                }
                            }
                            .onDelete(perform: viewModel.removeRestockItem)
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    // Total & Action
                    VStack(spacing: 16) {
                        HStack {
                            Text("Tổng chi phí")
                                .font(.headline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(viewModel.restockItems.reduce(0) { $0 + $1.totalCost }))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            viewModel.completeRestockSession()
                            dismiss()
                        }) {
                            Text("Hoàn tất nhập hàng")
                                .font(.headline)
                                .foregroundStyle(Color.themeTextDark)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.themePrimary)
                                .cornerRadius(16)
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color.white)
                    .shadow(radius: 5)
                }
                
                // Mic & Manual Input Controls
                VStack {
                    Spacer()
                    
                    // Mic & Manual Input Controls
                    HStack {
                        // Manual Input Button
                        Button(action: { showManualInput = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(radius: 3)
                                .overlay(Image(systemName: "keyboard").foregroundStyle(Color.themeTextDark))
                        }
                        
                        Spacer()
                        
                        // Mic Button
                        VoiceAIButton(viewModel: viewModel, size: 70)
                        
                        Spacer()
                        
                        // Scanner Button
                        Button(action: { showScanner = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(radius: 3)
                                .overlay(Image(systemName: "doc.text.viewfinder").foregroundStyle(Color.themeTextDark))
                        }
                    }
                    .padding(.bottom, 140) // Adjust based on Total section height
                    .padding(.horizontal, 40)
                }
                
                // Voice Overlay
                VoiceOverlayView(viewModel: viewModel)
            }
            .navigationTitle("Nhập hàng")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
            }
            .onAppear {
                viewModel.isRestockMode = true
            }
            .onDisappear {
                viewModel.isRestockMode = false
            }
            .sheet(isPresented: $showManualInput) {
                ManualRestockItemView(viewModel: viewModel)
            }
            .sheet(isPresented: $showScanner) {
                InvoiceScannerView(viewModel: viewModel)
            }
            .sheet(item: $editingItem) { item in
                ManualRestockItemView(viewModel: viewModel, itemToEdit: item)
            }
        }
    }
}

struct ManualRestockItemView: View {
    @ObservedObject var viewModel: OrderViewModel
    var itemToEdit: RestockItem? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var incurredCost = ""
    @State private var sellingPrice = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết hàng hóa")) {
                    TextField("Tên hàng", text: $name)
                    if !name.isEmpty {
                        Text("Tồn hiện tại: \(viewModel.stockLevel(for: name))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    TextField("Số lượng", text: $quantity)
                        .keyboardType(.numberPad)
                        .onChange(of: quantity) { _ in updateSellingPrice() }
                    
                    TextField("Đơn giá nhập", text: $price)
                        .keyboardType(.decimalPad)
                        .onChange(of: price) { newValue in
                            // Filter non-numeric characters first (allow comma and dot)
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                price = filtered
                            }
                            updateSellingPrice()
                        }
                    
                    TextField("Chi phí phát sinh (Ship, bao bì...)", text: $incurredCost)
                        .keyboardType(.decimalPad)
                        .onChange(of: incurredCost) { newValue in
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                incurredCost = filtered
                            }
                            updateSellingPrice()
                        }
                    
                    if let p = parseDouble(price), let q = Int(quantity), q > 0 {
                        let extra = parseDouble(incurredCost) ?? 0
                        let total = (p * Double(q)) + extra
                        let unitCost = total / Double(q)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tổng chi phí:")
                                Spacer()
                                Text(formatCurrency(total))
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Giá vốn/sp:")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(unitCost))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    TextField("Giá bán dự kiến (Lãi 30%)", text: $sellingPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(itemToEdit == nil ? "Thêm hàng nhập" : "Sửa hàng nhập")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(itemToEdit == nil ? "Thêm" : "Lưu") {
                        if let p = parseDouble(price), let q = Int(quantity), !name.isEmpty {
                            let extra = parseDouble(incurredCost) ?? 0
                            let suggested = parseDouble(sellingPrice)
                            
                            if var item = itemToEdit {
                                item.name = name
                                item.quantity = q
                                item.unitPrice = p
                                item.additionalCost = extra
                                item.suggestedPrice = suggested
                                item.isConfirmed = true
                                viewModel.updateRestockItem(item)
                            } else {
                                viewModel.addRestockItem(name, unitPrice: p, quantity: q, additionalCost: extra, suggestedPrice: suggested)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty || quantity.isEmpty)
                }
            }
        }
        .presentationDetents([.height(550)])
        .onAppear {
            if let item = itemToEdit {
                name = item.name
                quantity = String(item.quantity)
                price = String(format: "%.0f", item.unitPrice)
                incurredCost = String(format: "%.0f", item.additionalCost)
                if let s = item.suggestedPrice {
                    sellingPrice = String(format: "%.0f", s)
                }
            }
        }
    }
    
    func updateSellingPrice() {
        if let p = parseDouble(price), let q = Int(quantity), q > 0 {
            let extra = parseDouble(incurredCost) ?? 0
            let total = (p * Double(q)) + extra
            let unitCost = total / Double(q)
            let suggested = unitCost * 1.3
            sellingPrice = String(Int(suggested))
        }
    }
    
    func parseDouble(_ input: String) -> Double? {
        // Handle "2,000" or "20,000" (Thousands separator)
        // If input contains comma, remove it assuming it's a thousands separator for VND
        // e.g. "2,000" -> "2000"
        let clean = input.replacingOccurrences(of: ",", with: "")
        
        return Double(clean)
    }
}
