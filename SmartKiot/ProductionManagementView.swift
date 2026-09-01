import SwiftUI

struct ProductionManagementView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMode: Mode? = .nhapNguyenLieu
    @State private var showMaterialEntry = false
    @State private var materialTab: Int = 0
    @State private var searchText: String = ""
    @State private var historySearchText: String = ""
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
    @State private var printingTransaction: ProductionTransaction?
    @State private var showPrintSheet = false
    @State private var showExportWarehousePrintSheet = false
    @State private var highlightedTxId: UUID? = nil
    @State private var showPrintOptions = false
    @State private var printImage: UIImage?
    @State private var showPrintShareSheet = false
    
    enum Mode: String, CaseIterable {
        case nhapNguyenLieu = "Nhập Nguyên liệu"
        case xuatNguyenLieu = "Xuất Nguyên liệu"
        case nhapThanhPham = "Nhập Thành Phẩm"
        case xuatThanhPham = "Xuất Thành Phẩm"
    }
    
    // Nguyên liệu: ưu tiên theo lịch sử nhập/xuất gần nhất
    private var sortedMaterials: [MaterialItem] {
        var recentOrder: [String: Int] = [:]
        let sorted = viewModel.productionHistory.sorted { $0.createdAt > $1.createdAt }
        var rank = 0
        for tx in sorted {
            for item in tx.items {
                let key = item.name.lowercased()
                if recentOrder[key] == nil {
                    recentOrder[key] = rank
                    rank += 1
                }
            }
        }
        let base = viewModel.materials.filter { m in
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return m.name.lowercased().contains(q)
        }
        return base.sorted { a, b in
            let ra = recentOrder[a.name.lowercased()] ?? Int.max
            let rb = recentOrder[b.name.lowercased()] ?? Int.max
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }
    
    // Thành phẩm: ưu tiên theo lịch sử nhập/xuất thành phẩm gần nhất
    private var sortedFinishedGoods: [Product] {
        var recentOrder: [String: Int] = [:]
        let sorted = viewModel.productionHistory.sorted { $0.createdAt > $1.createdAt }
        var rank = 0
        for tx in sorted {
            for item in tx.items {
                let key = item.name.lowercased()
                if recentOrder[key] == nil {
                    recentOrder[key] = rank
                    rank += 1
                }
            }
        }
        let base = viewModel.finishedGoods.filter { p in
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return p.name.lowercased().contains(q) || p.category.lowercased().contains(q)
        }
        return base.sorted { a, b in
            let ra = recentOrder[a.name.lowercased()] ?? Int.max
            let rb = recentOrder[b.name.lowercased()] ?? Int.max
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }
    
    private func productPriceText(for product: Product) -> String {
        // Dùng giá bán đã lưu trực tiếp; nếu chưa có (0) thì fallback về costPrice
        let price = product.price > 0 ? product.price : product.costPrice
        return formatCurrency(price)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Compact Two-Row Mode Selector
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        modeButton(for: m)
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
                                
                                Spacer()
                                
                                Button {
                                    showPrintOptions = true
                                } label: {
                                    HStack {
                                        Image(systemName: "printer")
                                        Text("In")
                                    }
                                    .font(.headline)
                                }
                                .buttonStyle(.borderedProminent)
                                .confirmationDialog("Chọn kiểu in", isPresented: $showPrintOptions, titleVisibility: .visible) {
                                    if mode == .nhapThanhPham || mode == .xuatThanhPham {
                                        Button("In toàn bộ thành phẩm") {
                                            renderFinishedGoodsFullImage()
                                        }
                                    } else {
                                        Button("In toàn bộ nguyên liệu") {
                                            renderMaterialsFullImage()
                                        }
                                    }
                                    if mode == .nhapThanhPham || mode == .xuatThanhPham {
                                        Button("In bill điền tay để scan nhập thành phẩm") {
                                            renderFinishedGoodsBlankImage()
                                        }
                                    } else {
                                        Button("In bill điền tay để scan nhập nguyên liệu") {
                                            renderMaterialsBlankImage()
                                        }
                                    }
                                    Button("Hủy", role: .cancel) { }
                                }
                            }
                            .padding(.horizontal)
                            
                            if mode == .nhapThanhPham || mode == .xuatThanhPham {
                                let filtered = sortedFinishedGoods
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
                                                .frame(width: 80, alignment: .trailing)
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
                                                        priceText: productPriceText(for: p),
                                                        stockText: FormatUtils.formatWeight(p.stockQuantity),
                                                        hasVAT: p.hasVAT
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
                            ForEach(sortedMaterials) { item in
                                let shouldHighlightRed = item.stockQuantity == 0 || (item.minStockAlertThreshold != nil && item.stockQuantity <= item.minStockAlertThreshold!)
                                Button {
                                    editingMaterial = item
                                    showMaterialEdit = true
                                } label: {
                                    HStack {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.themeTextDark)
                                            .lineLimit(2)
                                        if item.hasVAT {
                                            Text("VAT")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.85))
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                        Text(formatCurrency(item.lastUnitPrice))
                                            .font(.subheadline)
                                            .foregroundStyle(Color.themePrimary)
                                            .frame(width: 120, alignment: .trailing)
                                        Text(FormatUtils.formatWeight(item.stockQuantity, unit: item.unit))
                                            .font(.subheadline)
                                            .fontWeight(shouldHighlightRed ? .bold : .regular)
                                            .foregroundStyle(shouldHighlightRed ? .red : .gray)
                                            .frame(width: 80, alignment: .trailing)
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
                            // Search bar for history
                            HStack {
                                HStack {
                                    Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                                    TextField("Tìm theo tên hoặc mã phiếu...", text: $historySearchText)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                    if !historySearchText.isEmpty {
                                        Button { historySearchText = "" } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            let filteredHistory = viewModel.productionHistory.filter { tx in
                                if historySearchText.isEmpty { return true }
                                let searchLower = historySearchText.lowercased()
                                // Search by transaction ID or item names
                                let matchId = tx.id.uuidString.lowercased().contains(searchLower)
                                let matchItems = tx.items.contains { item in
                                    item.name.lowercased().contains(searchLower)
                                }
                                return matchId || matchItems
                            }
                            
                            if filteredHistory.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 60))
                                        .foregroundStyle(Color.gray.opacity(0.3))
                                    Text(historySearchText.isEmpty ? "Chưa có lịch sử" : "Không tìm thấy kết quả")
                                        .font(.headline)
                                        .foregroundStyle(.gray)
                                }
                                .frame(maxWidth: .infinity, minHeight: 220)
                            } else {
                                historyListView(for: filteredHistory)
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
                            await viewModel.loadProductionHistory(mode: mode.rawValue)
                        }
                        materialTab = 1  // Chuyển sang tab Lịch sử sau khi lưu
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
            .onChange(of: materialTab) { newVal in
                // Clear search text when switching tabs
                if newVal == 0 {
                    historySearchText = ""
                } else {
                    searchText = ""
                }
                if newVal == 1, let m = selectedMode {
                    Task { await viewModel.loadProductionHistory(mode: m.rawValue) }
                }
            }
            .onChange(of: selectedMode) { m in
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
                    MaterialEditView(viewModel: viewModel, mode: .edit(m), allowEditPriceAndStock: true)
                }
            }
            .sheet(isPresented: $showTransactionEdit) {
                if let tx = editingTransaction {
                    TransactionEditView(viewModel: viewModel, original: tx)
                }
            }
            .sheet(isPresented: $showPrintSheet) {
                if let tx = printingTransaction {
                    ProductionBillDetailView(tx: tx, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showExportWarehousePrintSheet) {
                if let tx = printingTransaction {
                    ProductionExportWarehouseBillView(tx: tx, viewModel: viewModel)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProductionScrollToTx"))) { notif in
                guard let txId = notif.userInfo?["txId"] as? UUID,
                      let mode = notif.userInfo?["mode"] as? String else { return }
                // Set mode trước
                if let m = Mode(rawValue: mode) { selectedMode = m }
                // Đợi UI render mode mới xong rồi mới chuyển tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation { materialTab = 1 }
                    // Highlight sau khi history đã load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        highlightedTxId = txId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            highlightedTxId = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showAutoMaterialExport, onDismiss: {
                materialTab = 1
                Task { await viewModel.loadProductionHistory(mode: "Xuất nguyên liệu") }
            }) {
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
            .sheet(isPresented: $showPrintShareSheet) {
                if let image = printImage {
                    ShareSheet(items: [image])
                }
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

    // MARK: - History Card Actions
    private func handleShowEditHistory(txId: UUID) async {
        let entries = await viewModel.fetchProductionEdits(for: txId)
        await MainActor.run {
            editHistoryEntries = entries
            showEditHistory = true
        }
    }

    private func handleShowAutoExportDetail(txId: UUID) async {
        let logs = await viewModel.fetchAutoMaterialExportLogsForTransaction(transactionId: txId)
        let firstLog = logs.first
        await MainActor.run {
            selectedAutoExportLog = firstLog
            showAutoExportDetail = (firstLog != nil)
        }
    }

    private func handleEdit(tx: ProductionTransaction) {
        editingTransaction = tx
        showTransactionEdit = true
    }

    private func handlePrint(tx: ProductionTransaction) {
        printingTransaction = tx
        showPrintSheet = true
    }

    private func handlePrintExport(tx: ProductionTransaction) {
        printingTransaction = tx
        showExportWarehousePrintSheet = true
    }

    // MARK: - History List View
    private func historyListView(for history: [ProductionTransaction]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(history, id: \.id) { tx in
                        historyCard(for: tx)
                    }
                }
                .padding(.top, 8)
            }
            .onChange(of: highlightedTxId) { txId in
                if let txId {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(txId, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historyCard(for tx: ProductionTransaction) -> some View {
        let txId = tx.id
        ProductionTransactionHistoryCard(
            tx: tx,
            selectedMode: selectedMode,
            editedIds: viewModel.editedProductionTxIds,
            isHighlighted: highlightedTxId == txId,
            onShowEditHistory: {
                Task { await handleShowEditHistory(txId: txId) }
            },
            onShowAutoExportDetail: {
                Task { await handleShowAutoExportDetail(txId: txId) }
            },
            onEdit: { handleEdit(tx: tx) },
            onPrint: { handlePrint(tx: tx) },
            onPrintExport: { handlePrintExport(tx: tx) }
        )
        .id(txId)
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

    @ViewBuilder
    func modeButton(for mode: Mode) -> some View {
        let isSelected = selectedMode == mode
        let modeColor = color(for: mode)
        Button(action: { selectedMode = mode }) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: mode))
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? modeColor : Color.white)
            .foregroundStyle(isSelected ? .white : modeColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(modeColor.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
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
    var hasVAT: Bool = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                    .lineLimit(2)
                if hasVAT {
                    Text("VAT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.85))
                        .clipShape(Capsule())
                }
            }
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
    var isHighlighted: Bool
    let onShowEditHistory: () -> Void
    let onShowAutoExportDetail: () -> Void
    let onEdit: () -> Void
    let onPrint: () -> Void
    let onPrintExport: (() -> Void)?

    init(
        tx: ProductionTransaction,
        selectedMode: ProductionManagementView.Mode?,
        editedIds: Set<UUID>,
        isHighlighted: Bool = false,
        onShowEditHistory: @escaping () -> Void,
        onShowAutoExportDetail: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onPrint: @escaping () -> Void,
        onPrintExport: (() -> Void)? = nil
    ) {
        self.tx = tx
        self.selectedMode = selectedMode
        self.editedIds = editedIds
        self.isHighlighted = isHighlighted
        self.onShowEditHistory = onShowEditHistory
        self.onShowAutoExportDetail = onShowAutoExportDetail
        self.onEdit = onEdit
        self.onPrint = onPrint
        self.onPrintExport = onPrintExport
    }

    @State private var showDeleteInfo = false

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
            // Header row: Thời gian + STT nhỏ
            HStack(spacing: 8) {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(tx.isDeleted ? Color.gray : Color.themeTextDark)
                
                if let stt = tx.sequenceNumber {
                    Text("STT: \(stt)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(tx.isDeleted ? Color.gray : Color.themePrimary)
                }
                
                Spacer()
            }

            // Badge row: Badges, Tên nhân viên, Lịch sử chỉnh sửa
            HStack(spacing: 8) {
                if tx.isDeleted {
                    // Badge "Đã xoá" — bấm để xem thông tin
                    Button {
                        showDeleteInfo = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.caption2)
                            Text("Đã xoá")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeleteInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thông tin xoá", systemImage: "trash.fill")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.red)
                            if let name = tx.deletedByName, !name.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Người xoá:").foregroundStyle(.gray)
                                    Text(name).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let at = tx.deletedAt {
                                HStack(spacing: 4) {
                                    Text("Thời gian:").foregroundStyle(.gray)
                                    Text(formatTxDate(at)).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let note = tx.deleteNote, !note.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Lý do:").foregroundStyle(.gray)
                                    Text(note).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(14)
                        .frame(width: 240)
                        .presentationCompactAdaptation(.popover)
                    }
                } else {
                    if showEditedBadge {
                        Text("Đã chỉnh sửa")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange))
                    }
                    if showAutoExportButton {
                        Button(action: onShowAutoExportDetail) {
                            Text("Chi tiết tự động")
                                .font(.caption).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                        }
                    }
                    if let name = tx.creatorName, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                Spacer()
                if !tx.isDeleted {
                    Button(action: onShowEditHistory) {
                        Text("Lịch sử chỉnh sửa")
                            .font(.caption).fontWeight(.bold).foregroundStyle(Color.themePrimary)
                    }
                }
            }

            // Items
            VStack(spacing: 6) {
                ForEach(tx.items, id: \.id) { it in
                    ProductionTransactionItemRow(item: it, isExportMode: isExportMode)
                }
            }
            .opacity(tx.isDeleted ? 0.45 : 1)

            // Bottom row
            HStack {
                if isExportToInventory && !tx.isDeleted {
                    Text("xuất sang kho hàng hoá")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.purple.opacity(0.85)))
                }
                Spacer()
                // Nút In xuất kho (chỉ hiện khi có callback)
                if !tx.isDeleted, let onPrintExport = onPrintExport {
                    Button(action: onPrintExport) {
                        HStack(spacing: 4) {
                            Image(systemName: "printer.fill")
                                .font(.caption)
                            Text("In xuất kho")
                                .font(.subheadline).fontWeight(.bold)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.themePrimary))
                    }
                }
                // Nút In đơn
                if !tx.isDeleted {
                    Button(action: onPrint) {
                        HStack(spacing: 4) {
                            Image(systemName: "printer")
                                .font(.caption)
                            Text("In đơn")
                                .font(.subheadline).fontWeight(.bold)
                        }
                        .foregroundStyle(Color.themePrimary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.themePrimary.opacity(0.1)))
                    }
                }
                // Nút Sửa — luôn hiện để có thể xoá từ đây
                Button(action: onEdit) {
                    Text("Sửa")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(tx.isDeleted ? Color.gray : Color.themePrimary))
                }
            }
        }
        .padding(12)
        .background(tx.isDeleted ? Color.gray.opacity(0.08) : (isHighlighted ? Color.themePrimary.opacity(0.06) : Color.white))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHighlighted ? Color.themePrimary : (tx.isDeleted ? Color.red.opacity(0.2) : Color.clear),
                    lineWidth: isHighlighted ? 2 : 1
                )
        )
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
        let qtyText = FormatUtils.formatWeight(item.quantity, unit: item.unit)
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

// MARK: - Print Helpers
private func formatDateTimeForPrint(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter.string(from: date)
}

private extension ProductionManagementView {
    func renderMaterialsFullImage() {
        let view = MaterialsFullPrintView(materials: viewModel.materials)
            .frame(width: 375)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showPrintShareSheet = true
        }
    }
    
    func renderMaterialsBlankImage() {
        let view = MaterialsBlankPrintView(materials: viewModel.materials)
            .frame(width: 375)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showPrintShareSheet = true
        }
    }
    
    func renderFinishedGoodsFullImage() {
        let view = FinishedGoodsFullPrintView(products: viewModel.finishedGoods)
            .frame(width: 375)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showPrintShareSheet = true
        }
    }
    
    func renderFinishedGoodsBlankImage() {
        let view = FinishedGoodsBlankPrintView(products: viewModel.finishedGoods)
            .frame(width: 375)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showPrintShareSheet = true
        }
    }
}

