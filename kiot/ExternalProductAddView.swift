import SwiftUI
import PhotosUI

struct ExternalProductAddView: View {
    let info: ExternalProductInfo
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var price: String = ""
    @State private var costPrice: String = ""
    @State private var quantity: String = "1"
    @State private var selectedImageData: Data?
    @State private var isLoadingImage = false
    
    init(info: ExternalProductInfo, viewModel: OrderViewModel) {
        self.info = info
        self.viewModel = viewModel
        _name = State(initialValue: info.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin sản phẩm")) {
                    if let imageURL = info.imageURL {
                        HStack {
                            Spacer()
                            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(8)
                            } else if isLoadingImage {
                                ProgressView()
                                    .frame(height: 150)
                            } else {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                    case .failure:
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundStyle(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 150)
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tên sản phẩm")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        TextField("Nhập tên sản phẩm", text: $name)
                    }
                    
                    HStack {
                        Text("Mã vạch:")
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(info.barcode)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Section(header: Text("Giá bán & Kho")) {
                    CurrencyTextField(title: "Giá bán (đ)", text: $price, font: .headline, foregroundStyle: Color.themePrimary)
                    
                    CurrencyTextField(title: "Giá vốn (đ)", text: $costPrice)
                    
                    CurrencyTextField(title: "Số lượng nhập kho ban đầu", text: $quantity)
                }
                
                Section(footer: Text("Sản phẩm sẽ được thêm vào kho và đơn hàng hiện tại.")) {
                    Button(action: addProduct) {
                        HStack {
                            Spacer()
                            Text("Thêm và chọn ngay")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(price.isEmpty)
                }
            }
            .navigationTitle("Sản phẩm mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
            }
            .task {
                if let url = info.imageURL {
                    isLoadingImage = true
                    selectedImageData = await BarcodeLookupService.shared.downloadImage(from: url)
                    isLoadingImage = false
                }
            }
        }
    }
    
    private func addProduct() {
        guard let priceVal = Double(price) else { return }
        let costVal = Double(costPrice) ?? 0
        let qtyVal = Int(quantity) ?? 0
        
        // 1. Create Product in DB
        let newProduct = Product(
            name: name,
            price: priceVal,
            costPrice: costVal,
            category: "Đồ uống", // Default or let user pick? Assuming Beverage/FMCG often
            imageName: "cup.and.saucer.fill", // Default icon
            color: "blue",
            imageData: selectedImageData,
            stockQuantity: qtyVal,
            barcode: info.barcode
        )
        
        // Optimistic add to local products
        viewModel.products.append(newProduct)
        viewModel.inventory[newProduct.name.lowercased()] = qtyVal
        
        // Trigger DB save (async)
        Task {
            // Implement save logic in ViewModel or direct here
            // Reusing existing createProduct method logic would be best
             viewModel.createProduct(
                name: name,
                price: priceVal,
                costPrice: costVal,
                category: .others, // Or infer
                imageName: "cup.and.saucer.fill",
                color: "blue",
                quantity: qtyVal,
                imageData: selectedImageData,
                barcode: info.barcode
             )
        }
        
        // 2. Add to current order
        viewModel.addProduct(newProduct)
        
        dismiss()
    }
}

// Extension to make ExternalProductInfo Identifiable for sheet
extension ExternalProductInfo: Identifiable {
    var id: String { barcode }
}
