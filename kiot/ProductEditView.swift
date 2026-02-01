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
    @State private var quantity: String = "0"
    @State private var selectedCategory: Category = .others
    @State private var selectedColor: String = "gray"
    @State private var selectedIcon: String = "shippingbox.fill"
    @State private var selectedImageData: Data?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showDeleteConfirmation = false
    
    let colors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray", "black", "brown"]
    let icons = ["shippingbox.fill", "rosette", "sun.max.fill", "camera.macro", "gift.fill", "birthday.cake.fill", "cylinder.split.1x2.fill", "scribble.variable", "envelope.fill", "star.fill", "heart.fill", "tag.fill"]
    
    init(viewModel: OrderViewModel, mode: Mode) {
        self.viewModel = viewModel
        self.mode = mode
        
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _price = State(initialValue: "")
            _quantity = State(initialValue: "0")
            _selectedCategory = State(initialValue: .others)
            _selectedColor = State(initialValue: "gray")
            _selectedIcon = State(initialValue: "shippingbox.fill")
        case .edit(let product):
            _name = State(initialValue: product.name)
            _price = State(initialValue: String(Int(product.price)))
            _quantity = State(initialValue: String(viewModel.stockLevel(for: product.name)))
            _selectedCategory = State(initialValue: Category(rawValue: product.category) ?? .others)
            _selectedColor = State(initialValue: product.color)
            _selectedIcon = State(initialValue: product.imageName)
            _selectedImageData = State(initialValue: product.imageData)
            if let data = product.imageData, let uiImage = UIImage(data: data) {
                _capturedImage = State(initialValue: uiImage)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chi tiết")) {
                    TextField("Tên", text: $name)
                    TextField("Giá", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Tồn kho", text: $quantity)
                        .keyboardType(.numberPad)
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
                                        .fill(selectedIcon == icon && selectedImageData == nil ? Color.themePrimary.opacity(0.2) : Color.gray.opacity(0.1))
                                        .frame(width: 45, height: 45)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(selectedIcon == icon && selectedImageData == nil ? Color.themePrimary : Color.gray)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.themePrimary, lineWidth: selectedIcon == icon && selectedImageData == nil ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                    capturedImage = nil
                                    selectedImageData = nil
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
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        save()
                    }
                    .disabled(name.isEmpty || price.isEmpty)
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
        }
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
        
        switch mode {
        case .add:
            viewModel.createProduct(name: name, price: priceValue, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData)
        case .edit(let product):
            viewModel.updateProduct(product, name: name, price: priceValue, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData)
        }
        dismiss()
    }
}
