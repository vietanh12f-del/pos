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
    
    enum DateFilterMode: String, CaseIterable, Identifiable {
        case all, today, yesterday, week, month, quarter, year, custom
        var id: String { rawValue }
    }
    @State private var dateFilterMode: DateFilterMode = .all
    @State private var customStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate: Date = Date()
    @State private var showCustomDateSheet: Bool = false
    
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
        if searchText.isEmpty {
            return viewModel.products
        } else {
            return viewModel.products.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.category.lowercased().contains(searchText.lowercased()) ||
                ($0.barcode?.contains(searchText) ?? false)
            }
        }
    }
    
    var filteredRestockHistory: [RestockBill] {
        let byDate = viewModel.restockHistory.filter { isDateInSelectedRange($0.createdAt) }
        if searchText.isEmpty {
            return byDate
        } else {
            return byDate.filter { bill in
                bill.items.contains { $0.name.lowercased().contains(searchText.lowercased()) }
            }
        }
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
                
                // Search Bar
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
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                HStack {
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
                .padding(.bottom, 8)
                
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
                            .padding(.top, 8)
                            
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
                                        Text(product.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.themeTextDark)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .layoutPriority(1)
                                        
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
                                    
                                    Text("\(product.stockQuantity)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(product.stockQuantity > 0 ? Color.themePrimary : Color.red)
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
                                    Button(role: .destructive) {
                                        productToDelete = product
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
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
                } else {
                    // Restock History List
                    HStack {
                        Menu {
                            Button("Hôm nay") { dateFilterMode = .today }
                            Button("Hôm qua") { dateFilterMode = .yesterday }
                            Button("Tuần") { dateFilterMode = .week }
                            Button("Tháng") { dateFilterMode = .month }
                            Button("Quý") { dateFilterMode = .quarter }
                            Button("Năm") { dateFilterMode = .year }
                            Button("Tùy chọn") { dateFilterMode = .custom; showCustomDateSheet = true }
                            Divider()
                            Button("Tất cả") { dateFilterMode = .all }
                        } label: {
                            Label("Lọc: \(dateFilterLabel)", systemImage: "calendar")
                                .foregroundColor(.orange)
                        }
                        if dateFilterMode == .custom {
                            Text("\(formatDate(customStartDate)) → \(formatDate(customEndDate))")
                                .font(.caption)
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
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Nhập hàng")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                            Text(formatDate(bill.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(formatCurrency(bill.totalCost))
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.red)
                                            Text("\(bill.items.count) mặt hàng")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
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
                                                    Text("Chi phí \(formatCurrency(item.additionalCost))")
                                                        .font(.caption2)
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background((item.additionalCost > 0 ? Color.orange : Color.gray).opacity(0.75))
                                                        .clipShape(Capsule())
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
                                    
                                    HStack {
                                        Spacer()
                                        Button {
                                            viewModel.editRestockBill(bill)
                                            DispatchQueue.main.async {
                                                showNewRestock = true
                                            }
                                        } label: {
                                            Text("Sửa")
                                                .font(.headline)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withTransaction(Transaction(animation: nil)) {
                                        selectedRestockBill = bill
                                    }
                                }
                                .listRowBackground(Color.white)
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
            .contentShape(Rectangle())
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
                ProductEditView(viewModel: viewModel, mode: .edit(product))
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
        }
    }
}

// MARK: - Print Helpers
private extension InventoryView {
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
struct InventoryFullPrintView: View {
    let products: [Product]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Danh sách sản phẩm")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Text("Sản phẩm").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Giá bán").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
                Text("Giá vốn").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 90, alignment: .trailing)
                Text("Kho").font(.subheadline).fontWeight(.bold).foregroundStyle(.gray)
                    .frame(width: 60, alignment: .trailing)
            }
            
            ForEach(products) { p in
                HStack(alignment: .top, spacing: 8) {
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
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phiếu nhập trống")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: 8) {
                Text("Ngày:")
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
            
            ForEach(products) { p in
                HStack(alignment: .top, spacing: 0) {
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
