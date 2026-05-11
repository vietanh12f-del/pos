import SwiftUI
import Combine

struct InventoryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showingAddProduct: Bool
    @Binding var showNewRestock: Bool
    
    @State private var selectedTab: Int = 0 // 0: Kho hàng, 1: Lịch sử nhập
    @State private var searchText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var productToDelete: Product?
    @State private var editingProduct: Product?
    @State private var showRestockDetail = false
    @State private var selectedRestockBill: RestockBill?
    @State private var showBarcodeScanner = false
    @State private var productToPrint: Product?
    @State private var showPrintOptions = false
    @State private var printImage: UIImage?
    @State private var showPrintShareSheet = false
    @State private var showDeleteRestockConfirmation = false
    @State private var restockBillToDelete: RestockBill?
    @State private var showRestockEditHistory = false
    @State private var restockBillForHistory: RestockBill?
    @State private var showFilterSheet = false
    @State private var showInventoryReport = false
    
    // Filter states
    enum DateFilterMode: String, CaseIterable, Identifiable {
        case all, today, yesterday, week, month, quarter, year, custom
        var id: String { rawValue }
    }
    @State private var dateFilterMode: DateFilterMode = .all
    @State private var customStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate: Date = Date()
    @State private var showCustomDateSheet: Bool = false
    
    @State private var filterCreator: String = ""
    @State private var filterSupplierName: String = ""
    @State private var filterMinCost: String = ""
    @State private var filterMaxCost: String = ""
    
    enum VATFilterMode: String, CaseIterable, Identifiable {
        case all, hasVAT, noVAT
        var id: String { rawValue }
    }
    @State private var vatFilterMode: VATFilterMode = .all
    
    @State private var filterProductName: String = ""
    
    // Get unique creator names and supplier names from restock history
    private var uniqueCreators: [String] {
        Array(Set(viewModel.restockHistory.compactMap { $0.creatorName })).sorted()
    }
    
    private var uniqueSuppliers: [String] {
        let savedSuppliers = viewModel.suppliers.map { $0.name }
        let restockSuppliers = viewModel.restockHistory.compactMap { $0.supplierName }
        return Array(Set(savedSuppliers + restockSuppliers)).sorted()
    }
    
    // Get unique product names from all restock items
    private var uniqueProductNames: [String] {
        let allNames = viewModel.restockHistory.flatMap { $0.items.map { $0.name } }
        return Array(Set(allNames)).sorted()
    }
    
    private var dateFilterLabel: String {
        switch dateFilterMode {
        case .all: return "Tất cả"
        case .today: return "Hôm nay"
        case .yesterday: return "Hôm qua"
        case .week: return "Tuần"
        case .month: return "Tháng"
        case .quarter: return "Quý"
        case .year: return "Năm"
        case .custom: return "Tùy chọn"
        }
    }
    
    private var hasActiveFilters: Bool {
        dateFilterMode != .all ||
        !filterCreator.isEmpty ||
        !filterSupplierName.isEmpty ||
        vatFilterMode != .all ||
        !filterProductName.isEmpty ||
        !filterMinCost.isEmpty ||
        !filterMaxCost.isEmpty
    }
    
    private var activeFilterSummary: String {
        var parts: [String] = []
        if dateFilterMode != .all {
            parts.append(dateFilterLabel)
        }
        if !filterCreator.isEmpty {
            parts.append("Người nhập: \(filterCreator)")
        }
        if !filterSupplierName.isEmpty {
            parts.append("NCC: \(filterSupplierName)")
        }
        if vatFilterMode != .all {
            parts.append(vatFilterMode == .hasVAT ? "Có VAT" : "Không VAT")
        }
        if !filterProductName.isEmpty {
            parts.append("Sản phẩm: \(filterProductName)")
        }
        if !filterMinCost.isEmpty || !filterMaxCost.isEmpty {
            let min = filterMinCost.isEmpty ? "0" : filterMinCost
            let max = filterMaxCost.isEmpty ? "∞" : filterMaxCost
            parts.append("Giá: \(min) - \(max)")
        }
        return parts.joined(separator: " • ")
    }
    
    private func selectedDateRange(now: Date = Date()) -> (Date, Date)? {
        let cal = Calendar.current
        switch dateFilterMode {
        case .all:
            return nil
        case .today:
            let start = cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return (start, end)
        case .yesterday:
            let start = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now))!
            let end = cal.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return (start, end)
        case .week:
            if let interval = cal.dateInterval(of: .weekOfYear, for: now) {
                let start = interval.start
                let end = min(interval.end, now)
                return (start, end)
            }
            return nil
        case .month:
            if let interval = cal.dateInterval(of: .month, for: now) {
                let start = interval.start
                let end = min(interval.end, now)
                return (start, end)
            }
            return nil
        case .quarter:
            let month = cal.component(.month, from: now)
            let year = cal.component(.year, from: now)
            let quarterStartMonth = [1,4,7,10].last { $0 <= month } ?? 1
            var comps = DateComponents()
            comps.year = year
            comps.month = quarterStartMonth
            comps.day = 1
            let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let endMonth = quarterStartMonth + 2
            var endComps = DateComponents()
            endComps.year = year
            endComps.month = endMonth
            endComps.day = cal.range(of: .day, in: .month, for: cal.date(from: endComps) ?? now)?.count ?? 30
            let quarterEndFull = cal.date(from: endComps) ?? now
            let end = min(quarterEndFull, now)
            return (start, end)
        case .year:
            if let interval = cal.dateInterval(of: .year, for: now) {
                let start = interval.start
                let end = min(interval.end, now)
                return (start, end)
            }
            return nil
        case .custom:
            let start = cal.startOfDay(for: customStartDate)
            let end = max(customEndDate, start)
            return (start, end)
        }
    }
    
    private func isDateInSelectedRange(_ date: Date) -> Bool {
        if let (start, end) = selectedDateRange() {
            return date >= start && date <= end
        }
        return true
    }
    
    private func highlightedInventoryName(_ name: String) -> AttributedString {
        var s = AttributedString(name)
        if let r = s.range(of: "sữa", options: .caseInsensitive) {
            s[r].foregroundColor = .red
            s[r].backgroundColor = .yellow
            s[r].font = .subheadline
        }
        return s
    }
    
    var filteredProducts: [Product] {
        let base = viewModel.products.filter { !$0.isFinishedGood }
        
        // Xây dựng thứ tự ưu tiên: sản phẩm vừa nhập (từ restockHistory mới nhất) lên đầu
        var recentOrder: [String: Int] = [:]
        let sortedBills = viewModel.restockHistory
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
        var rank = 0
        for bill in sortedBills {
            for item in bill.items {
                let key = item.name.lowercased()
                if recentOrder[key] == nil {
                    recentOrder[key] = rank
                    rank += 1
                }
            }
        }
        
        let filtered: [Product]
        if searchText.isEmpty {
            filtered = base
        } else {
            let q = searchText.lowercased()
            filtered = base.filter {
                $0.name.lowercased().contains(q) ||
                $0.category.lowercased().contains(q) ||
                ($0.barcode?.contains(searchText) ?? false)
            }
        }
        
        return filtered.sorted { a, b in
            let ra = recentOrder[a.name.lowercased()] ?? Int.max
            let rb = recentOrder[b.name.lowercased()] ?? Int.max
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }
    
    var filteredRestockHistory: [RestockBill] {
        var result = viewModel.restockHistory
        
        // Filter by date
        result = result.filter { isDateInSelectedRange($0.createdAt) }
        
        // Filter by creator
        if !filterCreator.isEmpty {
            result = result.filter { bill in
                bill.creatorName == filterCreator
            }
        }
        
        // Filter by supplier name
        if !filterSupplierName.isEmpty {
            result = result.filter { bill in
                bill.supplierName == filterSupplierName
            }
        }
        
        // Filter by VAT
        switch vatFilterMode {
        case .hasVAT:
            result = result.filter { bill in
                bill.items.contains { $0.hasVAT }
            }
        case .noVAT:
            result = result.filter { bill in
                !bill.items.contains { $0.hasVAT }
            }
        case .all:
            break
        }
        
        // Filter by product name
        if !filterProductName.isEmpty {
            result = result.filter { bill in
                bill.items.contains { $0.name == filterProductName }
            }
        }
        
        // Filter by min cost
        if let minCost = Double(filterMinCost), minCost > 0 {
            result = result.filter { $0.totalCost >= minCost }
        }
        
        // Filter by max cost
        if let maxCost = Double(filterMaxCost), maxCost > 0 {
            result = result.filter { $0.totalCost <= maxCost }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { bill in
                bill.items.contains { $0.name.lowercased().contains(searchText.lowercased()) }
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Chế độ", selection: $selectedTab) {
                    Text("Hàng hóa").tag(0)
                    Text("Lịch sử nhập").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Bar + Print
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        TextField("Tìm kiếm...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                        
                        Button(action: { showBarcodeScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    
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
                        Button("In toàn bộ sản phẩm") {
                            renderInventoryFullImage()
                        }
                        Button("In bill điền tay để scan nhập hàng") {
                            renderInventoryBlankImage()
                        }
                        Button("Hủy", role: .cancel) { }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 0)
                
                
                
                // Content
                if selectedTab == 0 {
                    // Goods List
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredProducts.isEmpty {
                        ScrollView {
                            VStack(spacing: 16) {
                                Image(systemName: "cube.box")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                Text("Chưa có hàng hóa")
                                    .font(.headline)
                                    .foregroundStyle(Color.gray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        }
                        .refreshable {
                            await viewModel.loadData(force: true)
                        }
                    } else {
                        List {
                            // Header Row
                            HStack {
                                Text("Sản phẩm")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Giá bán")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 80, alignment: .trailing)
                                
                                Text("Giá vốn")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 80, alignment: .trailing)
                                
                                Text("Kho")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .padding(.top, 0)
                            
                            ForEach(filteredProducts) { product in
                                HStack(spacing: 12) {
                                    if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else if let imageURL = product.imageURL, let url = URL(string: imageURL) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else if phase.error != nil {
                                                Image(systemName: "photo.badge.exclamationmark")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 44, height: 44)
                                                    .foregroundColor(.gray)
                                            } else {
                                                ProgressView()
                                                    .frame(width: 44, height: 44)
                                            }
                                        }
                                    } else {
                                        Image(systemName: product.imageName)
                                            .font(.title2)
                                            .foregroundStyle(Color.themePrimary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.themePrimary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(product.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                                .lineLimit(nil)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .layoutPriority(1)
                                            if product.hasVAT {
                                                Text("VAT")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.85))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Text(product.category)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text(formatCurrency(product.price))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.themeTextDark)
                                        .frame(width: 80, alignment: .trailing)
                                    
                                    Text(formatCurrency(product.costPrice))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .frame(width: 80, alignment: .trailing)
                                    
                                    Text("\(viewModel.stockLevel(for: product.name))")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(viewModel.stockLevel(for: product.name) > 0 ? Color.themePrimary : Color.red)
                                        .frame(width: 50, alignment: .trailing)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withTransaction(Transaction(animation: nil)) {
                                        editingProduct = product
                                    }
                                }
                                .listRowBackground(Color.white)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if StoreManager.shared.currentMember?.role == .owner {
                                        Button(role: .destructive) {
                                            productToDelete = product
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                                    
                                    Button {
                                        productToPrint = product
                                    } label: {
                                        Label("In Mã", systemImage: "printer")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .refreshable {
                            await viewModel.loadData(force: true)
                        }
                    }
                } else {
                    // Restock History List
                    HStack {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Label("Lọc", systemImage: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.orange)
                        }
                        if hasActiveFilters {
                            Text(activeFilterSummary)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        } else {
                            Text("Tất cả")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    
                    if viewModel.restockHistory.isEmpty {
                        ScrollView {
                            VStack(spacing: 16) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                Text("Chưa có lịch sử nhập hàng")
                                    .font(.headline)
                                    .foregroundStyle(Color.gray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        }
                        .refreshable {
                            await viewModel.loadData(force: true)
                        }
                    } else {
                        List {
                            ForEach(filteredRestockHistory) { bill in
                                InventoryRestockHistoryCard(
                                    bill: bill,
                                    viewModel: viewModel,
                                    onTap: {
                                        withTransaction(Transaction(animation: nil)) {
                                            selectedRestockBill = bill
                                        }
                                    },
                                    onEdit: {
                                        viewModel.editRestockBill(bill)
                                        DispatchQueue.main.async {
                                            showNewRestock = true
                                        }
                                    },
                                    onDelete: {
                                        restockBillToDelete = bill
                                        showDeleteRestockConfirmation = true
                                    },
                                    onShowHistory: {
                                        restockBillForHistory = bill
                                        showRestockEditHistory = true
                                    }
                                )
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .refreshable {
                            await viewModel.loadData(force: true)
                        }
                    }
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Kho hàng hóa")
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showInventoryReport = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Báo cáo kho")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(0.95),
                                            Color.teal.opacity(0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 54)
                                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .contentShape(Rectangle())
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InventoryShowHistory"))) { _ in
                selectedTab = 1
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Removed redundant Plus button as per user request
                    EmptyView()
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadData(force: true)
                }
            }
            .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation, presenting: productToDelete) { product in
                Button("Xóa", role: .destructive) {
                    if let index = viewModel.products.firstIndex(where: { $0.id == product.id }) {
                        // Optimistic update
                        viewModel.deleteProduct(product)
                    }
                }
                Button("Hủy", role: .cancel) {}
            } message: { product in
                Text("Bạn có chắc muốn xóa sản phẩm '\(product.name)'? Hành động này không thể hoàn tác.")
            }
            .sheet(item: $editingProduct) { product in
                // Từ Kho hàng hoá: không cho chỉnh Giá vốn + Tồn kho
                ProductEditView(viewModel: viewModel, mode: .edit(product), allowEditCostAndStock: false)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddProduct) {
                ProductEditView(viewModel: viewModel, mode: .add)
            }
            .sheet(item: $selectedRestockBill) { bill in
                RestockDetailView(
                    bill: bill,
                    viewModel: viewModel,
                    showNewRestock: $showNewRestock
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(onScan: { code in
                    searchText = code
                    showBarcodeScanner = false // Dismiss automatically
                })
            }
            .sheet(isPresented: $showCustomDateSheet) {
                VStack(spacing: 12) {
                    Text("Chọn khoảng thời gian")
                        .font(.headline)
                    DatePicker("Từ ngày", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("Đến ngày", selection: $customEndDate, displayedComponents: .date)
                    HStack {
                        Button("Đóng") { showCustomDateSheet = false }
                        Spacer()
                        Button("Áp dụng") {
                            dateFilterMode = .custom
                            showCustomDateSheet = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(320)])
            }
            .sheet(item: $productToPrint) { product in
                BarcodePrintView(product: product)
            }
            .sheet(isPresented: $showPrintShareSheet) {
                if let img = printImage {
                    ShareSheet(items: [img])
                }
            }
            .sheet(isPresented: $showRestockEditHistory) {
                if let bill = restockBillForHistory {
                    RestockEditHistorySheet(viewModel: viewModel, restockBillId: bill.id)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                RestockFilterSheet(
                    dateFilterMode: $dateFilterMode,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate,
                    filterCreator: $filterCreator,
                    filterSupplierName: $filterSupplierName,
                    filterMinCost: $filterMinCost,
                    filterMaxCost: $filterMaxCost,
                    vatFilterMode: $vatFilterMode,
                    filterProductName: $filterProductName,
                    uniqueCreators: uniqueCreators,
                    uniqueSuppliers: uniqueSuppliers,
                    uniqueProductNames: uniqueProductNames
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInventoryReport) {
                InventoryReportView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Xóa phiếu nhập?", isPresented: $showDeleteRestockConfirmation, presenting: restockBillToDelete) { bill in
                Button("Hủy", role: .cancel) { }
                Button("Xóa", role: .destructive) {
                    Task { await viewModel.softDeleteRestockBill(bill) }
                }
            } message: { _ in
                Text("Phiếu sẽ được đánh dấu đã xoá và tồn kho/giá nhập sẽ được khôi phục. Phiếu vẫn còn trong lịch sử.")
            }
        }
    }
}

// MARK: - Restock History Card for Inventory
private struct InventoryRestockHistoryCard: View {
    let bill: RestockBill
    let viewModel: OrderViewModel
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShowHistory: () -> Void
    
    private func highlightedInventoryName(_ name: String) -> AttributedString {
        var s = AttributedString(name)
        if let r = s.range(of: "sữa", options: .caseInsensitive) {
            s[r].foregroundColor = .red
            s[r].backgroundColor = .yellow
            s[r].font = .subheadline
        }
        return s
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        return formatter.string(from: NSNumber(value: amount)) ?? "0 đ"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: Thời gian + STT nhỏ
            HStack(spacing: 8) {
                Text(formatDate(bill.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(bill.isDeleted ? Color.gray : Color.themeTextDark)
                
                if let stt = bill.sequenceNumber {
                    Text("STT: \(stt)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(bill.isDeleted ? Color.gray : Color.themePrimary)
                }
                
                Spacer()
            }
            
            // Badge row: Badges, Tên nhân viên, Nút Sửa/Xóa/Lịch sử
            HStack(spacing: 8) {
                if bill.isDeleted {
                    Text("Đã xoá")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.75))
                        .clipShape(Capsule())
                } else {
                    if viewModel.editedRestockBillIds.contains(bill.id) {
                        Text("Đã sửa")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    if bill.items.contains(where: { $0.isFinishedGood }) {
                        Text("nhập từ thành phẩm")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    if let name = bill.creatorName, !name.isEmpty {
                        HStack(spacing: 4) {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.gray)
                            if let supplierName = bill.supplierName, !supplierName.isEmpty {
                                Text("• \(supplierName)")
                                    .font(.caption)
                                    .foregroundStyle(.gray.opacity(0.7))
                            }
                        }
                    } else if let supplierName = bill.supplierName, !supplierName.isEmpty {
                        Text(supplierName)
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                }
                Spacer()
                if !bill.isDeleted {
                    if viewModel.editedRestockBillIds.contains(bill.id) {
                        Button(action: onShowHistory) {
                            Text("Lịch sử")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    Button(action: onDelete) {
                        Text("Xóa")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red))
                    }
                    Button(action: onEdit) {
                        Text("Sửa")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange))
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bill.items.prefix(3)) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(highlightedInventoryName(item.name))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            Text("Giá nhập \(formatCurrency(item.unitPrice))")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.75))
                                .clipShape(Capsule())
                            Text("Số lượng \(item.quantity)")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.75))
                                .clipShape(Capsule())
                            if item.additionalCost > 0 {
                                Text("Chi phí \(formatCurrency(item.additionalCost))")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.75))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                if bill.items.count > 3 {
                    Text("… xem thêm \(bill.items.count - 3) mặt hàng")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.leading, 20)
            .opacity(bill.isDeleted ? 0.45 : 1)
            
            HStack {
                Spacer()
                Text("\(bill.items.count) mặt hàng")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
        }
        .padding(12)
        .background(bill.isDeleted ? Color.gray.opacity(0.08) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bill.isDeleted ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }
}

// MARK: - Print Helpers
private extension InventoryView {
    func calculateCorrectedTotal(_ bill: RestockBill) -> Double {
        guard !bill.items.isEmpty else { return bill.totalCost }
        let materialNames = Set(viewModel.materials.map { $0.name.lowercased() })
        return bill.items.reduce(0) { acc, item in
            let isMaterial = materialNames.contains(item.name.lowercased())
            let base = isMaterial ? (item.unitPrice * (Double(item.quantity) / 1000.0)) : (item.unitPrice * Double(item.quantity))
            return acc + base + item.additionalCost
        }
    }
    func renderInventoryFullImage() {
        let view = InventoryFullPrintView(products: viewModel.products)
            .frame(width: 375)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showPrintShareSheet = true
        }
    }
    
    func renderInventoryBlankImage() {
        let view = InventoryBlankPrintView(products: viewModel.products)
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

// MARK: - Print Views
private func formatDateTimeForPrint(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter.string(from: date)
}

struct InventoryFullPrintView: View {
    let products: [Product]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Danh sách sản phẩm")
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
                Text("Sản phẩm").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Giá bán").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
                Text("Giá vốn").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
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
                    Text(formatCurrency(p.costPrice))
                        .foregroundStyle(.gray)
                        .frame(width: 90, alignment: .trailing)
                    Text("\(p.stockQuantity)")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white)
    }
}

struct InventoryBlankPrintView: View {
    let products: [Product]
    let printDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phiếu nhập trống")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Ngày giờ: \(formatDateTimeForPrint(printDate))")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            
            HStack(spacing: 8) {
                Text("Ngày điền:")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
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
            
            HStack(spacing: 0) {
                Text("STT")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 30, alignment: .trailing)
                Divider()
                Text("Sản phẩm")
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color.white)
        )
    }
}

// MARK: - Filter Sheet for Restock History
struct RestockFilterSheet: View {
    @Binding var dateFilterMode: InventoryView.DateFilterMode
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Binding var filterCreator: String
    @Binding var filterSupplierName: String
    @Binding var filterMinCost: String
    @Binding var filterMaxCost: String
    @Binding var vatFilterMode: InventoryView.VATFilterMode
    @Binding var filterProductName: String
    
    let uniqueCreators: [String]
    let uniqueSuppliers: [String]
    let uniqueProductNames: [String]
    
    @Environment(\.dismiss) var dismiss
    
    private func dateFilterLabel(for mode: InventoryView.DateFilterMode) -> String {
        switch mode {
        case .all: return "Tất cả"
        case .today: return "Hôm nay"
        case .yesterday: return "Hôm qua"
        case .week: return "Tuần"
        case .month: return "Tháng"
        case .quarter: return "Quý"
        case .year: return "Năm"
        case .custom: return "Tùy chọn"
        }
    }
    
    private func vatFilterLabel(for mode: InventoryView.VATFilterMode) -> String {
        switch mode {
        case .all: return "Tất cả"
        case .hasVAT: return "Có VAT"
        case .noVAT: return "Không VAT"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Thời gian") {
                    Picker("Chọn khoảng thời gian", selection: $dateFilterMode) {
                        ForEach(InventoryView.DateFilterMode.allCases) { mode in
                            Text(dateFilterLabel(for: mode)).tag(mode)
                        }
                    }
                    if dateFilterMode == .custom {
                        HStack {
                            DatePicker("Từ ngày", selection: $customStartDate, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                        }
                    }
                }
                
                Section("Người nhập") {
                    if uniqueCreators.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundStyle(.gray)
                    } else {
                        Picker("Chọn người nhập", selection: $filterCreator) {
                            Text("Tất cả").tag("")
                            ForEach(uniqueCreators, id: \.self) { creator in
                                Text(creator).tag(creator)
                            }
                        }
                    }
                }
                
                Section("Cơ sở cung cấp") {
                    if uniqueSuppliers.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundStyle(.gray)
                    } else {
                        Picker("Chọn cơ sở cung cấp", selection: $filterSupplierName) {
                            Text("Tất cả").tag("")
                            ForEach(uniqueSuppliers, id: \.self) { supplier in
                                Text(supplier).tag(supplier)
                            }
                        }
                    }
                }
                
                Section("VAT") {
                    Picker("Chọn VAT", selection: $vatFilterMode) {
                        ForEach(InventoryView.VATFilterMode.allCases) { mode in
                            Text(vatFilterLabel(for: mode)).tag(mode)
                        }
                    }
                }
                
                Section("Sản phẩm") {
                    if uniqueProductNames.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundStyle(.gray)
                    } else {
                        Picker("Chọn sản phẩm", selection: $filterProductName) {
                            Text("Tất cả").tag("")
                            ForEach(uniqueProductNames, id: \.self) { productName in
                                Text(productName).tag(productName)
                            }
                        }
                    }
                }
                
                Section("Tổng chi phí") {
                    HStack {
                        Text("Từ")
                        TextField("0", text: $filterMinCost)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Đến")
                        TextField("0", text: $filterMaxCost)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button("Đặt lại tất cả") {
                        dateFilterMode = .all
                        filterCreator = ""
                        filterSupplierName = ""
                        vatFilterMode = .all
                        filterProductName = ""
                        filterMinCost = ""
                        filterMaxCost = ""
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Lọc phiếu nhập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Inventory Report View
struct InventoryReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInfoSheet = false
    @State private var selectedFieldInfo: (title: String, desc: String)? = nil
    
    private let fieldExplanations: [String: (title: String, desc: String)] = [
        "Số hàng hóa hiện tại": ("Số hàng hóa hiện tại", "Số loại hàng hóa hiện có trong kho (không bao gồm thành phẩm)"),
        "Giá trị tồn kho": ("Giá trị tồn kho", "Tổng giá trị hàng hóa hiện có trong kho (tính theo giá vốn)"),
        "Số phiếu xuất": ("Số đơn hàng", "Tổng số đơn hàng bán lẻ trong khoảng thời gian đã chọn"),
        "Số đơn hàng": ("Số đơn hàng", "Tổng số đơn hàng bán lẻ trong khoảng thời gian đã chọn"),
        "Doanh thu": ("Tổng doanh thu", "Tổng doanh thu từ tất cả đơn hàng trong khoảng thời gian đã chọn"),
        "Phiếu có VAT": ("Phiếu có VAT", "Số phiếu nhập hàng có ít nhất một mặt hàng có VAT"),
        "Giá trị VAT": ("Tổng VAT", "Tổng giá trị VAT từ tất cả các mặt hàng trong các phiếu nhập"),
        "Số phiếu nhập": ("Số phiếu nhập", "Tổng số phiếu nhập hàng trong khoảng thời gian đã chọn"),
        "Tổng chi phí": ("Tổng chi phí", "Tổng chi phí nhập hàng trong khoảng thời gian đã chọn")
    ]
    
    // MARK: - Date Filter
    enum QuickRange: String, CaseIterable {
        case today    = "Hôm nay"
        case thisWeek = "Tuần này"
        case thisMonth = "Tháng này"
        case custom   = "Tuỳ chọn"
    }
    
    @State private var quickRange: QuickRange = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false
    
    enum ReportDateRange {
        case today
        case thisWeek
        case thisMonth
        case custom(start: Date, end: Date)
    }
    
    var activeRange: ReportDateRange {
        switch quickRange {
        case .today:     return .today
        case .thisWeek:  return .thisWeek
        case .thisMonth: return .thisMonth
        case .custom:    return .custom(start: customStart, end: customEnd)
        }
    }
    
    private func dateInterval(for range: ReportDateRange) -> (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .today:
            return (cal.startOfDay(for: now),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .thisWeek:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .day, value: 6, to: start)?.addingTimeInterval(-1) ?? now)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now)
        case .custom(let s, let e):
            return (cal.startOfDay(for: s),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e)
        }
    }
    
    private var rangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM"
        switch quickRange {
        case .today:
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        case .thisWeek:
            let cal = Calendar.current
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            let start = cal.date(from: comps) ?? Date()
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? Date()
            return "\(df.string(from: start)) – \(df.string(from: end))"
        case .thisMonth:
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "MM/yyyy"
            return "Tháng \(f.string(from: Date()))"
        case .custom:
            return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
        }
    }
    
    // MARK: - Filtered Data
    private var filteredRestockBills: [RestockBill] {
        let (start, end) = dateInterval(for: activeRange)
        return viewModel.restockHistory.filter { bill in
            !bill.isDeleted && bill.createdAt >= start && bill.createdAt <= end
        }
    }
    
    // MARK: - Inventory Stats
    private var currentProductCount: Int {
        viewModel.products.filter { !$0.isFinishedGood }.count
    }
    
    private var currentInventoryValue: Double {
        viewModel.products.filter { !$0.isFinishedGood }
            .reduce(0.0) { acc, product in
                acc + Double(product.stockQuantity) * product.costPrice
            }
    }
    
    // MARK: - Export Report (Xuất kho - from sales orders (pastOrders))
    @State private var showExportReport = false
    
    private var filteredExportOrders: [Bill] {
        let (start, end) = dateInterval(for: activeRange)
        return viewModel.pastOrders.filter { bill in bill.createdAt >= start && bill.createdAt <= end }
    }
    
    private var exportBillCount: Int { filteredExportOrders.count }
    private var exportRevenue: Double { 
        filteredExportOrders.reduce(0.0) { acc, bill in
            acc + bill.total
        }
    }
    private var exportVatCount: Int { 0 } // Since Bill doesn't have VAT fields yet
    private var exportTotalVat: Double { 0.0 }
    
    // MARK: - Import Report (Nhập kho - from RestockBill)
    @State private var showImportReport = false
    
    private var importBillCount: Int { filteredRestockBills.count }
    private var importTotalCost: Double { 
        filteredRestockBills.reduce(0.0) { acc, bill in
            acc + bill.totalCost
        }
    }
    private var importVatCount: Int { 
        filteredRestockBills.filter { bill in bill.items.contains { item in item.hasVAT } }.count 
    }
    private var importTotalVat: Double {
        filteredRestockBills.reduce(0.0) { total, bill in
            total + bill.items.reduce(0.0) { itemTotal, item in
                itemTotal + (item.hasVAT ? (item.unitPrice * Double(item.quantity) * 0.1) : 0.0)
            }
        }
    }
    
    // MARK: - Helpers
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        return formatter.string(from: NSNumber(value: amount)) ?? "0 đ"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Filter
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickRange.allCases, id: \.self) { r in
                                Button {
                                    quickRange = r
                                    if r == .custom { showCustomPicker = true }
                                } label: {
                                    Text(r.rawValue)
                                        .font(.caption)
                                        .fontWeight(quickRange == r ? .semibold : .regular)
                                        .foregroundStyle(quickRange == r ? .white : Color.themeTextDark)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(quickRange == r ? Color.themePrimary : Color.white)
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                quickRange == r ? Color.clear : Color.gray.opacity(0.2),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(Color.themePrimary)
                        Text(rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        if quickRange == .custom {
                            Button {
                                showCustomPicker = true
                            } label: {
                                Text("Đổi ngày")
                                    .font(.caption)
                                    .foregroundStyle(Color.themePrimary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(Color.white)
                
                Divider()
                
                // Report Cards
                ScrollView {
                    VStack(spacing: 14) {
                        // Export Report Card (Xuất kho)
                        Button {
                            showExportReport = true
                        } label: {
                            exportReportCard()
                        }
                        .buttonStyle(.plain)
                        
                        // Import Report Card (Nhập kho)
                        Button {
                            showImportReport = true
                        } label: {
                            importReportCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .background(Color.themeBackgroundLight)
            }
            .navigationTitle("Báo cáo kho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showInfoSheet = true }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                }
            }

            .sheet(isPresented: $showCustomPicker) {
                NavigationStack {
                    Form {
                        Section(header: Text("Chọn khoảng thời gian")) {
                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Tuỳ chọn ngày")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") { showCustomPicker = false }
                                .fontWeight(.bold)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") {
                                quickRange = .thisMonth
                                showCustomPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showExportReport) {
                InventoryExportReportView(viewModel: viewModel, allOrders: viewModel.pastOrders)
            }
            .sheet(isPresented: $showImportReport) {
                InventoryImportReportView(viewModel: viewModel, allBills: viewModel.restockHistory.filter { !$0.isDeleted })
            }
            .sheet(isPresented: $showInfoSheet) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Xuất kho section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Báo cáo xuất kho")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themeTextDark)
                                
                                infoRow(title: "Số đơn hàng", desc: "Tổng số đơn hàng bán lẻ trong khoảng thời gian đã chọn")
                                infoRow(title: "Tổng doanh thu", desc: "Tổng doanh thu từ tất cả đơn hàng trong khoảng thời gian đã chọn")
                                infoRow(title: "Số hàng hóa hiện tại", desc: "Số loại hàng hóa hiện có trong kho (không bao gồm thành phẩm)")
                                infoRow(title: "Giá trị tồn kho", desc: "Tổng giá trị hàng hóa hiện có trong kho (tính theo giá vốn)")
                            }
                            
                            Divider()
                            
                            // Nhập kho section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Báo cáo nhập kho")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themeTextDark)
                                
                                infoRow(title: "Số phiếu nhập", desc: "Tổng số phiếu nhập hàng trong khoảng thời gian đã chọn")
                                infoRow(title: "Tổng chi phí", desc: "Tổng chi phí nhập hàng trong khoảng thời gian đã chọn")
                                infoRow(title: "Phiếu có VAT", desc: "Số phiếu nhập hàng có ít nhất một mặt hàng có VAT")
                                infoRow(title: "Tổng VAT", desc: "Tổng giá trị VAT từ tất cả các mặt hàng trong các phiếu nhập")
                            }
                        }
                        .padding()
                    }
                    .background(Color.themeBackgroundLight)
                    .navigationTitle("Chú ý nghĩa các trường")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showInfoSheet = false }
                        }
                    }
                }
            }
            .alert(selectedFieldInfo?.title ?? "Giải thích", isPresented: Binding(
                get: { selectedFieldInfo != nil },
                set: { _ in selectedFieldInfo = nil }
            )) {
                Button("Đóng", role: .cancel) { }
            } message: {
                Text(selectedFieldInfo?.desc ?? "")
            }
        }
    }
    
    private func infoRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.themePrimary)
            Text(desc)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }
    
    // MARK: - Export Report Card
    @ViewBuilder
    private func exportReportCard() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "tray.and.arrow.up.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Báo cáo xuất kho")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text("Xuất hàng hóa / bán lẻ")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().padding(.horizontal, 16)
            
            // Summary 6 columns
            HStack(spacing: 0) {
                summaryCol(label: "Số hàng hóa hiện tại", value: "\(currentProductCount)")
                Divider().frame(height: 40)
                summaryCol(label: "Giá trị tồn kho", value: formatCurrency(currentInventoryValue))
                Divider().frame(height: 40)
                summaryCol(label: "Số đơn hàng", value: "\(exportBillCount)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            
            Divider().padding(.horizontal, 16)
            
            HStack(spacing: 0) {
                summaryCol(label: "Doanh thu", value: formatCurrency(exportRevenue))
                Divider().frame(height: 40)
                summaryCol(label: "Phiếu có VAT", value: "—")
                Divider().frame(height: 40)
                summaryCol(label: "Giá trị VAT", value: "—")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Import Report Card
    @ViewBuilder
    private func importReportCard() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Báo cáo nhập kho")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text("Nhập hàng hóa từ nhà cung cấp")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().padding(.horizontal, 16)
            
            // Summary 6 columns
            HStack(spacing: 0) {
                summaryCol(label: "Số hàng hóa hiện tại", value: "\(currentProductCount)")
                Divider().frame(height: 40)
                summaryCol(label: "Giá trị tồn kho", value: formatCurrency(currentInventoryValue))
                Divider().frame(height: 40)
                summaryCol(label: "Số phiếu nhập", value: "\(importBillCount)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            
            Divider().padding(.horizontal, 16)
            
            HStack(spacing: 0) {
                summaryCol(label: "Tổng chi phí", value: formatCurrency(importTotalCost))
                Divider().frame(height: 40)
                summaryCol(label: "Phiếu có VAT", value: "\(importVatCount)")
                Divider().frame(height: 40)
                summaryCol(label: "Giá trị VAT", value: formatCurrency(importTotalVat))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func summaryCol(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                if let explanation = fieldExplanations[label] {
                    Button(action: {
                        selectedFieldInfo = explanation
                    }) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(Color.themePrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(value == "—" ? Color.gray.opacity(0.35) : Color.themeTextDark)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

// MARK: - Product Import Model
struct ProductImport: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let totalCost: Double
}

// MARK: - Inventory Import Report View
struct InventoryImportReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    let allBills: [RestockBill]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRestockBill: RestockBill? = nil
    @State private var showNewRestock = false // dummy binding for RestockDetailView
    
    // Filters
    enum TimeFilter: String, CaseIterable {
        case today = "Hôm nay"
        case week = "Tuần này"
        case month = "Tháng này"
        case custom = "Tuỳ chọn"
    }
    @State private var timeFilter: TimeFilter = .today
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showCustomDatePicker = false
    enum VATFilter: String, CaseIterable {
        case all = "Tất cả"
        case hasVAT = "Có VAT"
        case noVAT = "Không VAT"
    }
    @State private var vatFilter: VATFilter = .all
    @State private var filterCreator = ""
    @State private var filterSupplier = ""
    @State private var showCreatorPicker = false
    @State private var showSupplierPicker = false
    @State private var showTopProducts = false
    
    private var creators: [String] {
        Array(Set(allBills.compactMap { $0.creatorName }.filter { !$0.isEmpty })).sorted()
    }
    
    private var suppliers: [String] {
        Array(Set(allBills.compactMap { $0.supplierName }.filter { !$0.isEmpty })).sorted()
    }
    
    private var dateInterval: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch timeFilter {
        case .today:
            let start = cal.startOfDay(for: now)
            return (start, now)
        case .week:
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (start, now)
        case .custom:
            return (cal.startOfDay(for: customStartDate), cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate)
        }
    }
    
    private var filteredBills: [RestockBill] {
        var result = allBills
        
        // Time filter
        let (start, end) = dateInterval
        result = result.filter { $0.createdAt >= start && $0.createdAt <= end }
        
        // Creator filter
        if !filterCreator.isEmpty {
            result = result.filter { $0.creatorName == filterCreator }
        }
        
        // Supplier filter
        if !filterSupplier.isEmpty {
            result = result.filter { $0.supplierName == filterSupplier }
        }
        
        // VAT filter
        switch vatFilter {
        case .all:
            break
        case .hasVAT:
            result = result.filter { bill in bill.items.contains { item in item.hasVAT } }
        case .noVAT:
            result = result.filter { bill in !bill.items.contains { item in item.hasVAT } }
        }
        
        return result
    }
    
    private var timeRangeLabel: String {
        switch timeFilter {
        case .today: return "Hôm nay"
        case .week: return "Tuần này"
        case .month: return "Tháng này"
        case .custom:
            let df = DateFormatter()
            df.locale = Locale(identifier: "vi_VN")
            df.dateFormat = "dd/MM/yyyy"
            return "\(df.string(from: customStartDate)) - \(df.string(from: customEndDate))"
        }
    }
    
    private var productImports: [ProductImport] {
        var importMap: [String: (quantity: Int, totalCost: Double)] = [:]
        
        for bill in filteredBills {
            for item in bill.items {
                let key = item.name
                let current = importMap[key] ?? (0, 0)
                importMap[key] = (
                    quantity: current.quantity + item.quantity,
                    totalCost: current.totalCost + item.unitPrice * Double(item.quantity)
                )
            }
        }
        
        return importMap.map { name, data in
            ProductImport(name: name, quantity: data.quantity, totalCost: data.totalCost)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        return formatter.string(from: NSNumber(value: amount)) ?? "0 đ"
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM/yyyy HH:mm"
        return df.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Filters
                    VStack(spacing: 12) {
                        // Time filter
                        HStack {
                            Text("Thời gian")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Picker("", selection: $timeFilter) {
                                ForEach(TimeFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        if timeFilter == .custom {
                            HStack {
                                Text(timeRangeLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.themePrimary)
                                Spacer()
                                Button("Đổi ngày") {
                                    showCustomDatePicker = true
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        // Creator and Supplier filters
                        HStack {
                            Button(action: { showCreatorPicker = true }) {
                                HStack {
                                    Text(filterCreator.isEmpty ? "Người tạo" : filterCreator)
                                        .font(.subheadline)
                                        .foregroundStyle(filterCreator.isEmpty ? .gray : .primary)
                                    if !filterCreator.isEmpty {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .onLongPressGesture {
                                filterCreator = ""
                            }
                            
                            Button(action: { showSupplierPicker = true }) {
                                HStack {
                                    Text(filterSupplier.isEmpty ? "Cơ sở cung cấp" : filterSupplier)
                                        .font(.subheadline)
                                        .foregroundStyle(filterSupplier.isEmpty ? .gray : .primary)
                                    if !filterSupplier.isEmpty {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .onLongPressGesture {
                                filterSupplier = ""
                            }
                        }
                        
                        // VAT filter
                        HStack {
                            Text("VAT")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Picker("", selection: $vatFilter) {
                                ForEach(VATFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        InventoryStatCard(
                            title: "Số phiếu nhập",
                            value: "\(filteredBills.count)",
                            icon: "doc.text",
                            color: .green
                        )
                        InventoryStatCard(
                            title: "Tổng chi phí",
                            value: formatCurrency(filteredBills.reduce(0.0) { acc, bill in
                                acc + bill.totalCost
                            }),
                            icon: "creditcard",
                            color: .blue
                        )
                        InventoryStatCard(
                            title: "Phiếu có VAT",
                            value: "\(filteredBills.filter { bill in bill.items.contains { item in item.hasVAT } }.count)",
                            icon: "checkmark.seal",
                            color: .orange
                        )
                        InventoryStatCard(
                            title: "Tổng VAT",
                            value: formatCurrency(filteredBills.reduce(0.0) { total, bill in
                                total + bill.items.reduce(0.0) { itemTotal, item in
                                    itemTotal + (item.hasVAT ? (item.unitPrice * Double(item.quantity) * 0.1) : 0.0)
                                }
                            }),
                            icon: "percent",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Top Products Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "chart.bar.fill")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.green)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Top sản phẩm nhập nhiều")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themeTextDark)
                                Text("Xem chi tiết top sản phẩm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTopProducts = true
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Bill List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Danh sách phiếu nhập")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
                            .padding(.horizontal)
                        
                        if filteredBills.isEmpty {
                            Text("Không có dữ liệu")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(filteredBills.sorted(by: { $0.createdAt > $1.createdAt })) { bill in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(formatDate(bill.createdAt))
                                            .font(.subheadline)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Text(formatCurrency(bill.totalCost))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.themePrimary)
                                    }
                                    
                                    if let creator = bill.creatorName, !creator.isEmpty {
                                        HStack {
                                            Text(creator)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                            if let supplier = bill.supplierName, !supplier.isEmpty {
                                                Text("• \(supplier)")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray.opacity(0.7))
                                            }
                                        }
                                    } else if let supplier = bill.supplierName, !supplier.isEmpty {
                                        Text(supplier)
                                            .font(.caption)
                                            .foregroundStyle(.gray.opacity(0.7))
                                    }
                                    
                                    Text("\(bill.items.count) mặt hàng")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestockBill = bill
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Báo cáo nhập kho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .sheet(item: $selectedRestockBill) { bill in
                RestockDetailView(
                    bill: bill,
                    viewModel: viewModel,
                    showNewRestock: $showNewRestock
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCustomDatePicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        DatePicker("Từ ngày", selection: $customStartDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        DatePicker("Đến ngày", selection: $customEndDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .navigationTitle("Chọn khoảng thời gian")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCustomDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showCreatorPicker) {
                NavigationStack {
                    List {
                        Button("Tất cả") {
                            filterCreator = ""
                            showCreatorPicker = false
                        }
                        ForEach(creators, id: \.self) { creator in
                            Button(creator) {
                                filterCreator = creator
                                showCreatorPicker = false
                            }
                        }
                    }
                    .navigationTitle("Người tạo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCreatorPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSupplierPicker) {
                NavigationStack {
                    List {
                        Button("Tất cả") {
                            filterSupplier = ""
                            showSupplierPicker = false
                        }
                        ForEach(suppliers, id: \.self) { supplier in
                            Button(supplier) {
                                filterSupplier = supplier
                                showSupplierPicker = false
                            }
                        }
                    }
                    .navigationTitle("Cơ sở cung cấp")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showSupplierPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showTopProducts) {
                TopImportProductsView(productImports: productImports, formatCurrency: formatCurrency)
            }
        }
    }
}

// MARK: - Top Import Products View
struct TopImportProductsView: View {
    let productImports: [ProductImport]
    let formatCurrency: (Double) -> String
    @Environment(\.dismiss) private var dismiss
    enum SortBy: String, CaseIterable {
        case totalCost = "Tổng chi phí"
        case quantity = "Số lượng"
    }
    @State private var sortBy: SortBy = .totalCost
    
    private var sortedProducts: [ProductImport] {
        switch sortBy {
        case .totalCost:
            return productImports.sorted { $0.totalCost > $1.totalCost }
        case .quantity:
            return productImports.sorted { $0.quantity > $1.quantity }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sort Picker
                HStack {
                    Text("Sắp xếp theo")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Picker("", selection: $sortBy) {
                        ForEach(SortBy.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.white)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 8) {
                        if sortedProducts.isEmpty {
                            Text("Không có dữ liệu")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(Array(sortedProducts.enumerated()), id: \.element.id) { index, product in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(index < 3 ? Color.themePrimary : .gray)
                                        .frame(width: 30, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.themeTextDark)
                                        Text("\(product.quantity) sản phẩm")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(product.totalCost))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Top sản phẩm nhập nhiều")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Product Sale Model
struct ProductSale: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let revenue: Double
}

// MARK: - Inventory Export Report View (Sales Orders)
struct InventoryExportReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    let allOrders: [Bill]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBill: Bill? = nil
    
    // Filters
    enum TimeFilter: String, CaseIterable {
        case today = "Hôm nay"
        case week = "Tuần này"
        case month = "Tháng này"
        case custom = "Tuỳ chọn"
    }
    @State private var timeFilter: TimeFilter = .today
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showCustomDatePicker = false
    enum VATFilter: String, CaseIterable {
        case all = "Tất cả"
        case hasVAT = "Có VAT"
        case noVAT = "Không VAT"
    }
    @State private var vatFilter: VATFilter = .all
    @State private var filterCreator = ""
    @State private var filterCustomer = ""
    @State private var showCreatorPicker = false
    @State private var showCustomerPicker = false
    @State private var showTopProducts = false
    
    private var creators: [String] {
        Array(Set(allOrders.compactMap { $0.creatorName }.filter { !$0.isEmpty })).sorted()
    }
    
    private var customers: [String] {
        Array(Set(allOrders.compactMap { $0.customerName }.filter { !$0.isEmpty })).sorted()
    }
    
    private var dateInterval: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch timeFilter {
        case .today:
            let start = cal.startOfDay(for: now)
            return (start, now)
        case .week:
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (start, now)
        case .custom:
            return (cal.startOfDay(for: customStartDate), cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate)
        }
    }
    
    private var filteredOrders: [Bill] {
        var result = allOrders
        
        // Time filter
        let (start, end) = dateInterval
        result = result.filter { $0.createdAt >= start && $0.createdAt <= end }
        
        // Creator filter
        if !filterCreator.isEmpty {
            result = result.filter { $0.creatorName == filterCreator }
        }
        
        // Customer filter
        if !filterCustomer.isEmpty {
            result = result.filter { $0.customerName == filterCustomer }
        }
        
        // VAT filter - Note: currently Bill has no VAT fields, so we skip this for now
        // switch vatFilter {
        // case .all: break
        // case .hasVAT: result = result.filter { ... }
        // case .noVAT: result = result.filter { ... }
        // }
        
        return result
    }
    
    private var timeRangeLabel: String {
        switch timeFilter {
        case .today: return "Hôm nay"
        case .week: return "Tuần này"
        case .month: return "Tháng này"
        case .custom:
            let df = DateFormatter()
            df.locale = Locale(identifier: "vi_VN")
            df.dateFormat = "dd/MM/yyyy"
            return "\(df.string(from: customStartDate)) - \(df.string(from: customEndDate))"
        }
    }
    
    private var productSales: [ProductSale] {
        var salesMap: [String: (quantity: Int, revenue: Double)] = [:]
        
        for order in filteredOrders {
            for item in order.items {
                let key = item.name
                let current = salesMap[key] ?? (0, 0)
                salesMap[key] = (
                    quantity: current.quantity + item.quantity,
                    revenue: current.revenue + item.price * Double(item.quantity)
                )
            }
        }
        
        return salesMap.map { name, data in
            ProductSale(name: name, quantity: data.quantity, revenue: data.revenue)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        return formatter.string(from: NSNumber(value: amount)) ?? "0 đ"
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM/yyyy HH:mm"
        return df.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Filters
                    VStack(spacing: 12) {
                        // Time filter
                        HStack {
                            Text("Thời gian")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Picker("", selection: $timeFilter) {
                                ForEach(TimeFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        if timeFilter == .custom {
                            HStack {
                                Text(timeRangeLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.themePrimary)
                                Spacer()
                                Button("Đổi ngày") {
                                    showCustomDatePicker = true
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        // Creator and Customer filters
                        HStack {
                            Button(action: { showCreatorPicker = true }) {
                                HStack {
                                    Text(filterCreator.isEmpty ? "Người tạo" : filterCreator)
                                        .font(.subheadline)
                                        .foregroundStyle(filterCreator.isEmpty ? .gray : .primary)
                                    if !filterCreator.isEmpty {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .onLongPressGesture {
                                filterCreator = ""
                            }
                            
                            Button(action: { showCustomerPicker = true }) {
                                HStack {
                                    Text(filterCustomer.isEmpty ? "Người mua" : filterCustomer)
                                        .font(.subheadline)
                                        .foregroundStyle(filterCustomer.isEmpty ? .gray : .primary)
                                    if !filterCustomer.isEmpty {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .onLongPressGesture {
                                filterCustomer = ""
                            }
                        }
                        
                        // VAT filter (disabled for now since Bill has no VAT)
                        HStack {
                            Text("VAT")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Picker("", selection: $vatFilter) {
                                ForEach(VATFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(true)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        InventoryStatCard(
                            title: "Số đơn hàng",
                            value: "\(filteredOrders.count)",
                            icon: "doc.text",
                            color: .orange
                        )
                        InventoryStatCard(
                            title: "Tổng doanh thu",
                            value: formatCurrency(filteredOrders.reduce(0.0) { acc, bill in
                                acc + bill.total
                            }),
                            icon: "creditcard",
                            color: .blue
                        )
                        InventoryStatCard(
                            title: "Số hàng hóa hiện tại",
                            value: "\(viewModel.products.filter { !$0.isFinishedGood }.count)",
                            icon: "cube.box",
                            color: .green
                        )
                        InventoryStatCard(
                            title: "Giá trị tồn kho",
                            value: formatCurrency(viewModel.products.filter { !$0.isFinishedGood }.reduce(0.0) { acc, product in
                                acc + Double(product.stockQuantity) * product.costPrice
                            }),
                            icon: "banknote",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Top Products Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "chart.bar.fill")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.blue)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Top sản phẩm bán chạy")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themeTextDark)
                                Text("Xem chi tiết top sản phẩm")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTopProducts = true
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Order List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Danh sách đơn hàng")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
                            .padding(.horizontal)
                        
                        if filteredOrders.isEmpty {
                            Text("Không có dữ liệu")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(filteredOrders.sorted(by: { $0.createdAt > $1.createdAt })) { bill in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(formatDate(bill.createdAt))
                                            .font(.subheadline)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Text(formatCurrency(bill.total))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.themePrimary)
                                    }
                                    
                                    if let creator = bill.creatorName, !creator.isEmpty {
                                        HStack {
                                            Text(creator)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                            if let customer = bill.customerName, !customer.isEmpty {
                                                Text("• \(customer)")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray.opacity(0.7))
                                            }
                                        }
                                    } else if let customer = bill.customerName, !customer.isEmpty {
                                        Text(customer)
                                            .font(.caption)
                                            .foregroundStyle(.gray.opacity(0.7))
                                    }
                                    
                                    Text("\(bill.items.count) mặt hàng")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBill = bill
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Báo cáo xuất kho (bán lẻ)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, viewModel: viewModel)
            }
            .sheet(isPresented: $showCustomDatePicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        DatePicker("Từ ngày", selection: $customStartDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        DatePicker("Đến ngày", selection: $customEndDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .navigationTitle("Chọn khoảng thời gian")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCustomDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showCreatorPicker) {
                NavigationStack {
                    List {
                        Button("Tất cả") {
                            filterCreator = ""
                            showCreatorPicker = false
                        }
                        ForEach(creators, id: \.self) { creator in
                            Button(creator) {
                                filterCreator = creator
                                showCreatorPicker = false
                            }
                        }
                    }
                    .navigationTitle("Người tạo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCreatorPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showCustomerPicker) {
                NavigationStack {
                    List {
                        Button("Tất cả") {
                            filterCustomer = ""
                            showCustomerPicker = false
                        }
                        ForEach(customers, id: \.self) { customer in
                            Button(customer) {
                                filterCustomer = customer
                                showCustomerPicker = false
                            }
                        }
                    }
                    .navigationTitle("Người mua")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") { showCustomerPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showTopProducts) {
                TopProductsView(productSales: productSales, formatCurrency: formatCurrency)
            }
        }
    }
}

// MARK: - Top Products View
struct TopProductsView: View {
    let productSales: [ProductSale]
    let formatCurrency: (Double) -> String
    @Environment(\.dismiss) private var dismiss
    enum SortBy: String, CaseIterable {
        case revenue = "Doanh số"
        case quantity = "Số lượng"
    }
    @State private var sortBy: SortBy = .revenue
    
    private var sortedProducts: [ProductSale] {
        switch sortBy {
        case .revenue:
            return productSales.sorted { $0.revenue > $1.revenue }
        case .quantity:
            return productSales.sorted { $0.quantity > $1.quantity }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sort Picker
                HStack {
                    Text("Sắp xếp theo")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Picker("", selection: $sortBy) {
                        ForEach(SortBy.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.white)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 8) {
                        if sortedProducts.isEmpty {
                            Text("Không có dữ liệu")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(Array(sortedProducts.enumerated()), id: \.element.id) { index, product in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(index < 3 ? Color.themePrimary : .gray)
                                        .frame(width: 30, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.themeTextDark)
                                        Text("\(product.quantity) sản phẩm")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(product.revenue))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.themePrimary)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Top sản phẩm bán chạy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stat Card for Report
private struct InventoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
