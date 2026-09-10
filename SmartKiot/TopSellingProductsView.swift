import SwiftUI

struct TopSellingProduct: Identifiable {
    let id = UUID()
    let name: String
    let quantitySold: Int
    let revenue: Double
    let category: String
    let averagePrice: Double
    
    var revenuePerItem: Double {
        quantitySold > 0 ? revenue / Double(quantitySold) : 0
    }
}

struct TopSellingProductsView: View {
    let orders: [Bill]
    @State private var period = Period.month
    @State private var customStart = Calendar.current.startOfDay(for: Date())
    @State private var customEnd = Date()
    private enum Period: String, CaseIterable {
        case today = "Hôm nay", week = "Tuần này", month = "Tháng này", custom = "Tuỳ chọn"
    }
    private var selectedRange: ReportDateRange {
        switch period {
        case .today: return .today
        case .week: return .thisWeek
        case .month: return .thisMonth
        case .custom: return .custom(start: customStart, end: customEnd)
        }
    }
    private var interval: (Date, Date) { FinancialReportService.shared.getDateRange(selectedRange) }
    private var dateRange: String {
        let (start, end) = interval
        return "\(start.formatted(date: .numeric, time: .omitted)) – \(end.formatted(date: .numeric, time: .omitted))"
    }
    private var periodOrders: [Bill] {
        let (start, end) = interval
        return orders.filter { !$0.isDeleted && $0.createdAt >= start && $0.createdAt <= end }
    }
    
    @State private var searchText = ""
    @State private var sortOption: ProductSortOption = .quantitySold
    @State private var showOnlyTopProducts = false
    @Environment(\.dismiss) private var dismiss
    
    enum ProductSortOption: String, CaseIterable {
        case quantitySold = "Số lượng bán"
        case revenue = "Doanh thu"
        case name = "Tên sản phẩm"
        case averagePrice = "Giá trung bình"
    }
    
    private var topSellingProducts: [TopSellingProduct] {
        TopSellingProduct.summarize(periodOrders)
    }
    
    private var filteredProducts: [TopSellingProduct] {
        var filtered = topSellingProducts
        
        // Lọc theo từ khóa tìm kiếm
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if showOnlyTopProducts {
            filtered = Array(filtered.sorted {
                $0.quantitySold == $1.quantitySold ? $0.name < $1.name : $0.quantitySold > $1.quantitySold
            }.prefix(10))
        }
        return filtered.sorted {
            switch sortOption {
            case .quantitySold: return $0.quantitySold == $1.quantitySold ? $0.name < $1.name : $0.quantitySold > $1.quantitySold
            case .revenue: return $0.revenue == $1.revenue ? $0.name < $1.name : $0.revenue > $1.revenue
            case .name: return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            case .averagePrice: return $0.averagePrice == $1.averagePrice ? $0.name < $1.name : $0.averagePrice > $1.averagePrice
            }
        }
    }
    
    private var salesStats: (totalProducts: Int, totalQuantity: Int, totalRevenue: Double) {
        let totalProducts = topSellingProducts.count
        let totalQuantity = topSellingProducts.reduce(0) { $0 + $1.quantitySold }
        let totalRevenue = topSellingProducts.reduce(0) { $0 + $1.revenue }
        
        return (totalProducts, totalQuantity, totalRevenue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Khoảng thời gian", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal)
                if period == .custom {
                    VStack {
                        DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            .onChange(of: customStart) { date in if customEnd < date { customEnd = date } }
                        DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    }.padding(.horizontal)
                }
                // Header thống kê tóm tắt
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng sản phẩm")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(salesStats.totalProducts)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tổng số lượng bán")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(salesStats.totalQuantity)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Doanh thu từ bán hàng")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(salesStats.totalRevenue))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Khoảng thời gian")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(dateRange)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                .padding()
                
                Text("Tính cả đơn đã thu và chưa thu, không tính đơn đã xoá. Doanh thu sản phẩm sau giảm giá từng dòng, chưa gồm VAT và phí thu hộ.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
                // Bộ lọc và tìm kiếm
                VStack(spacing: 12) {
                    // Thanh tìm kiếm
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        
                        TextField("Tìm kiếm sản phẩm...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Bộ lọc và sắp xếp
                    HStack(spacing: 12) {
                        // Toggle top products
                        Button {
                            showOnlyTopProducts.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showOnlyTopProducts ? "star.fill" : "star")
                                Text("Top 10")
                            }
                            .font(.subheadline)
                            .foregroundStyle(showOnlyTopProducts ? .white : Color.themePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showOnlyTopProducts ? Color.themePrimary : Color.themePrimary.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        // Sắp xếp
                        Menu {
                            ForEach(ProductSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if option == sortOption {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortOption.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.themePrimary.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Danh sách sản phẩm
                if filteredProducts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "cart" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "Không có sản phẩm nào được bán" : "Không tìm thấy sản phẩm nào")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        
                        if !searchText.isEmpty {
                            Text("Thử tìm kiếm với từ khóa khác")
                                .font(.subheadline)
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                } else {
                    List {
                        ForEach(Array(filteredProducts.enumerated()), id: \.element.id) { index, product in
                            TopSellingProductMiniRow(product: product, rank: index + 1)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.themeBackgroundLight)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.themeBackgroundLight)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Sản phẩm bán chạy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TopSellingProductsView(
        orders: []
    )
}
extension TopSellingProduct {
    static func summarize(_ orders: [Bill]) -> [TopSellingProduct] {
        var totals: [String: (quantity: Int, revenue: Double)] = [:]
        for order in orders where !order.isDeleted {
            for item in order.items {
                let old = totals[item.name] ?? (0, 0)
                totals[item.name] = (old.quantity + item.quantity, old.revenue + item.total)
            }
        }
        return totals.map { name, values in
            TopSellingProduct(name: name, quantitySold: values.quantity, revenue: values.revenue,
                              category: "", averagePrice: values.quantity > 0 ? values.revenue / Double(values.quantity) : 0)
        }.sorted { $0.quantitySold == $1.quantitySold ? $0.name < $1.name : $0.quantitySold > $1.quantitySold }
    }
}
