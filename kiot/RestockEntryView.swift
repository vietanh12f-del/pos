import SwiftUI

struct RestockEntryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showManualInput = false
    @State private var showScanner = false
    @State private var showBarcodeScanner = false
    @State private var scannedProduct: Product?
    @State private var showNotFoundAlert = false
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
                        // Barcode Scanner FAB
                        Button(action: { showBarcodeScanner = true }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.title2)
                                        .foregroundStyle(Color.themePrimary)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))

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
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(onScan: { code in
                showBarcodeScanner = false
                if let product = viewModel.products.first(where: { $0.barcode == code }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scannedProduct = product
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNotFoundAlert = true
                    }
                }
            })
        }
        .alert("Không tìm thấy sản phẩm", isPresented: $showNotFoundAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Không tìm thấy sản phẩm nào khớp với mã vạch này trong hệ thống.")
        }
        .sheet(item: $scannedProduct) { product in
            ManualRestockItemView(viewModel: viewModel, prefilledProduct: product)
        }
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
                if let product = viewModel.products.first(where: { $0.name.lowercased() == item.name.lowercased() }),
                   let imageURL = product.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            ZStack {
                                Color.themePrimary.opacity(0.1)
                                Text(String(item.name.prefix(1)).uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themePrimary)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                } else if let product = viewModel.products.first(where: { $0.name.lowercased() == item.name.lowercased() }),
                          let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.themePrimary.opacity(0.1))
                        
                        Text(String(item.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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
    var prefilledProduct: Product? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var incurredCost = ""
    @State private var sellingPrice = ""
    @State private var showQuantityWheel = false
    @State private var showUnitPriceWheel = false
    @State private var showAdditionalCostWheel = false
    @State private var showSellingPriceWheel = false
    @State private var quantityWheelSelection = 1
    @State private var quantityWheelMax = 500
    @State private var unitPriceWheelSelection = 0
    @State private var unitPriceWheelMax = 5000000
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostWheelMax = 1000000
    @State private var sellingPriceWheelSelection = 0
    @State private var sellingPriceWheelMax = 10000000
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết hàng hóa")) {
                    HStack(spacing: 8) {
                        TextField("Tên hàng", text: $name)
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
                        .contentShape(Rectangle())
                    }
                    .onReceive(viewModel.$manualRecordedName) { newText in
                        if viewModel.isRecordingManualProductName {
                            let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { name = t }
                        }
                    }
                    if !name.isEmpty {
                        Text("Tồn hiện tại: \(viewModel.stockLevel(for: name))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    HStack {
                        Text("Số lượng")
                        Spacer()
                        Button {
                            if let q = Int(quantity), q > 0 { quantityWheelSelection = q }
                            showQuantityWheel = true
                        } label: {
                            Text(quantity.isEmpty ? "\(quantityWheelSelection)" : quantity)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Đơn giá nhập")
                        Spacer()
                        Button {
                            if let p = parseDouble(price) { unitPriceWheelSelection = Int(p) }
                            showUnitPriceWheel = true
                        } label: {
                            Text(formatCurrency(parseDouble(price) ?? Double(unitPriceWheelSelection)))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Chi phí phát sinh")
                        Spacer()
                        Button {
                            if let v = parseDouble(incurredCost) { additionalCostWheelSelection = Int(v) }
                            showAdditionalCostWheel = true
                        } label: {
                            Text(formatCurrency(parseDouble(incurredCost) ?? Double(additionalCostWheelSelection)))
                                .fontWeight(.semibold)
                        }
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
                    
                    HStack {
                        Text("Giá bán dự kiến")
                        Spacer()
                        Button {
                            let base = parseDouble(sellingPrice) ?? ((parseDouble(price) ?? Double(unitPriceWheelSelection)) * 1.3)
                            sellingPriceWheelSelection = Int(base)
                            showSellingPriceWheel = true
                        } label: {
                            Text(
                                formatCurrency(
                                    ((parseDouble(sellingPrice) ?? Double(sellingPriceWheelSelection)) > 0)
                                    ? (parseDouble(sellingPrice) ?? Double(sellingPriceWheelSelection))
                                    : ((parseDouble(price) ?? Double(unitPriceWheelSelection)) * 1.3)
                                )
                            )
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if let p = parseDouble(price), let q = Int(quantity), q > 0 {
                        let extra = parseDouble(incurredCost) ?? 0
                        let total = (p * Double(q)) + extra
                        let unitCost = total / Double(q)
                        HStack {
                            Text("Gợi ý (Lãi 30%)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(unitCost * 1.3))
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    } else {
                        Text("Gợi ý (Lãi 30%): nhập giá/SL để xem")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
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
                    .disabled(name.isEmpty)
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
                quantityWheelSelection = item.quantity
                unitPriceWheelSelection = Int(item.unitPrice)
                additionalCostWheelSelection = Int(item.additionalCost)
                sellingPriceWheelSelection = Int(item.suggestedPrice ?? 0)
            } else if let product = prefilledProduct {
                name = product.name
                // Use last known cost price as default import price
                // If costPrice is 0, use 70% of selling price as a heuristic guess
                let defaultCost = product.costPrice > 0 ? product.costPrice : product.price * 0.7
                price = String(format: "%.0f", defaultCost)
                
                let defaultSuggested = defaultCost * 1.3
                sellingPrice = String(format: "%.0f", defaultSuggested)
                unitPriceWheelSelection = Int(defaultCost)
                sellingPriceWheelSelection = Int(defaultSuggested)
            }
        }
        .sheet(isPresented: $showQuantityWheel) {
            VStack(spacing: 12) {
                Text("Sửa số lượng")
                    .font(.headline)
                Picker("", selection: $quantityWheelSelection) {
                    ForEach(Array(1...quantityWheelMax), id: \.self) { q in
                        Text("\(q)").tag(q)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: quantityWheelSelection) { q in
                    if q > quantityWheelMax - 10 {
                        quantityWheelMax += 500
                    }
                }
                HStack {
                    Button("Đóng") { showQuantityWheel = false }
                    Spacer()
                    Button("Lưu") {
                        quantity = String(quantityWheelSelection)
                        updateSellingPrice()
                        showQuantityWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showUnitPriceWheel) {
            VStack(spacing: 12) {
                Text("Sửa đơn giá")
                    .font(.headline)
                Picker("", selection: $unitPriceWheelSelection) {
                    ForEach(Array(stride(from: 0, through: unitPriceWheelMax, by: StoreManager.shared.priceStep)), id: \.self) { v in
                        Text(formatCurrency(Double(v))).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: unitPriceWheelSelection) { _, newValue in
                    let step = StoreManager.shared.priceStep
                    if newValue > unitPriceWheelMax - (step * 5) {
                        unitPriceWheelMax += step * 100
                    }
                }
                HStack {
                    Button("Đóng") { showUnitPriceWheel = false }
                    Spacer()
                    Button("Lưu") {
                        price = String(unitPriceWheelSelection)
                        let defaultSuggested = Double(unitPriceWheelSelection) * 1.3
                        sellingPrice = String(Int(defaultSuggested))
                        sellingPriceWheelSelection = Int(defaultSuggested)
                        showUnitPriceWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa chi phí")
                    .font(.headline)
                Picker("", selection: $additionalCostWheelSelection) {
                    ForEach(Array(stride(from: 0, through: additionalCostWheelMax, by: StoreManager.shared.priceStep)), id: \.self) { v in
                        Text(formatCurrency(Double(v))).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: additionalCostWheelSelection) { _, newValue in
                    let step = StoreManager.shared.priceStep
                    if newValue > additionalCostWheelMax - (step * 5) {
                        additionalCostWheelMax += step * 100
                    }
                }
                HStack {
                    Button("Đóng") { showAdditionalCostWheel = false }
                    Spacer()
                    Button("Lưu") {
                        incurredCost = String(additionalCostWheelSelection)
                        updateSellingPrice()
                        showAdditionalCostWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSellingPriceWheel) {
            VStack(spacing: 12) {
                Text("Sửa giá bán")
                    .font(.headline)
                Picker("", selection: $sellingPriceWheelSelection) {
                    ForEach(Array(stride(from: 0, through: sellingPriceWheelMax, by: StoreManager.shared.priceStep)), id: \.self) { v in
                        Text(formatCurrency(Double(v))).tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: sellingPriceWheelSelection) { _, newValue in
                    let step = StoreManager.shared.priceStep
                    if newValue > sellingPriceWheelMax - (step * 5) {
                        sellingPriceWheelMax += step * 100
                    }
                }
                HStack {
                    Button("Đóng") { showSellingPriceWheel = false }
                    Spacer()
                    Button("Lưu") {
                        sellingPrice = String(sellingPriceWheelSelection)
                        showSellingPriceWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
        }
    }
    
    func updateSellingPrice() {
        let p = parseDouble(price) ?? Double(unitPriceWheelSelection)
        let q = Int(quantity) ?? quantityWheelSelection
        if q > 0 {
            let extra = parseDouble(incurredCost) ?? Double(additionalCostWheelSelection)
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
