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
    @State private var showAutoMaterialExport = false
    @State private var autoExportPulse = false
    @State private var showAutoExportDetail = false
    @State private var selectedAutoExportLog: AutoMaterialExportLog?
    
    enum Mode: String, CaseIterable {
        case nhapNguyenLieu = "Nhập Nguyên liệu"
        case xuatNguyenLieu = "Xuất Nguyên liệu"
        case nhapThanhPham = "Nhập Thành Phẩm"
        case xuatThanhPham = "Xuất Thành Phẩm"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Compact Two-Row Mode Selector
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Button(action: { selectedMode = m }) {
                            HStack(spacing: 8) {
                                Image(systemName: icon(for: m))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(m.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMode == m ? color(for: m) : Color.white)
                            .foregroundStyle(selectedMode == m ? .white : color(for: m))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(color(for: m).opacity(0.2), lineWidth: selectedMode == m ? 0 : 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)
                
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
                                                        ProductionProductListRow(
                                                            name: p.name,
                                                            priceText: formatCurrency(p.price),
                                                            stockText: FormatUtils.formatWeight(p.stockQuantity)
                                                        )
                                                    }
                                                    Divider().padding(.leading, 0)
                                                }
                                            }
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
                                            ProductionTransactionHistoryCard(
                                                tx: tx,
                                                selectedMode: selectedMode,
                                                editedIds: viewModel.editedProductionTxIds,
                                                onShowEditHistory: {
                                                    Task {
                                                        self.editHistoryEntries = await viewModel.fetchProductionEdits(for: tx.id)
                                                        self.showEditHistory = true
                                                    }
                                                },
                                                onShowAutoExportDetail: {
                                                    Task {
                                                        let logs = await viewModel.fetchAutoMaterialExportLogsForTransaction(transactionId: tx.id)
                                                        await MainActor.run {
                                                            self.selectedAutoExportLog = logs.first
                                                            self.showAutoExportDetail = (self.selectedAutoExportLog != nil)
                                                        }
                                                    }
                                                },
                                                onEdit: {
                                                    editingTransaction = tx
                                                    showTransactionEdit = true
                                                }
                                            )
                                        }
                                    }
                                    .padding(.top, 8)
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
                // Ensure a mode is selected by default if none is
                if selectedMode == nil {
                    selectedMode = .nhapNguyenLieu
                }
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
                    // Trong nhập / xuất nguyên liệu: không cho chỉnh Giá nhập + Tồn kho
                    MaterialEditView(viewModel: viewModel, mode: .edit(m), allowEditPriceAndStock: false)
                }
            }
            .sheet(isPresented: $showTransactionEdit) {
                if let tx = editingTransaction {
                    TransactionEditView(viewModel: viewModel, original: tx)
                }
            }
            .sheet(isPresented: $showAutoMaterialExport) {
                AutoMaterialExportSheetView(viewModel: viewModel, defaultHeaderName: "Xuất tự động")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showEditHistory) {
                EditHistorySheet(entries: editHistoryEntries)
            }
            .sheet(isPresented: $showAutoExportDetail) {
                if let log = selectedAutoExportLog {
                    AutoMaterialExportLogDetailSheet(log: log)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showProductEdit) {
                if let p = editingProduct {
                    ProductEditView(viewModel: viewModel, mode: .edit(p))
                }
            }
            .sheet(item: $editingFinishedProduct) { product in
                ProductEditView(viewModel: viewModel, mode: .edit(product))
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
            .overlay(alignment: .bottomTrailing) {
                if selectedMode == .xuatNguyenLieu {
                    Button {
                        showAutoMaterialExport = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Xuất tự động")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(autoExportPulse ? 0.95 : 0.55),
                                                Color.purple.opacity(autoExportPulse ? 0.95 : 0.55)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 54, height: 54)
                                    .shadow(color: Color.blue.opacity(autoExportPulse ? 0.6 : 0.2), radius: autoExportPulse ? 14 : 5, x: 0, y: autoExportPulse ? 8 : 2)
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(autoExportPulse ? 1.08 : 0.92)
                            .opacity(autoExportPulse ? 1 : 0.75)
                        }
                        .padding(.horizontal, 8)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 92)
                    .onAppear {
                        autoExportPulse = false
                        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                            autoExportPulse = true
                        }
                    }
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

private struct ProductionProductListRow: View {
    let name: String
    let priceText: String
    let stockText: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.themeTextDark)
                .lineLimit(2)
            Spacer()
            Text(priceText)
                .font(.subheadline)
                .foregroundStyle(Color.themePrimary)
                .frame(width: 120, alignment: .trailing)
            Text(stockText)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.white)
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

private struct ProductionTransactionHistoryCard: View {
    let tx: ProductionTransaction
    let selectedMode: ProductionManagementView.Mode?
    let editedIds: Set<UUID>
    let onShowEditHistory: () -> Void
    let onShowAutoExportDetail: () -> Void
    let onEdit: () -> Void
    
    private var isExportMode: Bool {
        guard let m = selectedMode else { return false }
        return m == .xuatThanhPham || m == .xuatNguyenLieu
    }
    
    private var showEditedBadge: Bool {
        editedIds.contains(tx.id)
    }
    
    private var showAutoExportButton: Bool {
        let note = tx.note?.lowercased() ?? ""
        return note.contains("xuất tự động")
    }
    
    private var isExportToInventory: Bool {
        let note = tx.note?.lowercased() ?? ""
        return note.contains("xuất sang kho hàng hoá") || note.contains("tự động xuất kho từ phiếu nhập")
    }
    
    var body: some View {
        let dateText = formatTxDate(tx.createdAt)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                
                if let stt = tx.sequenceNumber {
                    Text("• \(stt)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
                
                if let name = tx.creatorName, !name.isEmpty {
                    Text("• \(name)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                if showEditedBadge {
                    Text("Đã chỉnh sửa")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange))
                }
                if showAutoExportButton {
                    Button(action: onShowAutoExportDetail) {
                        Text("Chi tiết tự động")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
                Spacer()
                Button(action: onShowEditHistory) {
                    Text("Lịch sử chỉnh sửa")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
            }
            
            VStack(spacing: 6) {
                ForEach(tx.items, id: \.id) { it in
                    ProductionTransactionItemRow(item: it, isExportMode: isExportMode)
                }
            }
            
            HStack {
                // Label bên trái button Sửa
                if isExportToInventory {
                    Text("xuất sang kho hàng hoá")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.purple.opacity(0.85)))
                }
                Spacer()
                Button(action: onEdit) {
                    Text("Sửa")
                        .font(.subheadline)
                        .fontWeight(.bold)
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
    
    private func formatTxDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}

private struct ProductionTransactionItemRow: View {
    let item: RestockItem
    let isExportMode: Bool
    
    var body: some View {
        let qtyText = FormatUtils.formatWeight(item.quantity)
        let priceTitle = isExportMode ? "Giá xuất" : "Giá nhập"
        let priceText = formatCurrency(item.unitPrice)
        let costText = formatCurrency(item.additionalCost)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
                Text("SL: \(qtyText)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            HStack {
                Text("\(priceTitle): \(priceText)")
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                Spacer()
                Text("Chi phí: \(costText)")
                    .font(.caption)
                    .foregroundStyle(.gray)
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
