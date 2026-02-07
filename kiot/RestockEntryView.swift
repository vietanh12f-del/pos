import SwiftUI

struct RestockEntryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showManualInput = false
    @State private var showScanner = false
    @State private var editingItem: RestockItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color.themeBackgroundLight.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Nhập hàng")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    Button(action: { 
                        viewModel.cancelVoiceProcessing()
                        dismiss() 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                .padding()
                .padding(.top, 10)
                .background(Color.white)
                
                // Content
                if viewModel.restockItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Chưa có hàng hóa nào")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.gray)
                        Text("Nhấn vào mic để nói hoặc dùng các công cụ bên dưới")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                        Spacer() // Push up a bit
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.restockItems) { item in
                                RestockItemCard(item: item, viewModel: viewModel)
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.removeRestockItem(at: IndexSet(integer: viewModel.restockItems.firstIndex(where: {$0.id == item.id}) ?? 0))
                                        } label: {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                        .padding(.bottom, 160) // Space for bottom panel + FABs
                    }
                }
            }
            
            // Floating Controls & Bottom Panel
            VStack(spacing: 0) {
                Spacer()
                
                // Floating Action Buttons (FABs)
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Scanner FAB
                        Button(action: { showScanner = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.title2)
                                        .foregroundStyle(Color.themePrimary)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                        
                        // Manual Input FAB
                        Button(action: { showManualInput = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Image(systemName: "keyboard")
                                        .font(.title2)
                                        .foregroundStyle(Color.themePrimary)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                        
                        // Main Mic FAB (Matching SmartOrderEntryView)
                        VoiceAIButton(viewModel: viewModel, size: 64)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
                
                // Bottom Panel (Total & Complete)
                VStack(spacing: 16) {
                    // Total Info
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Tổng chi phí")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(viewModel.restockItems.reduce(0) { $0 + $1.totalCost }))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.completeRestockSession()
                            dismiss()
                        }) {
                            HStack {
                                Text("Hoàn tất")
                                Image(systemName: "checkmark")
                            }
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(viewModel.restockItems.isEmpty ? Color.gray : Color.themePrimary)
                            )
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                    }
                }
                .padding(24)
                .background(
                    Color.white
                        .cornerRadius(24, corners: [.topLeft, .topRight])
                        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                )
            }
            
            // Voice Overlay
            VoiceOverlayView(viewModel: viewModel)
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.isRestockMode = true }
        .onDisappear { 
            viewModel.isRestockMode = false 
            viewModel.cancelVoiceProcessing()
        }
        .sheet(isPresented: $showManualInput) { ManualRestockItemView(viewModel: viewModel) }
        .sheet(isPresented: $showScanner) { InvoiceScannerView(viewModel: viewModel) }
        .sheet(item: $editingItem) { item in ManualRestockItemView(viewModel: viewModel, itemToEdit: item) }
    }
}

// Helper View for Item Card
struct RestockItemCard: View {
    let item: RestockItem
    @ObservedObject var viewModel: OrderViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon/Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.themePrimary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(String(item.name.prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(item.quantity)", systemImage: "number")
                    Label(formatCurrency(item.unitPrice), systemImage: "tag")
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(item.totalCost))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Button(action: {
                    withAnimation {
                        viewModel.toggleRestockItemConfirmation(item)
                    }
                }) {
                    Image(systemName: item.isConfirmed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isConfirmed ? .green : .gray.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isConfirmed ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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
