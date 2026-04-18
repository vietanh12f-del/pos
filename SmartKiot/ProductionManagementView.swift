import SwiftUI

struct ProductionManagementView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMode: Mode? = .nhapNguyenLieu
    @State private var showMaterialEntry = false
    @State private var materialTab: Int = 0
    @State private var searchText: String = ""
    @State private var editingMaterial: MaterialItem?
    @State private var showMaterialEdit = false
    @State private var editingTransaction: ProductionTransaction?
    @State private var showTransactionEdit = false
    @State private var showEditHistory = false
    @State private var editHistoryEntries: [ProductionEdit] = []
    @State private var editingProduct: Product?
    @State private var editingFinishedProduct: Product?
    @State private var showProductEdit = false
    
    enum Mode: String, CaseIterable {
        case nhapNguyenLieu = "Nhập Nguyên liệu"
        case xuatNguyenLieu = "Xuất Nguyên liệu"
        case nhapThanhPham = "Nhập Thành Phẩm"
        case xuatThanhPham = "Xuất Thành Phẩm"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Tiles
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        ProductionModeTile(
                            icon: icon(for: m),
                            title: m.rawValue,
                            color: color(for: m),
                            selected: selectedMode == m,
                            action: { selectedMode = m }
                        )
                    }
                }
                .padding(.horizontal)
                
                if let mode = selectedMode {
                    VStack(spacing: 12) {
                        Picker("Chế độ", selection: $materialTab) {
                            Text(leftTitle(for: mode)).tag(0)
                            Text(rightTitle(for: mode)).tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .tint(color(for: mode))
                        .padding(.horizontal)
                        
                        if materialTab == 0 {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                                TextField((mode == .nhapThanhPham || mode == .xuatThanhPham) ? "Tìm thành phẩm có sẵn..." : "Tìm nguyên liệu có sẵn...", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                if !searchText.isEmpty {
                                    Button { searchText = "" } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            if mode == .nhapThanhPham || mode == .xuatThanhPham {
                                let filtered = viewModel.finishedGoods.filter { p in
                                    if searchText.isEmpty { return true }
                                    let q = searchText.lowercased()
                                    return p.name.lowercased().contains(q) || p.category.lowercased().contains(q)
                                }
                                if filtered.isEmpty {
                                    Spacer(minLength: 0).frame(height: 0)
                                } else {
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Thành phẩm").font(.caption).foregroundStyle(.gray)
                                            Spacer()
                                            Text("Giá bán").font(.caption).foregroundStyle(.gray)
                                                .frame(width: 120, alignment: .trailing)
                                            Text("Kho").font(.caption).foregroundStyle(.gray)
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        
                                        Divider()
                                        
                                        ScrollView {
                                            LazyVStack(spacing: 0) {
                                                ForEach(filtered) { p in
                                                    Button {
                                                        if selectedMode == .xuatThanhPham || selectedMode == .nhapThanhPham {
                                                            editingFinishedProduct = p
                                                        } else {
                                                            editingProduct = p
                                                            showProductEdit = true
                                                        }
                                                    } label: {
                                                        HStack {
                                                            Text(p.name)
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.themeTextDark)
                                                                .lineLimit(2)
                                                            Spacer()
                                                            Text(formatCurrency(p.price))
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.themePrimary)
                                                                .frame(width: 120, alignment: .trailing)
                                                            Text(FormatUtils.formatWeight(p.stockQuantity))
                                                                .font(.subheadline)
                                                                .foregroundStyle(.gray)
                                                                .frame(width: 60, alignment: .trailing)
                                                        }
                                                        .padding(.horizontal)
                                                        .padding(.vertical, 10)
                                                        .background(Color.white)
                                                    }
                                                    Divider().padding(.leading, 0)
                                                }
                                            }
                                            .padding(.bottom, 120)
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            } else {
                                if viewModel.materials.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "shippingbox")
                                            .font(.system(size: 60))
                                            .foregroundStyle(Color.gray.opacity(0.3))
                                        Text("Chưa có dữ liệu")
                                            .font(.headline)
                                            .foregroundStyle(.gray)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 220)
                                } else {
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Nguyên liệu").font(.caption).foregroundStyle(.gray)
                                            Spacer()
                                            Text("Giá nhập").font(.caption).foregroundStyle(.gray)
                                                .frame(width: 120, alignment: .trailing)
                                            Text("Kho").font(.caption).foregroundStyle(.gray)
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        
                                        Divider()
                                        
                                        ScrollView {
                                            LazyVStack(spacing: 0) {
                                                ForEach(viewModel.materials.filter { item in
                                                    if searchText.isEmpty { return true }
                                                    let q = searchText.lowercased()
                                                    return item.name.lowercased().contains(q)
                                                }) { item in
                                                    Button {
                                                        editingMaterial = item
                                                        showMaterialEdit = true
                                                    } label: {
                                                        HStack {
                                                            Text(item.name)
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.themeTextDark)
                                                                .lineLimit(2)
                                                            Spacer()
                                                            Text(formatCurrency(item.lastUnitPrice))
                                                                .font(.subheadline)
                                                                .foregroundStyle(Color.themePrimary)
                                                                .frame(width: 120, alignment: .trailing)
                                                            Text(FormatUtils.formatWeight(item.stockQuantity))
                                                                .font(.subheadline)
                                                                .foregroundStyle(.gray)
                                                                .frame(width: 60, alignment: .trailing)
                                                        }
                                                        .padding(.horizontal)
                                                        .padding(.vertical, 10)
                                                        .background(Color.white)
                                                    }
                                                    Divider().padding(.leading, 0)
                                                }
                                            }
                                            .padding(.bottom, 120)
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                        } else {
                            if viewModel.productionHistory.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 60))
                                        .foregroundStyle(Color.gray.opacity(0.3))
                                    Text("Chưa có lịch sử")
                                        .font(.headline)
                                        .foregroundStyle(.gray)
                                }
                                .frame(maxWidth: .infinity, minHeight: 220)
                            } else {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.productionHistory, id: \.id) { tx in
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text(tx.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.themeTextDark)
                                                    Spacer()
                                                    // Hidden total price for all modes per request
                                                }
                                                HStack(spacing: 8) {
                                                    if viewModel.editedProductionTxIds.contains(tx.id) || (tx.note?.isEmpty == false) {
                                                        Text("Đã chỉnh sửa")
                                                            .font(.caption).fontWeight(.semibold)
                                                            .foregroundStyle(.white)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Capsule().fill(Color.orange))
                                                    }
                                                    Spacer()
                                                    Button {
                                                        Task {
                                                            self.editHistoryEntries = await viewModel.fetchProductionEdits(for: tx.id)
                                                            self.showEditHistory = true
                                                        }
                                                    } label: {
                                                        Text("Lịch sử chỉnh sửa")
                                                            .font(.caption).fontWeight(.bold)
                                                            .foregroundStyle(Color.themePrimary)
                                                    }
                                                }
                                                VStack(spacing: 6) {
                                                    ForEach(tx.items, id: \.id) { it in
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            HStack {
                                                                Text(it.name)
                                                                    .font(.subheadline)
                                                                    .foregroundStyle(Color.themeTextDark)
                                                                Spacer()
                                                                Text("SL: \(FormatUtils.formatWeight(it.quantity))")
                                                                    .font(.caption)
                                                                    .foregroundStyle(.gray)
                                                            }
                                                            HStack {
                                                            let isExportMode = (selectedMode == .xuatThanhPham || selectedMode == .xuatNguyenLieu)
                                                            Text("\(isExportMode ? "Giá xuất" : "Giá nhập"): \(formatCurrency(it.unitPrice))")
                                                                    .font(.caption)
                                                                    .foregroundStyle(Color.themePrimary)
                                                                Spacer()
                                                                Text("Chi phí: \(formatCurrency(it.additionalCost))")
                                                                    .font(.caption)
                                                                    .foregroundStyle(.gray)
                                                            }
                                                        }
                                                    }
                                                }
                                                HStack {
                                                    Spacer()
                                                    Button {
                                                        editingTransaction = tx
                                                        showTransactionEdit = true
                                                    } label: {
                                                        Text("Sửa")
                                                            .font(.subheadline).fontWeight(.bold)
                                                            .foregroundStyle(.white)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(Capsule().fill(Color.themePrimary))
                                                    }
                                                }
                                            }
                                            .padding(12)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.bottom, 120)
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
            }
            .navigationTitle("Quản Lý Sản Xuất")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .sheet(isPresented: $showMaterialEntry) {
                let mode = selectedMode ?? .nhapNguyenLieu
                RestockEntryView(
                    viewModel: viewModel,
                    titleText: centerButtonTitle(for: mode),
                    summaryTitle: summaryTitle(for: mode),
                    useInventoryList: true,
                    useMaterialsList: (mode == .nhapNguyenLieu || mode == .xuatNguyenLieu),
                    onComplete: { items in
                        viewModel.completeProductionTransaction(mode: mode.rawValue)
                        Task { 
                            if mode == .nhapThanhPham || mode == .xuatThanhPham {
                                await viewModel.loadProducts()
                            } else {
                                await viewModel.loadMaterials()
                            }
                        }
                        materialTab = 0
                    }
                )
            }
            .onAppear {
                Task { 
                    await viewModel.loadMaterials()
                    await viewModel.loadProducts()
                    if let m = selectedMode { await viewModel.loadProductionHistory(mode: m.rawValue) }
                }
            }
            .onChange(of: materialTab) { _, newVal in
                if newVal == 1, let m = selectedMode {
                    Task { await viewModel.loadProductionHistory(mode: m.rawValue) }
                }
            }
            .onChange(of: selectedMode) { _, m in
                Task {
                    if materialTab == 1, let md = m {
                        await viewModel.loadProductionHistory(mode: md.rawValue)
                    }
                    if let md = m, (md == .nhapThanhPham || md == .xuatThanhPham) {
                        await viewModel.loadProducts()
                    }
                }
            }
            .sheet(isPresented: $showMaterialEdit) {
                if let m = editingMaterial {
                    MaterialEditView(viewModel: viewModel, mode: .edit(m))
                }
            }
            .sheet(isPresented: $showTransactionEdit) {
                if let tx = editingTransaction {
                    TransactionEditView(viewModel: viewModel, original: tx)
                }
            }
            .sheet(isPresented: $showEditHistory) {
                EditHistorySheet(entries: editHistoryEntries)
            }
            .sheet(isPresented: $showProductEdit) {
                if let p = editingProduct {
                    ProductEditView(viewModel: viewModel, mode: .edit(p))
                }
            }
            .sheet(item: $editingFinishedProduct) { product in
                let isExportMode = (selectedMode == .xuatThanhPham)
                let defaultUnitPrice = isExportMode
                    ? product.price
                    : (product.costPrice > 0 ? product.costPrice : product.price)
                let item = RestockItem(
                    name: product.name,
                    quantity: 1000,
                    unitPrice: defaultUnitPrice,
                    additionalCost: 0,
                    suggestedPrice: nil,
                    isConfirmed: false,
                    category: product.category
                )
                ManualRestockItemView(
                    viewModel: viewModel,
                    itemToEdit: item,
                    isFinishedGoods: true,
                    addTitle: isExportMode ? "Thêm thành phẩm xuất" : "Thêm thành phẩm nhập",
                    editTitle: "Sửa thành phẩm"
                )
            }
            .safeAreaInset(edge: .bottom) {
                if let mode = selectedMode {
                    Button {
                        showMaterialEntry = true
                    } label: {
                        Text(centerButtonTitle(for: mode))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [color(for: mode), color(for: mode).opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    func icon(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "tray.and.arrow.down.fill"
        case .xuatNguyenLieu: return "tray.and.arrow.up.fill"
        case .nhapThanhPham: return "tray.and.arrow.down.fill"
        case .xuatThanhPham: return "tray.and.arrow.up.fill"
        }
    }
    
    func color(for mode: Mode) -> Color {
        switch mode {
        case .nhapNguyenLieu: return .green
        case .xuatNguyenLieu: return .orange
        case .nhapThanhPham: return .blue
        case .xuatThanhPham: return .purple
        }
    }
    func leftTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Nguyên liệu"
        case .xuatNguyenLieu: return "Nguyên liệu"
        case .nhapThanhPham: return "Thành phẩm"
        case .xuatThanhPham: return "Thành phẩm"
        }
    }
    func rightTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Lịch sử nhập"
        case .xuatNguyenLieu: return "Lịch sử xuất"
        case .nhapThanhPham: return "Lịch sử nhập"
        case .xuatThanhPham: return "Lịch sử xuất"
        }
    }
    func centerButtonTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Nhập nguyên liệu"
        case .xuatNguyenLieu: return "Xuất nguyên liệu"
        case .nhapThanhPham: return "Nhập thành phẩm"
        case .xuatThanhPham: return "Xuất thành phẩm"
        }
    }
    func summaryTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Tóm tắt nhập nguyên liệu"
        case .xuatNguyenLieu: return "Tóm tắt xuất nguyên liệu"
        case .nhapThanhPham: return "Tóm tắt nhập thành phẩm"
        case .xuatThanhPham: return "Tóm tắt xuất thành phẩm"
        }
    }
}

 
struct EditHistorySheet: View {
    let entries: [ProductionEdit]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries, id: \.id) { e in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(e.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Spacer()
                        }
                        if let note = e.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(Color.themeTextDark)
                        }
                        if let details = e.details, !details.isEmpty {
                            ForEach(details, id: \.self) { line in
                                Text("• \(line)").font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Lịch sử chỉnh sửa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct ProductionModeTile: View {
    let icon: String
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(selected ? color : color.opacity(0.12))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(selected ? color : color.opacity(0.35), lineWidth: selected ? 0 : 1.5)
                        )
                    Image(systemName: icon)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? Color.white : color)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(.vertical, 12)
            .background(selected ? color.opacity(0.12) : Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? color : Color.gray.opacity(0.15), lineWidth: selected ? 2 : 1)
            )
        }
    }
}
