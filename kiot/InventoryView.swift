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
    @State private var showProductEdit = false
    @State private var editingProduct: Product?
    @State private var showRestockDetail = false
    @State private var selectedRestockBill: RestockBill?
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return viewModel.products
        } else {
            return viewModel.products.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.category.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var filteredRestockHistory: [RestockBill] {
        // Simple search for restock history? Maybe by ID or items?
        // For now just return all, or filter by items names if needed.
        if searchText.isEmpty {
            return viewModel.restockHistory
        } else {
            return viewModel.restockHistory.filter { bill in
                bill.items.contains { $0.name.lowercased().contains(searchText.lowercased()) }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Text("Kho hàng hóa")
                        .font(.headline)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                }
                .padding()
                .background(Color.white)
                
                // Segmented Control
                Picker("Chế độ", selection: $selectedTab) {
                    Text("Hàng hóa").tag(0)
                    Text("Lịch sử nhập").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color.white)
                
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
                }
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.white)
                
                // Content
                if selectedTab == 0 {
                    // Goods List
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredProducts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                            Text("Chưa có hàng hóa")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Header Row
                            HStack {
                                Text("Sản phẩm")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Giá bán")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 80, alignment: .trailing)
                                
                                Text("Giá vốn")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 80, alignment: .trailing)
                                
                                Text("Kho")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            
                            ForEach(filteredProducts) { product in
                                Button(action: {
                                    editingProduct = product
                                    showProductEdit = true
                                }) {
                                    HStack(spacing: 12) {
                                        // Image
                                        if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: product.imageName)
                                                .font(.title2)
                                                .foregroundStyle(Color.themePrimary)
                                                .frame(width: 40, height: 40)
                                                .background(Color.themePrimary.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        // Name & Category
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(product.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                                .lineLimit(1)
                                            
                                            Text(product.category)
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Selling Price
                                        Text(formatCurrency(product.price))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.themeTextDark)
                                            .frame(width: 80, alignment: .trailing)
                                        
                                        // Cost Price
                                        Text(formatCurrency(product.costPrice))
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                            .frame(width: 80, alignment: .trailing)
                                        
                                        // Stock
                                        Text("\(product.stockQuantity)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(product.stockQuantity > 0 ? Color.themePrimary : Color.red)
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        productToDelete = product
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    // Restock History List
                    if viewModel.restockHistory.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                            Text("Chưa có lịch sử nhập hàng")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredRestockHistory) { bill in
                                Button(action: {
                                    selectedRestockBill = bill
                                    showRestockDetail = true
                                }) {
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
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.red) // Cost is negative/red usually, but here just color it distinct
                                            
                                            Text("\(bill.items.count) mặt hàng")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .background(Color.themeBackgroundLight)
            .toolbar(.hidden, for: .navigationBar) // Hide system nav bar
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
            }
            .sheet(isPresented: $showingAddProduct) {
                ProductEditView(viewModel: viewModel, mode: .add)
            }
            .sheet(item: $selectedRestockBill) { bill in
                // Restock Detail View
                VStack {
                    Text("Chi tiết phiếu nhập")
                        .font(.headline)
                        .padding()
                    List {
                        ForEach(bill.items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantity) x \(formatCurrency(item.unitPrice))")
                            }
                        }
                        HStack {
                            Text("Tổng cộng")
                                .fontWeight(.bold)
                            Spacer()
                            Text(formatCurrency(bill.totalCost))
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        }
    }
}
