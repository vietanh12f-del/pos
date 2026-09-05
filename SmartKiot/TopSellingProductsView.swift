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
    let dateRange: String
    
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
        var productStats: [String: (quantity: Int, revenue: Double, prices: [Double])] = [:]
        
        // Tính toán thống kê cho từng sản phẩm
        for order in orders {
            if order.isPaid && !order.isDeleted {
                for item in order.items {
                    let key = item.name
                    let current = productStats[key] ?? (quantity: 0, revenue: 0, prices: [])
                    
                    productStats[key] = (
                        quantity: current.quantity + item.quantity,
                        revenue: current.revenue + (Double(item.quantity) * item.price),
                        prices: current.prices + [item.price]
                    )
                }
            }
        }
        
        // Chuyển đổi thành TopSellingProduct
        return productStats.compactMap { (productName, stats) in
            let avgPrice = stats.prices.isEmpty ? 0 : stats.prices.reduce(0, +) / Double(stats.prices.count)
            
            return TopSellingProduct(
                name: productName,
                quantitySold: stats.quantity,
                revenue: stats.revenue,
                category: "", // Không có thông tin category từ OrderItem
                averagePrice: avgPrice
            )
        }
    }
    
    private var filteredProducts: [TopSellingProduct] {
        var filtered = topSellingProducts
        
        // Lọc theo từ khóa tìm kiếm
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Lọc top products nếu được bật
        if showOnlyTopProducts {
            filtered = Array(filtered.prefix(10))
        }
        
        // Sắp xếp
        switch sortOption {
        case .quantitySold:
            return filtered.sorted { $0.quantitySold > $1.quantitySold }
        case .revenue:
            return filtered.sorted { $0.revenue > $1.revenue }
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .averagePrice:
            return filtered.sorted { $0.averagePrice > $1.averagePrice }
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
                            TopSellingProductRow(product: product, rank: index + 1)
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

struct TopSellingProductRow: View {
    let product: TopSellingProduct
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "1.circle.fill"
        case 2: return "2.circle.fill"  
        case 3: return "3.circle.fill"
        default: return "\(rank).circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header với ranking và tên sản phẩm
            HStack {
                // Ranking
                Image(systemName: rankIcon)
                    .font(.title2)
                    .foregroundStyle(rankColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                        .lineLimit(2)
                    
                    if !product.category.isEmpty {
                        Text(product.category)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.quantitySold)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                    
                    Text("đã bán")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            // Thông tin chi tiết
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Doanh thu:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(formatCurrency(product.revenue))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Giá TB:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(formatCurrency(product.averagePrice))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themeTextDark)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Doanh thu/SP")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    
                    Text(formatCurrency(product.revenuePerItem))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    TopSellingProductsView(
        orders: [],
        dateRange: "01/01/2024 - 31/01/2024"
    )
}