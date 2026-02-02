import SwiftUI

struct GoodsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @StateObject private var authManager = AuthManager.shared
    @State private var showingAddProduct = false
    @State private var editingProduct: Product?
    @State private var searchText = ""
    @State private var productToDelete: Product?
    @State private var showDeleteConfirmation = false
    
    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return Category.allCases.filter { $0 != .all }
        } else {
            // Find categories that contain matching products
            return Category.allCases.filter { $0 != .all && hasMatchingProducts(in: $0) }
        }
    }
    
    func hasMatchingProducts(in category: Category) -> Bool {
        return viewModel.products.contains { product in
            product.category == category.rawValue &&
            product.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func filteredProducts(in category: Category) -> [Product] {
        return viewModel.products.filter { product in
            product.category == category.rawValue &&
            (searchText.isEmpty || product.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        NavigationStack {
            if !StoreManager.shared.hasPermission(.viewInventory) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    Text("Bạn không có quyền xem hàng hóa")
                        .font(.headline)
                        .foregroundStyle(Color.gray)
                }
            } else {
                List {
                    ForEach(filteredCategories, id: \.self) { category in
                    Section(header: Text(category.displayName)) {
                        ForEach(filteredProducts(in: category)) { product in
                            Button(action: { editingProduct = product }) {
                                HStack {
                                    ZStack {
                                        if let data = product.imageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(colorForString(product.color).opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: product.imageName)
                                                .foregroundStyle(colorForString(product.color))
                                        }
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(product.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        HStack {
                                            Text(formatCurrency(product.price))
                                            Text("•")
                                            Text("Kho: \(viewModel.stockLevel(for: product.name))")
                                                .fontWeight(.medium)
                                                .foregroundStyle(viewModel.stockLevel(for: product.name) > 0 ? Color.blue : Color.red)
                                        }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    productToDelete = product
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hàng hóa")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tìm kiếm...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isDatabaseConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isDatabaseConnected ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddProduct = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProduct) {
                ProductEditView(viewModel: viewModel, mode: .add)
            }
            .sheet(item: $editingProduct) { product in
                ProductEditView(viewModel: viewModel, mode: .edit(product))
            }
            .alert("Xóa mặt hàng?", isPresented: $showDeleteConfirmation, presenting: productToDelete) { product in
                Button("Xóa", role: .destructive) {
                    viewModel.deleteProduct(product)
                }
                Button("Hủy", role: .cancel) {}
            } message: { product in
                Text("Bạn có chắc muốn xóa '\(product.name)'? Hành động này không thể hoàn tác.")
            }
            }
        }
    }
}