// MARK: - Materials Print Views
struct MaterialsFullPrintView: View {
    let materials: [MaterialItem]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Danh sách nguyên liệu")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Ngày giờ: \(formatDateTimeForPrint(printDate))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            
            HStack {
                Text("STT").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 30, alignment: .trailing)
                Text("Nguyên liệu").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Giá nhập").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
                Text("Kho").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 60, alignment: .trailing)
            }
            
            ForEach(Array(materials.enumerated()), id: \.element.id) { index, m in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(width: 30, alignment: .trailing)
                    Text(m.name)
                        .foregroundStyle(Color.themeTextDark)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatCurrency(m.lastUnitPrice))
                        .foregroundStyle(Color.themeTextDark)
                        .frame(width: 90, alignment: .trailing)
                    Text("\(Int(m.stockQuantity))")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct MaterialsBlankPrintView: View {
    let materials: [MaterialItem]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phiếu nhập nguyên liệu trống")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Ngày giờ: \(formatDateTimeForPrint(printDate))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            
            HStack(spacing: 0) {
                Text("STT")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 30, alignment: .trailing)
                Divider()
                Text("Nguyên liệu")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text("Số lượng")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 80, alignment: .trailing)
                Divider()
                Text("Đơn giá")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 80, alignment: .trailing)
                Divider()
                Text("Chi phí")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(width: 80, alignment: .trailing)
            }
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            
            ForEach(Array(materials.enumerated()), id: \.element.id) { index, m in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(width: 30, alignment: .trailing)
                    Divider()
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        Text(m.name)
                            .foregroundStyle(Color.themeTextDark)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Finished Goods Print Views
struct FinishedGoodsFullPrintView: View {
    let products: [Product]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Danh sách thành phẩm")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Ngày giờ: \(formatDateTimeForPrint(printDate))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            
            HStack {
                Text("STT").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 30, alignment: .trailing)
                Text("Thành phẩm").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Giá bán").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
                if AuthManager.shared.canViewCostPrice {
                    Text("Giá vốn").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                        .frame(width: 90, alignment: .trailing)
                }
                Text("Kho").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 60, alignment: .trailing)
            }
            
            ForEach(Array(products.enumerated()), id: \.element.id) { index, p in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(width: 30, alignment: .trailing)
                    Text(p.name)
                        .foregroundStyle(Color.themeTextDark)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatCurrency(p.price))
                        .foregroundStyle(Color.themeTextDark)
                        .frame(width: 90, alignment: .trailing)
                    if AuthManager.shared.canViewCostPrice {
                        Text(formatCurrency(p.costPrice))
                            .foregroundStyle(.gray)
                            .frame(width: 90, alignment: .trailing)
                    }
                    Text("\(p.stockQuantity)")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct FinishedGoodsBlankPrintView: View {
    let products: [Product]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phiếu nhập thành phẩm trống")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Ngày giờ: \(formatDateTimeForPrint(printDate))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            
            HStack(spacing: 0) {
                Text("STT")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 30, alignment: .trailing)
                Divider()
                Text("Thành phẩm")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text("Số lượng")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 80, alignment: .trailing)
                Divider()
                Text("Đơn giá")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 80, alignment: .trailing)
                Divider()
                Text("Chi phí")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(width: 80, alignment: .trailing)
            }
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            
            ForEach(Array(products.enumerated()), id: \.element.id) { index, p in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(width: 30, alignment: .trailing)
                    Divider()
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        Text(p.name)
                            .foregroundStyle(Color.themeTextDark)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                    
                    Divider()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 24)
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .padding()
    }
}
