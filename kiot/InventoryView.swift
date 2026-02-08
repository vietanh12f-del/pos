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
    @State private var showBarcodeScanner = false
    @State private var productToPrint: Product?
    
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
                
                // Content
                if selectedTab == 0 {
                    // Goods List
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredProducts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "cube.box")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Text("Chưa có hàng hóa")
                                .font(.headline)
                                .foregroundStyle(Color.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                        
                                        // Name & Category
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(product.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.themeTextDark)
                                                .lineLimit(2)
                                            
                                            Text(product.category)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Selling Price
                                        Text(formatCurrency(product.price))
                                            .font(.subheadline)
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
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(product.stockQuantity > 0 ? Color.themePrimary : Color.red)
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
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
                        .refreshable {
                            await viewModel.loadData(force: true)
                        }
                    }
                } else {
                    // Restock History List
                    if viewModel.restockHistory.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Text("Chưa có lịch sử nhập hàng")
                                .font(.headline)
                                .foregroundStyle(Color.gray)
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
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.red)
                                            
                                            Text("\(bill.items.count) mặt hàng")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color.white)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await viewModel.loadData()
                        }
                    }
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Kho hàng hóa")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Removed redundant Plus button as per user request
                    EmptyView()
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
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(onScan: { code in
                    searchText = code
                    showBarcodeScanner = false // Dismiss automatically
                })
            }
            .sheet(item: $productToPrint) { product in
                BarcodePrintView(product: product)
            }
        }
    }
}
