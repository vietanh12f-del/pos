import SwiftUI
import PhotosUI

struct ProductEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(Product)
    }
    
    let mode: Mode
    
    @State private var name: String = ""
    @State private var price: String = ""
    @State private var importPrice: String = ""
    @State private var additionalCost: String = ""
    @State private var quantity: String = "0"
    @State private var barcode: String = ""
    @State private var selectedCategory: Category = .others
    @State private var selectedColor: String = "gray"
    @State private var selectedIcon: String = "shippingbox.fill"
    @State private var selectedImageData: Data?
    @State private var selectedImageURL: String?
    @State private var showCamera = false
    @State private var showBarcodeScanner = false
    @State private var capturedImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var showPrintBarcode = false
    
    let colors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray", "black", "brown"]
    let icons = ["shippingbox.fill", "rosette", "sun.max.fill", "camera.macro", "gift.fill", "birthday.cake.fill", "cylinder.split.1x2.fill", "scribble.variable", "envelope.fill", "star.fill", "heart.fill", "tag.fill"]
    
    init(viewModel: OrderViewModel, mode: Mode) {
        self.viewModel = viewModel
        self.mode = mode
        
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _price = State(initialValue: "")
            _importPrice = State(initialValue: "")
            _additionalCost = State(initialValue: "")
            _quantity = State(initialValue: "0")
            _barcode = State(initialValue: "")
            _selectedCategory = State(initialValue: .others)
            _selectedColor = State(initialValue: "gray")
            _selectedIcon = State(initialValue: "shippingbox.fill")
        case .edit(let product):
            _name = State(initialValue: product.name)
            _price = State(initialValue: String(Int(product.price)))
            _importPrice = State(initialValue: String(Int(product.costPrice)))
            _additionalCost = State(initialValue: "0")
            _quantity = State(initialValue: String(viewModel.stockLevel(for: product.name)))
            _barcode = State(initialValue: product.barcode ?? "")
            _selectedCategory = State(initialValue: Category(rawValue: product.category) ?? .others)
            _selectedColor = State(initialValue: product.color)
            _selectedIcon = State(initialValue: product.imageName)
            _selectedImageData = State(initialValue: product.imageData)
            _selectedImageURL = State(initialValue: product.imageURL)
            if let data = product.imageData, let uiImage = UIImage(data: data) {
                _capturedImage = State(initialValue: uiImage)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button("Hủy") {
                    dismiss()
                }
                .foregroundStyle(Color.themeTextDark)
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                
                Spacer()
                
                Button("Lưu") {
                    save()
                }
                .disabled(name.isEmpty || price.isEmpty)
                .foregroundStyle(name.isEmpty || price.isEmpty ? Color.gray : Color.themePrimary)
            }
            .padding()
            .background(Color.white)
            
            Form {
                Section(header: Text("Chi tiết")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tên hàng")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        TextField("Nhập tên hàng", text: $name)
                    }
                    
                    if case .add = mode {
                        CurrencyTextField(title: "Giá vốn", text: $importPrice)
                        CurrencyTextField(title: "Chi phí phát sinh", text: $additionalCost)
                    } else {
                        CurrencyTextField(title: "Giá vốn", text: $importPrice)
                    }
                    
                    CurrencyTextField(title: "Giá bán dự kiến", text: $price)
                    CurrencyTextField(title: "Tồn kho", text: $quantity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mã vạch")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        TextField("Nhập hoặc quét mã", text: $barcode)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: { showBarcodeScanner = true }) {
                                        Image(systemName: "barcode.viewfinder")
                                            .foregroundStyle(.gray)
                                    }
                                }
                            )
                    }
                    
                    if barcode.isEmpty {
                        Button("Tạo mã vạch tự động") {
                            barcode = BarcodeGenerator.shared.generateRandomBarcode()
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    } else {
                        Button {
                            showPrintBarcode = true
                        } label: {
                            Label("In mã vạch", systemImage: "printer")
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Danh mục")) {
                    Picker("Danh mục", selection: $selectedCategory) {
                        ForEach(Category.allCases.filter { $0 != .all }, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                
                Section(header: Text("Giao diện")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nhãn màu")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(colorForString(color))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                            .padding(-2)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biểu tượng")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        if let capturedImage {
                             HStack {
                                 Spacer()
                                 ZStack(alignment: .topTrailing) {
                                     Image(uiImage: capturedImage)
                                         .resizable()
                                         .scaledToFill()
                                         .frame(width: 100, height: 100)
                                         .clipShape(RoundedRectangle(cornerRadius: 12))
                                         .overlay(
                                             RoundedRectangle(cornerRadius: 12)
                                                 .stroke(Color.themePrimary, lineWidth: 3)
                                         )
                                     
                                     Button(action: {
                                         self.capturedImage = nil
                                         self.selectedImageData = nil
                                     }) {
                                         Image(systemName: "xmark.circle.fill")
                                             .font(.title2)
                                             .foregroundStyle(.red)
                                             .background(Color.white.clipShape(Circle()))
                                     }
                                     .offset(x: 10, y: -10)
                                 }
                                 Spacer()
                             }
                             .padding(.bottom, 8)
                        } else if let imageURL = selectedImageURL, let url = URL(string: imageURL) {
                            HStack {
                                Spacer()
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.themePrimary, lineWidth: 3)
                                                )
                                        } else if phase.error != nil {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.gray)
                                        } else {
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    }
                                    
                                    Button(action: {
                                        self.selectedImageURL = nil
                                        // Note: Clearing URL doesn't delete from server, but will unlink from product on save if supported
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.red)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                    .offset(x: 10, y: -10)
                                }
                                Spacer()
                            }
                            .padding(.bottom, 8)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 45))], spacing: 12) {
                            Button(action: { showCamera = true }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 45, height: 45)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                            
                            ForEach(icons, id: \.self) { icon in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon && selectedImageData == nil && selectedImageURL == nil ? Color.themePrimary.opacity(0.2) : Color.gray.opacity(0.1))
                                        .frame(width: 45, height: 45)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(selectedIcon == icon && selectedImageData == nil && selectedImageURL == nil ? Color.themePrimary : Color.gray)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.themePrimary, lineWidth: selectedIcon == icon && selectedImageData == nil && selectedImageURL == nil ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                    capturedImage = nil
                                    selectedImageData = nil
                                    selectedImageURL = nil
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if case .edit(let product) = mode {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Xóa hàng hóa")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .alert("Xóa mặt hàng?", isPresented: $showDeleteConfirmation) {
                Button("Xóa", role: .destructive) {
                    if case .edit(let product) = mode {
                        viewModel.deleteProduct(product)
                        dismiss()
                    }
                }
                Button("Hủy", role: .cancel) { }
            } message: {
                if case .edit(let product) = mode {
                    Text("Bạn có chắc muốn xóa '\(product.name)'? Hành động này không thể hoàn tác.")
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { newImage in
                if let newImage {
                     selectedImageData = newImage.jpegData(compressionQuality: 0.8)
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(onScan: { code in
                    barcode = code
                    showBarcodeScanner = false
                })
            }
            .sheet(isPresented: $showPrintBarcode) {
                let tempProduct = Product(
                    id: { if case .edit(let p) = mode { return p.id } else { return UUID() } }(),
                    name: name,
                    price: Double(price) ?? 0,
                    costPrice: Double(importPrice) ?? 0,
                    category: selectedCategory.rawValue,
                    imageName: selectedIcon,
                    color: selectedColor,
                    imageData: selectedImageData,
                    stockQuantity: Int(quantity) ?? 0,
                    barcode: barcode
                )
                BarcodePrintView(product: tempProduct)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    var title: String {
        switch mode {
        case .add: return "Thêm hàng mới"
        case .edit: return "Sửa hàng hóa"
        }
    }
    
    func save() {
        guard let priceValue = Double(price) else { return }
        let quantityValue = Int(quantity) ?? 0
        let importPriceValue = Double(importPrice) ?? 0
        let additionalCostValue = Double(additionalCost) ?? 0
        
        var finalCostPrice = importPriceValue
        if quantityValue > 0 && additionalCostValue > 0 {
            finalCostPrice += (additionalCostValue / Double(quantityValue))
        }
        
        switch mode {
        case .add:
            viewModel.createProduct(name: name, price: priceValue, costPrice: finalCostPrice, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData, barcode: barcode.isEmpty ? nil : barcode)
        case .edit(let product):
            viewModel.updateProduct(product, name: name, price: priceValue, costPrice: finalCostPrice, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData, barcode: barcode.isEmpty ? nil : barcode, imageURL: selectedImageURL)
        }
        dismiss()
    }
}
