import SwiftUI
import UIKit

struct RestockEntryView: View {
    @ObservedObject var viewModel: OrderViewModel
    var titleText: String = "Nhập hàng"
    var summaryTitle: String = "Tóm tắt nhập hàng"
    var useInventoryList: Bool = true
    var useMaterialsList: Bool = false
    var onComplete: (([RestockItem]) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var showManualInput = false
    @State private var showScanner = false
    @State private var showBarcodeScanner = false
    @State private var scannedProduct: Product?
    @State private var showNotFoundAlert = false
    @State private var editingItem: RestockItem?
    @State private var showSummaryQtyWheel = false
    @State private var showSummaryPriceWheel = false
    @State private var summaryEditingIndex: Int?
    @State private var summaryQtySelection = 1
    @State private var summaryQtyMax = 1000
    @State private var summaryQtyKgSelection = 0
    @State private var summaryQtyGramsSelection = 0
    @State private var summaryQtyGramsMax = 950
    @State private var summaryQtyRangeBase = 0
    @State private var showSummaryQtyRangePicker = false
    @State private var summaryPriceSelection = 0
    @State private var summaryPriceBaseSelection = 0
    @State private var summaryPriceHundredsSelection = 0
    @State private var summaryPriceMax = 5_000_000
    @State private var summaryPriceRangeBase = 0
    @State private var showSummaryPriceRangePicker = false
    @State private var summaryIsMaterials = false
    @State private var inventorySubTab: Int = 0
    @State private var lastAddedItemId: UUID? = nil
    @State private var selectedCategoryFilter: String = "Tất cả"
    @State private var showSourcePicker = false
    @State private var sourcePickerIndex: Int? = nil
    @State private var sourcePickerOptions: [String] = []
    @State private var showExportInfoSheet = false
    @State private var showImportInfoSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color.themeBackgroundLight.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(titleText)
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
                
                VStack(spacing: 0) {
                    if useInventoryList {
                        // Dynamic category chips showing only categories with items
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                let dynamicCats: [String] = {
                                    if useMaterialsList {
                                        return Array(Set(viewModel.materials.map { $0.category })).sorted()
                                    } else {
                                        let source = inventorySubTab == 0 ? viewModel.products.filter { $0.isFinishedGood } : viewModel.products.filter { !$0.isFinishedGood && $0.stockQuantity > 0 }
                                        return Array(Set(source.map { $0.category })).sorted()
                                    }
                                }()
                                let allCats = ["Tất cả"] + dynamicCats.sorted()
                                ForEach(allCats, id: \.self) { cat in
                                    Button {
                                        selectedCategoryFilter = cat
                                    } label: {
                                        Text(cat)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedCategoryFilter == cat ? Color.themePrimary.opacity(0.15) : Color.gray.opacity(0.1))
                                            .foregroundStyle(selectedCategoryFilter == cat ? Color.themePrimary : Color.themeTextDark)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color.white)
                        }
                        
                        if !useMaterialsList {
                            HStack {
                                Button(action: { inventorySubTab = 0 }) {
                                    Text("Thành phẩm")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(inventorySubTab == 0 ? Color.themePrimary.opacity(0.15) : Color.gray.opacity(0.1))
                                        .foregroundStyle(inventorySubTab == 0 ? Color.themePrimary : Color.themeTextDark)
                                        .cornerRadius(14)
                                }
                                Button(action: { inventorySubTab = 1 }) {
                                    Text("Kho hàng hóa")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(inventorySubTab == 1 ? Color.themePrimary.opacity(0.15) : Color.gray.opacity(0.1))
                                        .foregroundStyle(inventorySubTab == 1 ? Color.themePrimary : Color.themeTextDark)
                                        .cornerRadius(14)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                        
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                            TextField(useMaterialsList ? "Tìm nguyên liệu có sẵn..." : "Tìm sản phẩm có sẵn...", text: $viewModel.searchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !viewModel.searchText.isEmpty {
                                Button { viewModel.searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if useMaterialsList {
                                    ForEach(viewModel.materials.filter { m in
                                        let catOK = (selectedCategoryFilter == "Tất cả") || (m.category.lowercased() == selectedCategoryFilter.lowercased())
                                        let s = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if s.isEmpty { return catOK }
                                        let q = s.lowercased()
                                        return catOK && (m.name.lowercased().contains(q) || m.category.lowercased().contains(q))
                                    }) { m in
                                        VStack(spacing: 8) {
                                            HStack {
                                                Text(formatCurrency(m.lastUnitPrice))
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(Color.themePrimary)
                                                Spacer()
                                            }
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12).fill(Color.white)
                                                VStack(spacing: 6) {
                                                    Text(m.name)
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.themeTextDark)
                                                        .lineLimit(2)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                    HStack {
                                                        Text("Kho: \(FormatUtils.formatWeight(m.stockQuantity))")
                                                            .font(.caption)
                                                            .foregroundStyle(.gray)
                                                        Spacer()
                                                    }
                                                }
                                                .padding(10)
                                            }
                                        .onTapGesture {
                                            let isExport = titleText.lowercased().contains("xuất")
                                            if isExport {
                                                if let idx = viewModel.restockItems.firstIndex(where: { $0.name.lowercased() == m.name.lowercased() }) {
                                                    viewModel.restockItems[idx].quantity += 1000
                                                    viewModel.restockItems[idx].unitPrice = m.lastUnitPrice
                                                    viewModel.restockItems[idx].category = m.category
                                                    lastAddedItemId = viewModel.restockItems[idx].id
                                                } else {
                                                    viewModel.addRestockItem(m.name, unitPrice: m.lastUnitPrice, quantity: 1000, additionalCost: 0, suggestedPrice: nil, category: m.category)
                                                    if let newIdx = viewModel.restockItems.lastIndex(where: { $0.name.lowercased() == m.name.lowercased() }) {
                                                        lastAddedItemId = viewModel.restockItems[newIdx].id
                                                    }
                                                }
                                            } else {
                                                if let idx = viewModel.restockItems.firstIndex(where: { $0.name.lowercased() == m.name.lowercased() }) {
                                                    viewModel.restockItems[idx].quantity += 1000
                                                    viewModel.restockItems[idx].unitPrice = m.lastUnitPrice
                                                    viewModel.restockItems[idx].category = m.category
                                                    lastAddedItemId = viewModel.restockItems[idx].id
                                                } else {
                                                    viewModel.addRestockItem(m.name, unitPrice: m.lastUnitPrice, quantity: 1000, additionalCost: 0, suggestedPrice: nil, category: m.category)
                                                    if let newIdx = viewModel.restockItems.lastIndex(where: { $0.name.lowercased() == m.name.lowercased() }) {
                                                        lastAddedItemId = viewModel.restockItems[newIdx].id
                                                    }
                                                }
                                            }
                                        }
                                            .frame(height: 110)
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                } else {
                                    ForEach((inventorySubTab == 0 ? viewModel.products.filter { $0.isFinishedGood } : viewModel.products.filter { !$0.isFinishedGood && $0.stockQuantity > 0 }).filter { p in
                                        let catOK = (selectedCategoryFilter == "Tất cả") || (p.category.lowercased() == selectedCategoryFilter.lowercased())
                                        let s = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if s.isEmpty {
                                            return catOK
                                        } else {
                                            let q = s.lowercased()
                                            return catOK && (p.name.lowercased().contains(q) || p.category.lowercased().contains(q) || (p.barcode?.contains(s) ?? false))
                                        }
                                    }) { p in
                                        VStack(spacing: 8) {
                                            HStack {
                                                Text(formatCurrency(p.price))
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(Color.themePrimary)
                                                Spacer()
                                            }
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12).fill(Color.white)
                                                VStack(spacing: 6) {
                                                    Text(p.name)
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.themeTextDark)
                                                        .lineLimit(2)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                    HStack {
                                                        let qtyText = inventorySubTab == 0
                                                            ? FormatUtils.formatWeight(p.stockQuantity)
                                                            : String(viewModel.stockLevel(for: p.name))
                                                        Text("Kho: \(qtyText)")
                                                            .font(.caption)
                                                            .foregroundStyle(.gray)
                                                        Spacer()
                                                    }
                                                }
                                                .padding(10)
                                            }
                                            .onTapGesture { 
                                                let isExport = titleText.lowercased().contains("xuất")
                                                if inventorySubTab == 1 {
                                                    // Quick add for stocked goods in inventory: +1 each tap
                                                    let unit = p.costPrice > 0 ? p.costPrice : p.price
                                                    if let idx = viewModel.restockItems.firstIndex(where: { $0.name.lowercased() == p.name.lowercased() }) {
                                                        viewModel.restockItems[idx].quantity += 1
                                                        viewModel.restockItems[idx].unitPrice = unit
                                                        viewModel.restockItems[idx].category = p.category
                                                        lastAddedItemId = viewModel.restockItems[idx].id
                                                    } else {
                                                        viewModel.addRestockItem(p.name, unitPrice: unit, quantity: 1, additionalCost: 0, suggestedPrice: nil, category: p.category)
                                                        if let newIdx = viewModel.restockItems.lastIndex(where: { $0.name.lowercased() == p.name.lowercased() }) {
                                                            lastAddedItemId = viewModel.restockItems[newIdx].id
                                                        }
                                                    }
                                                } else {
                                                    // Tab Thành phẩm: thêm nhanh 1kg cho cả nhập/xuất
                                                    let qty = 1000
                                                    let unit = p.price
                                                    if let idx = viewModel.restockItems.firstIndex(where: { $0.name.lowercased() == p.name.lowercased() }) {
                                                        viewModel.restockItems[idx].quantity += qty
                                                        viewModel.restockItems[idx].unitPrice = unit
                                                        viewModel.restockItems[idx].category = p.category
                                                        lastAddedItemId = viewModel.restockItems[idx].id
                                                    } else {
                                                        viewModel.addRestockItem(p.name, unitPrice: unit, quantity: qty, additionalCost: 0, suggestedPrice: nil, category: p.category)
                                                        if let newIdx = viewModel.restockItems.lastIndex(where: { $0.name.lowercased() == p.name.lowercased() }) {
                                                            lastAddedItemId = viewModel.restockItems[newIdx].id
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(height: 110)
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "shippingbox")
                                .font(.system(size: 80))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Text("Chưa có dữ liệu")
                                .font(.headline)
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        .padding(.bottom, 8)
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
                
                EmptyView()
            }
            
            // Voice Overlay
            VoiceOverlayView(viewModel: viewModel)
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                HStack {
                    Text(summaryTitle)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                if viewModel.restockItems.isEmpty {
                    VStack(spacing: 12) {
                        Text("Chưa có hàng hóa nào")
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 8)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(Array(viewModel.restockItems.enumerated()), id: \.element.id) { idx, item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            let explicit = item.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                            let displayed = explicit.isEmpty ? (viewModel.latestSource(for: item.name) ?? "") : explicit
                                            HStack(spacing: 8) {
                                                Text(item.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.themeTextDark)
                                                    .onTapGesture { editingItem = item }
                                                Spacer(minLength: 8)
                                                if !displayed.isEmpty {
                                                    Text(displayed)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.themePrimary)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(Capsule().fill(Color.themePrimary.opacity(0.12)))
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            let options = viewModel.sourceHistory(for: item.name)
                                                            if !options.isEmpty {
                                                                sourcePickerIndex = idx
                                                                sourcePickerOptions = options
                                                                showSourcePicker = true
                                                            }
                                                        }
                                                }
                                            }
                                            HStack(spacing: 10) {
                                                let isWeight = useMaterialsList || titleText.lowercased().contains("thành phẩm")
                                                HStack(spacing: 6) {
                                                    Text("SL:")
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                    Text(isWeight ? FormatUtils.formatWeight(item.quantity) : String(item.quantity))
                                                        .font(.headline)
                                                        .fontWeight(.heavy)
                                                        .monospacedDigit()
                                                        .foregroundStyle(Color.themePrimary)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .frame(minWidth: 120, minHeight: 36, alignment: .leading)
                                                .background(Color.clear)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    summaryEditingIndex = idx
                                                    summaryIsMaterials = useMaterialsList || titleText.lowercased().contains("thành phẩm")
                                                    if summaryIsMaterials {
                                                        let grams = max(0, item.quantity)
                                                        summaryQtyKgSelection = grams / 1000
                                                        summaryQtyGramsSelection = ((grams % 1000) / 50) * 50
                                                        if summaryQtyKgSelection > summaryQtyMax {
                                                            summaryQtyMax = max(summaryQtyMax, summaryQtyKgSelection + 200)
                                                        }
                                                    } else {
                                                        summaryQtySelection = max(1, item.quantity)
                                                    }
                                                    showSummaryQtyWheel = true
                                                }
                                                HStack(spacing: 6) {
                                                    let priceTitle = useMaterialsList ? "Đơn giá:" : (titleText.lowercased().contains("xuất") ? "Giá xuất:" : "Giá nhập:")
                                                    Text(priceTitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                    Text(formatCurrency(item.unitPrice))
                                                        .font(.headline)
                                                        .fontWeight(.heavy)
                                                        .monospacedDigit()
                                                        .foregroundStyle(Color.themePrimary)
                                                }
                                                .onTapGesture {
                                                    summaryEditingIndex = idx
                                                    summaryPriceSelection = Int(item.unitPrice)
                                                    let step = StoreManager.shared.priceStep
                                                    summaryPriceBaseSelection = (summaryPriceSelection / step) * step
                                                    let remainder = max(0, summaryPriceSelection - summaryPriceBaseSelection)
                                                    summaryPriceHundredsSelection = min(900, (remainder / 100) * 100)
                                                    showSummaryPriceWheel = true
                                                }
                                                if item.additionalCost > 0 {
                                                    Text("Phí: \(formatCurrency(item.additionalCost))")
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                }
                                            }
                                        }
                                        Spacer()
                                        Button {
                                            editingItem = item
                                        } label: {
                                            Text("Sửa")
                                                .font(.subheadline).fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(Color.themePrimary))
                                        }
                                        Button {
                                            if let idx = viewModel.restockItems.firstIndex(where: { $0.id == item.id }) {
                                                viewModel.removeRestockItem(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .id(item.id)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .onChange(of: lastAddedItemId) { _, newId in
                            if let target = newId {
                                withAnimation { proxy.scrollTo(target, anchor: .center) }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                
                HStack {
                    if isFinishedGoodsExportContext() {
                        // "Xuất thành phẩm" → show export info sheet
                        Button {
                            showExportInfoSheet = true
                        } label: {
                            HStack {
                                Text("Thông tin xuất")
                                Image(systemName: "doc.text.fill")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.restockItems.isEmpty ? Color.gray : Color.purple)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    } else if isImportMaterialsContext() {
                        // "Nhập nguyên liệu" → show import info sheet
                        Button {
                            showImportInfoSheet = true
                        } label: {
                            HStack {
                                Text("Thông tin nhập")
                                Image(systemName: "doc.text.fill")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.restockItems.isEmpty ? Color.gray : Color.green)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    } else {
                        Button {
                            if let cb = onComplete {
                                cb(viewModel.restockItems)
                            } else {
                                viewModel.completeRestockSession()
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Text("Hoàn tất")
                                Image(systemName: "checkmark")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.restockItems.isEmpty ? Color.gray : Color.themePrimary)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        }
                        .disabled(viewModel.restockItems.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding(.bottom, 6)
            .background(
                Color.white
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            )
        }
        .onAppear { 
            viewModel.isRestockMode = true 
            let tag = "\(titleText)|\(useMaterialsList ? "materials" : "products")"
            if viewModel.currentRestockSessionTag != tag {
                viewModel.restockItems.removeAll()
                viewModel.currentRestockSessionTag = tag
            }
            if useInventoryList && useMaterialsList {
                Task { await viewModel.loadMaterials() }
            } else if useInventoryList && !useMaterialsList {
                Task { await viewModel.loadProducts() }
                let t = titleText.lowercased()
                if t.contains("kho") || t.contains("nhập hàng") {
                    inventorySubTab = 1
                } else {
                    inventorySubTab = 0
                }
            }
        }
        .onDisappear { 
            viewModel.isRestockMode = false 
            viewModel.cancelVoiceProcessing()
            viewModel.cancelRestockEditingIfNeeded()
        }
        .sheet(isPresented: $showExportInfoSheet) {
            FinishedGoodsExportView(
                viewModel: viewModel,
                items: viewModel.restockItems,
                isImport: false
            ) {
                if let cb = onComplete {
                    cb(viewModel.restockItems)
                } else {
                    viewModel.completeProductionTransaction(mode: titleText)
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showImportInfoSheet) {
            FinishedGoodsExportView(
                viewModel: viewModel,
                items: viewModel.restockItems,
                isImport: true
            ) {
                if let cb = onComplete {
                    cb(viewModel.restockItems)
                } else {
                    viewModel.completeProductionTransaction(mode: titleText)
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showManualInput) { 
            ManualRestockItemView(
                viewModel: viewModel, 
                isFinishedGoods: isFinishedGoodsContext(),
                addTitle: computedAddTitle(),
                editTitle: computedEditTitle()
            ) 
        }
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
            ManualRestockItemView(
                viewModel: viewModel, 
                prefilledProduct: product, 
                isFinishedGoods: isFinishedGoodsContext(),
                addTitle: computedAddTitle(),
                editTitle: computedEditTitle()
            )
        }
        .sheet(item: $editingItem) { item in
            ManualRestockItemView(
                viewModel: viewModel, 
                itemToEdit: item, 
                isFinishedGoods: isFinishedGoodsContext(),
                addTitle: computedAddTitle(),
                editTitle: computedEditTitle()
            )
        }
        .confirmationDialog("Chọn nguồn nhập", isPresented: $showSourcePicker, titleVisibility: .visible) {
            ForEach(sourcePickerOptions, id: \.self) { src in
                Button(src) {
                    guard let idx = sourcePickerIndex else { return }
                    guard idx >= 0 && idx < viewModel.restockItems.count else { return }
                    var updated = viewModel.restockItems[idx]
                    updated.source = src
                    viewModel.updateRestockItem(updated)
                    sourcePickerIndex = nil
                    sourcePickerOptions = []
                }
            }
        }
        // Inline quantity edit
        .sheet(isPresented: $showSummaryQtyWheel) {
            VStack(spacing: 12) {
                Text("Sửa số lượng").font(.headline)
                HStack {
                    Button {
                        showSummaryQtyRangePicker = true
                    } label: {
                        Text(summaryQtyRangeBase <= 0 ? ">0" : ">\(summaryQtyRangeBase)")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                if summaryIsMaterials {
                    HStack {
                        VStack {
                            Text("Kg").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $summaryQtyKgSelection) {
                                ForEach(Array(summaryQtyRangeBase...summaryQtyMax), id: \.self) { kg in
                                    Text("\(kg)").tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: summaryQtyKgSelection) { _, newValue in
                                if newValue >= max(0, summaryQtyMax - 10) {
                                    summaryQtyMax += 200
                                }
                            }
                        }
                        VStack {
                            Text("Gam").font(.caption).foregroundStyle(.gray)
                            Picker("", selection: $summaryQtyGramsSelection) {
                                ForEach(Array(stride(from: 0, through: summaryQtyGramsMax, by: 50)), id: \.self) { g in
                                    Text("\(g)").tag(g)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                } else {
                    Picker("", selection: $summaryQtySelection) {
                        let minValue = Swift.max(1, summaryQtyRangeBase)
                        ForEach(Array(minValue...summaryQtyMax), id: \.self) { q in
                            Text("\(q)").tag(q)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                HStack {
                    Button("Đóng") { showSummaryQtyWheel = false }
                    Spacer()
                    Button("Lưu") {
                        if let i = summaryEditingIndex, i < viewModel.restockItems.count {
                            if summaryIsMaterials {
                                let grams = summaryQtyKgSelection * 1000 + summaryQtyGramsSelection
                                viewModel.restockItems[i].quantity = grams
                            } else {
                                viewModel.restockItems[i].quantity = summaryQtySelection
                            }
                        }
                        showSummaryQtyWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .onAppear {
                if summaryIsMaterials {
                    summaryQtyRangeBase = (summaryQtyKgSelection / 100) * 100
                } else {
                    summaryQtyRangeBase = (summaryQtySelection / 100) * 100
                }
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showSummaryQtyRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: summaryQtyMax, by: 100)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v)") {
                        summaryQtyRangeBase = v
                        if summaryIsMaterials {
                            if summaryQtyKgSelection < v { summaryQtyKgSelection = v }
                        } else {
                            let minValue = Swift.max(1, v)
                            if summaryQtySelection < minValue { summaryQtySelection = minValue }
                        }
                        showSummaryQtyRangePicker = false
                    }
                }
            }
        }
        // Inline price edit
        .sheet(isPresented: $showSummaryPriceWheel) {
            VStack(spacing: 12) {
                Text(useMaterialsList ? "Sửa đơn giá" : "Sửa giá bán dự kiến").font(.headline)
                let step = StoreManager.shared.priceStep
                let rangeMin = max(0, (summaryPriceRangeBase / step) * step)
                HStack {
                    Button {
                        showSummaryPriceRangePicker = true
                    } label: {
                        Text(summaryPriceRangeBase <= 0 ? ">0" : ">\(summaryPriceRangeBase / 1000)k")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $summaryPriceBaseSelection) {
                            ForEach(Array(stride(from: rangeMin, through: summaryPriceMax, by: step)), id: \.self) { v in
                                Text(formatCurrency(Double(v))).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: summaryPriceBaseSelection) { _, newValue in
                            summaryPriceSelection = newValue + summaryPriceHundredsSelection
                            if newValue > summaryPriceMax - (step * 5) {
                                summaryPriceMax += step * 100
                            }
                        }
                    }
                    VStack {
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $summaryPriceHundredsSelection) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: summaryPriceHundredsSelection) { _, newValue in
                            summaryPriceSelection = summaryPriceBaseSelection + newValue
                        }
                    }
                    .frame(width: 110)
                }
                HStack {
                    Button("Đóng") { showSummaryPriceWheel = false }
                    Spacer()
                    Button("Lưu") {
                        if let i = summaryEditingIndex, i < viewModel.restockItems.count {
                            viewModel.restockItems[i].unitPrice = Double(summaryPriceSelection)
                        }
                        showSummaryPriceWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, summaryPriceSelection)
                summaryPriceRangeBase = (current / 100000) * 100000
                summaryPriceBaseSelection = (current / step) * step
                let remainder = max(0, current - summaryPriceBaseSelection)
                summaryPriceHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showSummaryPriceRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(summaryPriceMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        summaryPriceRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if summaryPriceBaseSelection < rangeMin { summaryPriceBaseSelection = rangeMin }
                        showSummaryPriceRangePicker = false
                    }
                }
            }
        }
    }
}

private extension RestockEntryView {
    func computedAddTitle() -> String {
        let t = titleText.lowercased()
        let isExport = t.contains("xuất")
        if !useMaterialsList && inventorySubTab == 0 { return isExport ? "Thêm thành phẩm xuất" : "Thêm thành phẩm nhập" }
        // Inventory goods entry should not say "thành phẩm"
        if !useMaterialsList && (t.contains("kho") || t.contains("nhập hàng")) {
            return isExport ? "Thêm hàng xuất" : "Thêm hàng nhập"
        }
        if useMaterialsList { return isExport ? "Thêm nguyên liệu xuất" : "Thêm nguyên liệu nhập" }
        // Finished goods (production)
        if t.contains("thành phẩm") { return isExport ? "Thêm thành phẩm xuất" : "Thêm thành phẩm nhập" }
        return isExport ? "Thêm hàng xuất" : "Thêm hàng nhập"
    }
    func computedEditTitle() -> String {
        let t = titleText.lowercased()
        let isExport = t.contains("xuất")
        if !useMaterialsList && inventorySubTab == 0 { return isExport ? "Sửa thành phẩm xuất" : "Sửa thành phẩm nhập" }
        if !useMaterialsList && (t.contains("kho") || t.contains("nhập hàng")) {
            return isExport ? "Sửa hàng xuất" : "Sửa hàng nhập"
        }
        if useMaterialsList { return isExport ? "Sửa nguyên liệu xuất" : "Sửa nguyên liệu nhập" }
        if t.contains("thành phẩm") { return isExport ? "Sửa thành phẩm xuất" : "Sửa thành phẩm nhập" }
        return isExport ? "Sửa hàng xuất" : "Sửa hàng nhập"
    }
    func isFinishedGoodsContext() -> Bool {
        if useMaterialsList { return false }
        let t = titleText.lowercased()
        return inventorySubTab == 0 || t.contains("thành phẩm")
    }

    func isFinishedGoodsExportContext() -> Bool {
        if useMaterialsList { return false }
        let t = titleText.lowercased()
        return t.contains("xuất thành phẩm") || t.contains("xuất thành phẩm")
    }

    func isImportMaterialsContext() -> Bool {
        let t = titleText.lowercased()
        return t.contains("nhập nguyên liệu")
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
    var isFinishedGoods: Bool = false
    var addTitle: String = "Thêm hàng nhập"
    var editTitle: String = "Sửa hàng nhập"
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var incurredCost = ""
    @State private var showQuantityWheel = false
    @State private var showUnitPriceWheel = false
    @State private var showAdditionalCostWheel = false
    // removed selling price UI
    @State private var quantityWheelSelection = 1
    @State private var quantityWheelMax = 500
    @State private var quantityKgSelection = 0
    @State private var gramsWheelSelection = 0
    @State private var gramsWheelMax = 950
    @State private var quantityKgRangeBase = 0
    @State private var showQuantityKgRangePicker = false
    @State private var unitPriceWheelSelection = 0
    @State private var unitPriceWheelMax = 5000000
    @State private var unitPriceBaseSelection = 0
    @State private var unitPriceHundredsSelection = 0
    @State private var unitPriceWheelRangeBase = 0
    @State private var showUnitPriceWheelRangePicker = false
    @State private var additionalCostWheelSelection = 0
    @State private var additionalCostWheelMax = 1000000
    @State private var additionalCostBaseSelection = 0
    @State private var additionalCostHundredsSelection = 0
    @State private var additionalCostWheelRangeBase = 0
    @State private var showAdditionalCostWheelRangePicker = false
    @State private var showSuggestedPriceWheel = false
    @State private var suggestedPriceWheelSelection = 0
    @State private var suggestedPriceWheelMax = 10_000_000
    @State private var suggestedPriceBaseSelection = 0
    @State private var suggestedPriceHundredsSelection = 0
    @State private var suggestedPriceWheelRangeBase = 0
    @State private var showSuggestedPriceWheelRangePicker = false
    @State private var selectedCategoryName: String = Category.materials.rawValue
    @State private var showCategorySheet = false
    @State private var newCategoryName: String = ""
    @State private var showNamePicker = false
    @State private var nameSearch = ""
    @State private var sourceText: String = ""
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
    
    private var isSimpleFinishedGoodsEdit: Bool {
        isFinishedGoods && itemToEdit != nil && editTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "sửa thành phẩm"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(isFinishedGoods ? "Chi tiết thành phẩm" : "Chi tiết hàng hóa")) {
                    HStack(spacing: 8) {
                        TextField(isFinishedGoods ? "Tên thành phẩm" : "Tên hàng", text: $name)
                        Button {
                            showNamePicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
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
                    .onChange(of: name) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { return }
                        if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if let latest = viewModel.latestSource(for: trimmed) {
                                sourceText = latest
                            }
                        }
                    }
                    if !name.isEmpty {
                        let isWeightContext = addTitle.lowercased().contains("nguyên liệu") || addTitle.lowercased().contains("thành phẩm")
                        let current = viewModel.currentStockLevel(for: name)
                        HStack(spacing: 4) {
                            Text("Tồn hiện tại:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            if isWeightContext {
                                Text(FormatUtils.formatWeight(current))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            } else {
                                Text(String(current))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    
                    let useKgGram = addTitle.lowercased().contains("nguyên liệu") || addTitle.lowercased().contains("thành phẩm")
                    let isExport = addTitle.lowercased().contains("xuất")
                    let isFinishedGoodsTransactionEdit = isFinishedGoods && itemToEdit != nil && !isSimpleFinishedGoodsEdit && editTitle.lowercased().contains("sửa thành phẩm")
                    if isSimpleFinishedGoodsEdit {
                        HStack {
                            Text("Giá bán")
                            Spacer()
                            Button {
                                if let p = parseDouble(price) { unitPriceWheelSelection = Int(p) }
                                showUnitPriceWheel = true
                            } label: {
                                Text(formatCurrency(parseDouble(price) ?? Double(unitPriceWheelSelection)))
                                    .fontWeight(.semibold)
                            }
                        }
                    } else if isFinishedGoodsTransactionEdit {
                        HStack {
                            Text("Danh mục")
                            Spacer()
                            Button {
                                showCategorySheet = true
                            } label: {
                                let isMaterialsCtx = addTitle.lowercased().contains("nguyên liệu")
                                let placeholder = isMaterialsCtx ? Category.materials.rawValue : Category.others.rawValue
                                Text(selectedCategoryName.isEmpty ? placeholder : selectedCategoryName)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        HStack {
                            Text("Số lượng")
                            Spacer()
                            Button {
                                if useKgGram {
                                    let current = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                                    quantityKgSelection = max(0, current / 1000)
                                    let remainder = max(0, current % 1000)
                                    gramsWheelSelection = (remainder / 50) * 50
                                    if quantityKgSelection > quantityWheelMax {
                                        quantityWheelMax = max(quantityWheelMax, quantityKgSelection + 200)
                                    }
                                } else {
                                    if let q = Int(quantity), q > 0 { quantityWheelSelection = q }
                                }
                                showQuantityWheel = true
                            } label: {
                                let gramsVal = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                                Group {
                                    if useKgGram {
                                        Text(FormatUtils.formatKgDecimal(fromGrams: gramsVal))
                                            .fontWeight(.semibold)
                                    } else {
                                        Text(quantity.isEmpty ? String(quantityWheelSelection) : quantity)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        
                        if isExport {
                            HStack {
                                Text("Đơn giá xuất")
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
                            
                            let pVal = parseDouble(price) ?? Double(unitPriceWheelSelection)
                            let qVal = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                            let incVal = parseDouble(incurredCost) ?? Double(additionalCostWheelSelection)
                            HStack {
                                Text("Giá xuất")
                                Spacer()
                                if qVal > 0 {
                                    let total = (pVal * (Double(qVal) / 1000.0)) + incVal
                                    let unitValue = total / (Double(qVal) / 1000.0)
                                    Text(formatCurrency(unitValue))
                                        .fontWeight(.semibold)
                                } else {
                                    Text("—")
                                        .foregroundStyle(.gray)
                                }
                            }
                        } else {
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
                                .contentShape(Rectangle())
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
                                .contentShape(Rectangle())
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
                                        Button {
                                            showDocumentPreview = true
                                        } label: {
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
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                        default:
                                                            Image(systemName: "doc.text.image")
                                                                .foregroundStyle(.gray)
                                                        }
                                                    }
                                                    .frame(width: 54, height: 54)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                }
                                                
                                                Image(systemName: "magnifyingglass")
                                                    .font(.caption)
                                                    .foregroundStyle(.white)
                                                    .padding(6)
                                                    .background(Circle().fill(Color.black.opacity(0.45)))
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                                    .padding(4)
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
                    } else {
                        HStack {
                            Text("Số lượng")
                            Spacer()
                            Button {
                                if useKgGram {
                                    let current = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                                    quantityKgSelection = max(0, current / 1000)
                                    let remainder = max(0, current % 1000)
                                    gramsWheelSelection = (remainder / 50) * 50
                                    if quantityKgSelection > quantityWheelMax {
                                        quantityWheelMax = max(quantityWheelMax, quantityKgSelection + 200)
                                    }
                                } else {
                                    if let q = Int(quantity), q > 0 { quantityWheelSelection = q }
                                }
                                showQuantityWheel = true
                            } label: {
                                let gramsVal = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                                Group {
                                    if useKgGram {
                                        Text(FormatUtils.formatKgDecimal(fromGrams: gramsVal))
                                            .fontWeight(.semibold)
                                    } else {
                                        Text(quantity.isEmpty ? String(quantityWheelSelection) : quantity)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        
                        HStack {
                            Text(isExport ? "Đơn giá xuất" : "Đơn giá nhập")
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
                        
                        let pVal = parseDouble(price) ?? Double(unitPriceWheelSelection)
                        let isFGExport = isFinishedGoods && addTitle.lowercased().contains("xuất")
                        let isMatExport = (!isFinishedGoods) && addTitle.lowercased().contains("xuất")
                        let qVal = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                        let incVal = parseDouble(incurredCost) ?? Double(additionalCostWheelSelection)
                        HStack {
                            Text(isFinishedGoods ? (isFGExport ? "Giá xuất" : "Giá bán gồm chi phí") : (isMatExport ? "Giá xuất" : "Giá nhập gồm chi phí"))
                            Spacer()
                            if qVal > 0 {
                                let total = isMatExport ? (pVal * (Double(qVal) / 1000.0)) : ((pVal * (Double(qVal) / 1000.0)) + incVal)
                                let unitValue = isMatExport ? pVal : (total / (Double(qVal) / 1000.0))
                                Text(formatCurrency(unitValue))
                                    .fontWeight(.semibold)
                            } else {
                                Text("—")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    
                    if !isFinishedGoodsTransactionEdit {
                        HStack {
                            Text("Danh mục")
                            Spacer()
                            Button {
                                showCategorySheet = true
                            } label: {
                                let isMaterialsCtx = addTitle.lowercased().contains("nguyên liệu")
                                let placeholder = isMaterialsCtx ? Category.materials.rawValue : Category.others.rawValue
                                Text(selectedCategoryName.isEmpty ? placeholder : selectedCategoryName)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    if !isSimpleFinishedGoodsEdit && !isExport && !isFinishedGoodsTransactionEdit {
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
                            .contentShape(Rectangle())
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
                            .contentShape(Rectangle())
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
                                    Button {
                                        showDocumentPreview = true
                                    } label: {
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
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                    default:
                                                        Image(systemName: "doc.text.image")
                                                            .foregroundStyle(.gray)
                                                    }
                                                }
                                                .frame(width: 54, height: 54)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            
                                            Image(systemName: "magnifyingglass")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(Circle().fill(Color.black.opacity(0.45)))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                                .padding(4)
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
                    
                    if !isSimpleFinishedGoodsEdit, let p = parseDouble(price) {
                        let isFGExport = isFinishedGoods && addTitle.lowercased().contains("xuất")
                        let isMatExport = (!isFinishedGoods) && addTitle.lowercased().contains("xuất")
                        let q = FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection
                        if q > 0 {
                            let extra = parseDouble(incurredCost) ?? 0
                            let total = if isMatExport { p * (Double(q) / 1000.0) } else { (p * (Double(q) / 1000.0)) + extra }
                            let unitValue = isMatExport ? p : (total / (Double(q) / 1000.0))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(isFinishedGoods ? (isFGExport ? "Tổng xuất thành phẩm:" : "Tổng nhập thành phẩm:") : (isMatExport ? "Tổng xuất nguyên liệu:" : "Tổng chi phí:"))
                                    Spacer()
                                    Text(formatCurrency(total))
                                        .fontWeight(.bold)
                                }
                                
                                HStack {
                                    Text(isFinishedGoods ? (isFGExport ? "Giá xuất:" : "Giá bán (bao gồm chi phí):") : (isMatExport ? "Đơn giá xuất:" : "Đơn giá nhập (bao gồm chi phí):"))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Text(formatCurrency(unitValue))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    
                }
            }
            .navigationTitle(itemToEdit == nil ? addTitle : editTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(itemToEdit == nil ? "Thêm" : "Lưu") {
                        if isSimpleFinishedGoodsEdit {
                            let priceValue = parseDouble(price) ?? Double(unitPriceWheelSelection)
                            if let p = prefilledProduct ?? viewModel.products.first(where: { $0.name.lowercased() == name.lowercased() }) {
                                viewModel.updateProduct(
                                    p,
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    price: priceValue,
                                    costPrice: p.costPrice,
                                    category: Category(rawValue: selectedCategoryName) ?? .others,
                                    imageName: p.imageName,
                                    color: p.color,
                                    quantity: viewModel.stockLevel(for: p.name),
                                    imageData: p.imageData,
                                    barcode: p.barcode,
                                    imageURL: p.imageURL
                                )
                            }
                            dismiss()
                            return
                        }
                        let p = parseDouble(price) ?? Double(unitPriceWheelSelection)
                        let useKgGram = addTitle.lowercased().contains("nguyên liệu") || addTitle.lowercased().contains("thành phẩm")
                        let q = useKgGram ? (FormatUtils.parseKgDecimalToGrams(quantity) ?? quantityWheelSelection) : (Int(quantity) ?? quantityWheelSelection)
                        guard !name.isEmpty, q > 0 else { return }
                        let extra = parseDouble(incurredCost) ?? 0
                        let suggested: Double? = (!isFinishedGoods ? Double(suggestedPriceWheelSelection) : nil)
                        
                        if var item = itemToEdit {
                            item.name = name
                            item.quantity = q
                            item.unitPrice = p
                            item.additionalCost = extra
                            item.suggestedPrice = suggested
                            item.category = selectedCategoryName
                            let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                            item.source = src.isEmpty ? nil : src
                            item.documentImageURL = documentImageURL
                            item.isConfirmed = true
                            viewModel.updateRestockItem(item)
                        } else {
                            let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.addRestockItem(
                                name,
                                unitPrice: p,
                                quantity: q,
                                additionalCost: extra,
                                suggestedPrice: suggested,
                                category: selectedCategoryName,
                                source: src.isEmpty ? nil : src,
                                documentImageURL: documentImageURL
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.height(550)])
        .onAppear {
            if let item = itemToEdit {
                name = item.name
                sourceText = item.source ?? ""
                documentImageURL = item.documentImageURL
                let useKgGram = addTitle.lowercased().contains("nguyên liệu") || addTitle.lowercased().contains("thành phẩm")
                if useKgGram {
                    quantity = FormatUtils.formatKgDecimal(fromGrams: item.quantity)
                } else {
                    quantity = String(item.quantity)
                }
                price = String(format: "%.0f", item.unitPrice)
                incurredCost = String(format: "%.0f", item.additionalCost)
                quantityWheelSelection = item.quantity
                unitPriceWheelSelection = Int(item.unitPrice)
                additionalCostWheelSelection = Int(item.additionalCost)
                if let cat = item.category, !cat.isEmpty {
                    selectedCategoryName = cat
                }
                if !isFinishedGoods {
                    if let sp = item.suggestedPrice {
                        suggestedPriceWheelSelection = Int(sp)
                    } else {
                        suggestedPriceWheelSelection = max(Int(item.unitPrice * 1.3), Int(item.unitPrice))
                    }
                }
                // no selling price wheel
            } else if let product = prefilledProduct {
                name = product.name
                // Use last known cost price as default import price
                // If costPrice is 0, use 70% of selling price as a heuristic guess
                let defaultCost = product.costPrice > 0 ? product.costPrice : product.price * 0.7
                price = String(format: "%.0f", defaultCost)
                
                unitPriceWheelSelection = Int(defaultCost)
                if !isFinishedGoods {
                    suggestedPriceWheelSelection = Int(product.price)
                }
            }
            
            if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let latest = viewModel.latestSource(for: name) {
                    sourceText = latest
                }
            }
        }
        .sheet(isPresented: $showNamePicker) {
            NavigationStack {
                let isMaterialsCtx = addTitle.lowercased().contains("nguyên liệu")
                let items: [String] = {
                    if isMaterialsCtx {
                        return viewModel.materials.map { $0.name }
                    }
                    return viewModel.products.map { $0.name }
                }()
                
                List {
                    ForEach(items.filter {
                        let t = nameSearch.trimmingCharacters(in: .whitespacesAndNewlines)
                        if t.isEmpty { return true }
                        return $0.lowercased().contains(t.lowercased())
                    }, id: \.self) { n in
                        Button {
                            name = n
                            if isMaterialsCtx {
                                selectedCategoryName = Category.materials.rawValue
                                if let mat = viewModel.materials.first(where: { $0.name == n }) {
                                    let v = Int(mat.lastUnitPrice)
                                    unitPriceWheelSelection = v
                                    price = String(v)
                                }
                            } else {
                                if let p = viewModel.products.first(where: { $0.name == n }) {
                                    selectedCategoryName = p.category
                                    let defaultCost = p.costPrice > 0 ? p.costPrice : p.price * 0.7
                                    unitPriceWheelSelection = Int(defaultCost)
                                    price = String(Int(defaultCost))
                                }
                            }
                            if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if let latest = viewModel.latestSource(for: n) {
                                    sourceText = latest
                                }
                            }
                            showNamePicker = false
                        } label: {
                            Text(n)
                        }
                    }
                }
                .searchable(text: $nameSearch)
                .navigationTitle(isMaterialsCtx ? "Chọn nguyên liệu" : "Chọn hàng hóa")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { showNamePicker = false }
                    }
                }
            }
        }
        .confirmationDialog("Chọn nguồn nhập", isPresented: $showSourceHistoryPicker, titleVisibility: .visible) {
            ForEach(sourceHistoryOptions, id: \.self) { src in
                Button(src) { sourceText = src }
            }
        }
        .sheet(isPresented: $showDocumentPicker, onDismiss: {
            uploadSelectedDocumentImage()
        }) {
            ImagePicker(image: $documentImage, sourceType: documentPickerSource)
        }
        .fullScreenCover(isPresented: $showCameraPicker, onDismiss: {
            uploadSelectedDocumentImage()
        }) {
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
                        ZoomableView {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    } else if let urlString = documentImageURL, let url = URL(string: urlString) {
                        ZoomableView {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .tint(.white)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                default:
                                    Text("Không tải được ảnh")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    } else {
                        Text("Không có chứng từ")
                            .foregroundStyle(.white)
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
                            let isMaterialsCtx = addTitle.lowercased().contains("nguyên liệu")
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
                                    let isMaterialsCtx = addTitle.lowercased().contains("nguyên liệu")
                                    if isMaterialsCtx { viewModel.addMaterialCategory(trimmed) }
                                    else { viewModel.addProductCategory(trimmed) }
                                    newCategoryName = ""
                                    showCategorySheet = false
                                }
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .navigationTitle(addTitle.lowercased().contains("nguyên liệu") ? "Danh mục nguyên liệu" : "Danh mục hàng hóa")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCategorySheet = false }
                        }
                    }
                }
                .presentationDetents([.height(420)])
            }
        .sheet(isPresented: $showQuantityWheel) {
            let useKgGram = addTitle.lowercased().contains("nguyên liệu") || addTitle.lowercased().contains("thành phẩm")
            VStack(spacing: 12) {
                Text("Sửa số lượng")
                    .font(.headline)
                if useKgGram {
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
                    }
                    HStack {
                        VStack {
                            Text("Kg")
                                .font(.caption)
                                .foregroundStyle(.gray)
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
                            Text("Gam")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Picker("", selection: $gramsWheelSelection) {
                                ForEach(Array(stride(from: 0, through: gramsWheelMax, by: 50)), id: \.self) { g in
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
                }
                HStack {
                    Button("Đóng") { showQuantityWheel = false }
                    Spacer()
                    Button("Lưu") {
                        if useKgGram {
                            let total = quantityKgSelection * 1000 + gramsWheelSelection
                            quantityWheelSelection = total
                            quantity = FormatUtils.formatKgDecimal(fromGrams: total)
                        } else {
                            quantity = String(quantityWheelSelection)
                        }
                        showQuantityWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(340)])
            .onAppear {
                if useKgGram {
                    quantityKgRangeBase = (quantityKgSelection / 100) * 100
                }
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showQuantityKgRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: quantityWheelMax, by: 100)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v)") {
                        quantityKgRangeBase = v
                        if quantityKgSelection < v { quantityKgSelection = v }
                        showQuantityKgRangePicker = false
                    }
                }
            }
        }
        .sheet(isPresented: $showUnitPriceWheel) {
            VStack(spacing: 12) {
                Text("Sửa đơn giá")
                    .font(.headline)
                let step = StoreManager.shared.priceStep
                let rangeMin = max(0, (unitPriceWheelRangeBase / step) * step)
                HStack {
                    Button {
                        showUnitPriceWheelRangePicker = true
                    } label: {
                        Text(unitPriceWheelRangeBase <= 0 ? ">0" : ">\(unitPriceWheelRangeBase / 1000)k")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $unitPriceBaseSelection) {
                            ForEach(Array(stride(from: rangeMin, through: unitPriceWheelMax, by: step)), id: \.self) { v in
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
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
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
                        price = String(unitPriceWheelSelection)
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
                unitPriceWheelRangeBase = (current / 100000) * 100000
                unitPriceBaseSelection = (current / step) * step
                let remainder = max(0, current - unitPriceBaseSelection)
                unitPriceHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showUnitPriceWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(unitPriceWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        unitPriceWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if unitPriceBaseSelection < rangeMin { unitPriceBaseSelection = rangeMin }
                        showUnitPriceWheelRangePicker = false
                    }
                }
            }
        }
        .sheet(isPresented: $showAdditionalCostWheel) {
            VStack(spacing: 12) {
                Text("Sửa chi phí")
                    .font(.headline)
                let step = StoreManager.shared.priceStep
                let rangeMin = max(0, (additionalCostWheelRangeBase / step) * step)
                HStack {
                    Button {
                        showAdditionalCostWheelRangePicker = true
                    } label: {
                        Text(additionalCostWheelRangeBase <= 0 ? ">0" : ">\(additionalCostWheelRangeBase / 1000)k")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $additionalCostBaseSelection) {
                            ForEach(Array(stride(from: rangeMin, through: additionalCostWheelMax, by: step)), id: \.self) { v in
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
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
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
                        incurredCost = String(additionalCostWheelSelection)
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
                additionalCostWheelRangeBase = (current / 100000) * 100000
                additionalCostBaseSelection = (current / step) * step
                let remainder = max(0, current - additionalCostBaseSelection)
                additionalCostHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showAdditionalCostWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(additionalCostWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        additionalCostWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if additionalCostBaseSelection < rangeMin { additionalCostBaseSelection = rangeMin }
                        showAdditionalCostWheelRangePicker = false
                    }
                }
            }
        }
        .sheet(isPresented: $showSuggestedPriceWheel) {
            VStack(spacing: 12) {
                Text("Sửa giá bán dự kiến")
                    .font(.headline)
                let step = StoreManager.shared.priceStep
                let rangeMin = max(0, (suggestedPriceWheelRangeBase / step) * step)
                HStack {
                    Button {
                        showSuggestedPriceWheelRangePicker = true
                    } label: {
                        Text(suggestedPriceWheelRangeBase <= 0 ? ">0" : ">\(suggestedPriceWheelRangeBase / 1000)k")
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                HStack {
                    VStack {
                        Text("Giá")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $suggestedPriceBaseSelection) {
                            ForEach(Array(stride(from: rangeMin, through: suggestedPriceWheelMax, by: step)), id: \.self) { v in
                                Text(formatCurrency(Double(v))).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: suggestedPriceBaseSelection) { _, newValue in
                            suggestedPriceWheelSelection = newValue + suggestedPriceHundredsSelection
                            if newValue > suggestedPriceWheelMax - (step * 5) {
                                suggestedPriceWheelMax += step * 100
                            }
                        }
                    }
                    VStack {
                        Text("Trăm")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Picker("", selection: $suggestedPriceHundredsSelection) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: suggestedPriceHundredsSelection) { _, newValue in
                            suggestedPriceWheelSelection = suggestedPriceBaseSelection + newValue
                        }
                    }
                    .frame(width: 110)
                }
                HStack {
                    Button("Đóng") { showSuggestedPriceWheel = false }
                    Spacer()
                    Button("Lưu") {
                        showSuggestedPriceWheel = false
                    }
                }
                .font(.headline)
            }
            .padding()
            .presentationDetents([.height(300)])
            .onAppear {
                let step = StoreManager.shared.priceStep
                let current = max(0, suggestedPriceWheelSelection)
                suggestedPriceWheelRangeBase = (current / 100000) * 100000
                suggestedPriceBaseSelection = (current / step) * step
                let remainder = max(0, current - suggestedPriceBaseSelection)
                suggestedPriceHundredsSelection = min(900, (remainder / 100) * 100)
            }
            .confirmationDialog("Chọn vùng giá trị", isPresented: $showSuggestedPriceWheelRangePicker, titleVisibility: .visible) {
                ForEach(Array(stride(from: 0, through: min(suggestedPriceWheelMax, 10_000_000), by: 100_000)), id: \.self) { v in
                    Button(v == 0 ? ">0" : ">\(v / 1000)k") {
                        suggestedPriceWheelRangeBase = v
                        let step = StoreManager.shared.priceStep
                        let rangeMin = max(0, (v / step) * step)
                        if suggestedPriceBaseSelection < rangeMin { suggestedPriceBaseSelection = rangeMin }
                        showSuggestedPriceWheelRangePicker = false
                    }
                }
            }
        }
    }
    
    func uploadSelectedDocumentImage() {
        guard let img = documentImage else { return }
        guard let data = img.jpegData(compressionQuality: 0.85) else { return }
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let fileName = (itemToEdit?.id ?? UUID()).uuidString
        
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
    
    
    func parseDouble(_ input: String) -> Double? {
        // Handle "2,000" or "20,000" (Thousands separator)
        // If input contains comma, remove it assuming it's a thousands separator for VND
        // e.g. "2,000" -> "2000"
        let clean = input.replacingOccurrences(of: ",", with: "")
        
        return Double(clean)
    }
    
 
}

private struct ZoomableView<Content: View>: View {
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
