import SwiftUI

struct InventoryListView: View {
    let products: [Product]
    
    @State private var searchText = ""
    @State private var selectedCategory = "Tất cả"
    @State private var sortOption: InventorySortOption = .name
    @Environment(\.dismiss) private var dismiss
    
    enum InventorySortOption: String, CaseIterable {
        case name = "Tên"
        case stockQuantity = "Tồn kho"
        case costPrice = "Giá vốn"
        case totalValue = "Tổng giá trị"
    }
    
    private var categories: [String] {
        let allCategories = products.compactMap { $0.category.isEmpty ? nil : $0.category }.unique()
        return ["Tất cả"] + allCategories.sorted()
    }
    
    private var filteredProducts: [Product] {
        var filtered = products
        
        // Lọc theo danh mục
        if selectedCategory != "Tất cả" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Lọc theo từ khóa tìm kiếm
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.barcode?.localizedCaseInsensitiveContains(searchText) == true ||
                product.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sắp xếp
        switch sortOption {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .stockQuantity:
            return filtered.sorted { $0.stockQuantity > $1.stockQuantity }
        case .costPrice:
            return filtered.sorted { $0.costPrice > $1.costPrice }
        case .totalValue:
            return filtered.sorted { (Double($0.stockQuantity) * $0.costPrice) > (Double($1.stockQuantity) * $1.costPrice) }
        }
    }
    
    private var inventoryStats: (totalItems: Int, totalValue: Double, lowStockItems: Int) {
        let totalItems = products.count
        let totalValue = products.reduce(0) { $0 + (Double($1.stockQuantity) * $1.costPrice) }
        let lowStockItems = products.filter { $0.stockQuantity <= 5 }.count
        
        return (totalItems, totalValue, lowStockItems)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header thống kê tóm tắt
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng mặt hàng")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(inventoryStats.totalItems)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tổng giá trị")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(inventoryStats.totalValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sắp hết hàng")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(inventoryStats.lowStockItems)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(inventoryStats.lowStockItems > 0 ? .red : .green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Hiển thị")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(filteredProducts.count)")
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
                    
                    // Bộ lọc danh mục và sắp xếp
                    HStack(spacing: 12) {
                        // Danh mục
                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    HStack {
                                        Text(category)
                                        if category == selectedCategory {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text(selectedCategory)
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
                        
                        Spacer()
                        
                        // Sắp xếp
                        Menu {
                            ForEach(InventorySortOption.allCases, id: \.self) { option in
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
                        Image(systemName: searchText.isEmpty ? "archivebox" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "Không có sản phẩm nào trong kho" : "Không tìm thấy sản phẩm nào")
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
                        ForEach(filteredProducts) { product in
                            InventoryRow(product: product)
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
            .navigationTitle("Danh sách tồn kho")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct InventoryRow: View {
    let product: Product
    
    private var totalValue: Double {
        Double(product.stockQuantity) * product.costPrice
    }
    
    private var stockStatus: (text: String, color: Color) {
        if product.stockQuantity <= 0 {
            return ("Hết hàng", .red)
        } else if product.stockQuantity <= 5 {
            return ("Sắp hết", .orange)
        } else if product.stockQuantity <= 10 {
            return ("Ít hàng", .yellow)
        } else {
            return ("Còn hàng", .green)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header với tên sản phẩm và trạng thái
            HStack {
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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stockStatus.color)
                            .frame(width: 6, height: 6)
                        Text(stockStatus.text)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(stockStatus.color)
                    }
                }
            }
            
            // Thông tin số lượng và giá
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(Color.themePrimary)
                        Text("Tồn kho:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text("\(product.stockQuantity)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themeTextDark)
                    }
                    
                    if AuthManager.shared.canViewCostPrice {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Giá vốn:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(product.costPrice))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tổng giá trị")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    
                    if AuthManager.shared.canViewCostPrice {
                        Text(formatCurrency(totalValue))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    } else {
                        Text("***")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                    }
                }
            }
            
            // Barcode (nếu có)
            if let barcode = product.barcode, !barcode.isEmpty {
                HStack {
                    Image(systemName: "barcode")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(barcode)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        return Array(Set(self))
    }
}

#Preview {
    InventoryListView(products: [])
}