import SwiftUI
import PhotosUI
import UIKit

struct ProductEditView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(Product)
    }
    
    let mode: Mode
    let allowEditCostAndStock: Bool
    
    @State private var name: String = ""
    @State private var price: String = ""
    @State private var productPrice: String = ""
    @State private var shippingCost: String = ""
    @State private var importPrice: String = ""
    @State private var additionalCost: String = ""
    @State private var quantity: String = "0"
    @State private var barcode: String = ""
    @State private var selectedCategory: Category = .others
    @State private var selectedColor: String = "gray"
    @State private var selectedIcon: String = "shippingbox.fill"
    @State private var selectedImageData: Data?
    @State private var selectedImageURL: String?
    @State private var isFinishedGood: Bool = false
    @State private var showBarcodeScanner = false
    @State private var capturedImage: UIImage?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var pickerAlertMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showPrintBarcode = false
    @State private var showCostWheel = false
    @State private var costWheelSelection = 0
    @State private var costMillionsSelection = 0
    @State private var costMillionsRangeBase = 0
    @State private var showCostMillionsRangePicker = false
    @State private var costThousandsSelection = 0
    @State private var costThousandsRangeBase = 0
    @State private var showCostThousandsRangePicker = false
    @State private var costHundredsSelection = 0
    @State private var costHundredsRangeBase = 0
    @State private var showCostHundredsRangePicker = false
    @State private var showPriceWheel = false
    @State private var priceWheelSelection = 0
    @State private var priceMillionsSelection = 0
    @State private var priceMillionsRangeBase = 0
    @State private var showPriceMillionsRangePicker = false
    @State private var priceThousandsSelection = 0
    @State private var priceThousandsRangeBase = 0
    @State private var showPriceThousandsRangePicker = false
    @State private var priceHundredsSelection = 0
    @State private var priceHundredsRangeBase = 0
    @State private var showPriceHundredsRangePicker = false
    
    @State private var showProductPriceWheel = false
    @State private var productPriceWheelSelection = 0
    @State private var productPriceMillionsSelection = 0
    @State private var productPriceMillionsRangeBase = 0
    @State private var showProductPriceMillionsRangePicker = false
    @State private var productPriceThousandsSelection = 0
    @State private var productPriceThousandsRangeBase = 0
    @State private var showProductPriceThousandsRangePicker = false
    @State private var productPriceHundredsSelection = 0
    @State private var productPriceHundredsRangeBase = 0
    @State private var showProductPriceHundredsRangePicker = false
    
    @State private var showShippingCostWheel = false
    @State private var shippingCostWheelSelection = 0
    @State private var shippingCostMillionsSelection = 0
    @State private var shippingCostMillionsRangeBase = 0
    @State private var showShippingCostMillionsRangePicker = false
    @State private var shippingCostThousandsSelection = 0
    @State private var shippingCostThousandsRangeBase = 0
    @State private var showShippingCostThousandsRangePicker = false
    @State private var shippingCostHundredsSelection = 0
    @State private var shippingCostHundredsRangeBase = 0
    @State private var showShippingCostHundredsRangePicker = false
    
    @State private var showStockWheel = false
    @State private var stockWheelSelection = 0
    @State private var stockWheelMax = 1000
    @State private var stockKgSelection = 0
    @State private var stockGramsSelection = 0
    @State private var stockGramsMax = 990
    @State private var stockKgRangeBase = 0
    @State private var stockGramsRangeBase = 0
    @State private var showStockKgRangePicker = false
    @State private var showStockGramsRangePicker = false
    @State private var stockUnit = "kg" // "kg" hoặc "cái"
    @State private var showDuplicateNameAlert = false
    @State private var hasVAT: Bool = false
    @State private var markupPercent: Double = 30
    @State private var showMarkupPicker = false
    @State private var additionalInfo: String = ""
    @State private var isHidden: Bool = false
    
    // MARK: - Summary Section State for Finished Goods
    @State private var summaryStartDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var summaryEndDate: Date = Date()
    @State private var showSummaryDatePicker: Bool = false
    @State private var isEditingSummaryStart: Bool = true
    
    let colors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray", "black", "brown"]
    let icons = ["shippingbox.fill", "rosette", "sun.max.fill", "camera.macro", "gift.fill", "birthday.cake.fill", "cylinder.split.1x2.fill", "scribble.variable", "envelope.fill", "star.fill", "heart.fill", "tag.fill"]
    
    private func colorCircle(_ color: String) -> some View {
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
    
    init(viewModel: OrderViewModel, mode: Mode, allowEditCostAndStock: Bool = true) {
        self.viewModel = viewModel
        self.mode = mode
        self.allowEditCostAndStock = allowEditCostAndStock
        
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _price = State(initialValue: "")
            _priceWheelSelection = State(initialValue: 0)
            _productPrice = State(initialValue: "")
            _productPriceWheelSelection = State(initialValue: 0)
            _shippingCost = State(initialValue: "")
            _shippingCostWheelSelection = State(initialValue: 0)
            _importPrice = State(initialValue: "")
            _costWheelSelection = State(initialValue: 0)
            _additionalCost = State(initialValue: "0")
            _quantity = State(initialValue: "0")
            _stockUnit = State(initialValue: "cái")
            _barcode = State(initialValue: "")
            _selectedCategory = State(initialValue: .others)
            _selectedColor = State(initialValue: "gray")
            _selectedIcon = State(initialValue: "shippingbox.fill")
            _isFinishedGood = State(initialValue: false)
            _markupPercent = State(initialValue: 0)
            _additionalInfo = State(initialValue: "")
        case .edit(let product):
            _name = State(initialValue: product.name)
            let initialPrice = Int(product.price)
            _price = State(initialValue: String(initialPrice))
            _priceWheelSelection = State(initialValue: initialPrice)
            
            let initialProductPrice = Int(product.productPrice)
            _productPrice = State(initialValue: String(initialProductPrice))
            _productPriceWheelSelection = State(initialValue: initialProductPrice)
            
            let initialShippingCost = Int(product.shippingCost)
            _shippingCost = State(initialValue: String(initialShippingCost))
            _shippingCostWheelSelection = State(initialValue: initialShippingCost)
            
            let initialCost = Int(product.costPrice)
            _importPrice = State(initialValue: String(initialCost))
            _costWheelSelection = State(initialValue: initialCost)
            
            _additionalCost = State(initialValue: "0")
            let stockQty = product.isFinishedGood ? product.stockQuantity : viewModel.stockLevel(for: product.name)
            _quantity = State(initialValue: String(stockQty))
            _stockUnit = State(initialValue: product.isFinishedGood ? "kg" : "cái")
            _barcode = State(initialValue: product.barcode ?? "")
            _selectedCategory = State(initialValue: Category(rawValue: product.category) ?? .others)
            _selectedColor = State(initialValue: product.color)
            _selectedIcon = State(initialValue: product.imageName)
            _selectedImageData = State(initialValue: product.imageData)
            _selectedImageURL = State(initialValue: product.imageURL)
            _isFinishedGood = State(initialValue: product.isFinishedGood)
            _hasVAT = State(initialValue: product.hasVAT)
            _isHidden = State(initialValue: product.isHidden)
            _additionalInfo = State(initialValue: product.additionalInfo ?? "")
            // markupPercent: tính ngược từ giá bán / giá vốn nếu có
            if product.costPrice > 0 {
                if product.price > product.costPrice {
                    _markupPercent = State(initialValue: ((product.price / product.costPrice) - 1) * 100)
                } else {
                    _markupPercent = State(initialValue: 0)
                }
            }
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
                        HStack(spacing: 8) {
                            TextField("Nhập tên hàng", text: $name)
                            Button {
                                if viewModel.isRecordingManualProductName {
                                    viewModel.speechRecognizer.stopRecording()
                                    let spoken = viewModel.manualRecordedName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !spoken.isEmpty { name = spoken }
                                    viewModel.isRecordingManualProductName = false
                                } else {
                                    do {
                                        try viewModel.speechRecognizer.startRecording()
                                        viewModel.isRecordingManualProductName = true
                                        viewModel.manualRecordedName = ""
                                    } catch { }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill((viewModel.isRecordingManualProductName ? Color.red : Color.gray).opacity(0.15))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: viewModel.isRecordingManualProductName ? "waveform" : "mic.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(viewModel.isRecordingManualProductName ? Color.red : .gray)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                        .onReceive(viewModel.$manualRecordedName) { newText in
                            if viewModel.isRecordingManualProductName {
                                let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !t.isEmpty { name = t }
                            }
                        }
                    }
                    
                    if AuthManager.shared.canViewCostPrice {
                    HStack {
                        Text("Giá sản phẩm")
                        Spacer()
                        Button {
                            if let v = Double(productPrice) { productPriceWheelSelection = Int(v) }
                            showProductPriceWheel = true
                        } label: {
                            Text(formatCurrency(Double(productPriceWheelSelection > 0 ? productPriceWheelSelection : (Int(Double(productPrice) ?? 0)))))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Chi phí vận chuyển")
                        Spacer()
                        Button {
                            if let v = Double(shippingCost) { shippingCostWheelSelection = Int(v) }
                            showShippingCostWheel = true
                        } label: {
                            Text(formatCurrency(Double(shippingCostWheelSelection > 0 ? shippingCostWheelSelection : (Int(Double(shippingCost) ?? 0)))))
                                .fontWeight(.semibold)
                        }
                    }
                    } // end canViewCostPrice
                    
                    if AuthManager.shared.canViewCostPrice {
                        HStack {
                            Text("Giá vốn")
                            Spacer()
                            let pPrice = Double(productPrice) ?? 0
                            let sCost = Double(shippingCost) ?? 0
                            let totalCost = pPrice + sCost
                            Text(formatCurrency(totalCost))
                                .fontWeight(.semibold)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    Toggle(isOn: $hasVAT) {
                        HStack(spacing: 4) {
                            Text("Có VAT")
                            InfoPopoverButton(text: "Đánh dấu nếu hàng hoá này nhập có hoá đơn VAT.")
                        }
                    }
                    .tint(Color.themePrimary)
                    
                    Toggle(isOn: $isHidden) {
                        HStack(spacing: 4) {
                            Text("Ẩn sản phẩm")
                            InfoPopoverButton(text: "Ẩn sản phẩm khỏi danh sách lên đơn hàng. Vẫn hiển thị trong kho hàng.")
                            Image(systemName: "eye.slash")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .tint(Color.red)
                    
                    if case .add = mode {
                        CurrencyTextField(title: "Chi phí phát sinh", text: $additionalCost)
                    }
                    
                    HStack {
                        Text("Giá bán dự kiến")
                        Spacer()
                        // Button % markup
                        Button {
                            showMarkupPicker = true
                        } label: {
                            Text("+\(Int(markupPercent))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            if let v = Double(price) { priceWheelSelection = Int(v) }
                            showPriceWheel = true
                        } label: {
                            Text(formatCurrency(Double(priceWheelSelection > 0 ? priceWheelSelection : (Int(Double(price) ?? 0)))))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Tồn kho")
                        Spacer()
                        if StoreManager.shared.currentMember?.role == .owner {
                            Button {
                                if let v = Int(quantity) { 
                                    stockWheelSelection = v
                                    if stockUnit == "kg" {
                                        stockKgSelection = v / 1000
                                        stockGramsSelection = v % 1000
                                    }
                                }
                                showStockWheel = true
                            } label: {
                                Text(stockUnit == "kg"
                                     ? FormatUtils.formatWeight(Int(quantity) ?? 0)
                                     : "\(Int(quantity) ?? 0) cái")
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Text(stockUnit == "kg"
                                 ? FormatUtils.formatWeight(Int(quantity) ?? 0)
                                 : "\(Int(quantity) ?? 0) cái")
                                .fontWeight(.semibold)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mã vạch")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Nhập hoặc quét mã", text: $barcode)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: { showBarcodeScanner = true }) {
                                        Image(systemName: "barcode.viewfinder")
                                            .foregroundColor(.gray)
                                    }
                                }
                            )
                    }
                    
                    if barcode.isEmpty {
                        Button("Tạo mã vạch tự động") {
                            barcode = BarcodeGenerator.shared.generateRandomBarcode()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        Button {
                            showPrintBarcode = true
                        } label: {
                            Label("In mã vạch", systemImage: "printer")
                                .font(.caption)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thông tin thêm")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $additionalInfo)
                            .frame(minHeight: 80)
                    }
                }
                
                // Show import/export summary only for finished goods in edit mode
                if case .edit(let product) = mode, product.isFinishedGood {
                    // Import Summary Section
                    Section(header: 
                        HStack {
                            Text("Tổng nhập thành phẩm")
                            Spacer()
                            Button {
                                showSummaryDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(summaryDateRangeText)
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    ) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tổng số lượng nhập")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Text(FormatUtils.formatWeight(totalFinishedGoodImportedQuantity, unit: "kg"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themePrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Số phiếu nhập")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Text("\(finishedGoodImportTransactionCount) phiếu")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themePrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        HStack {
                            Text("Tổng giá trị nhập")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(totalFinishedGoodImportedCost))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.green)
                        }
                    }
                    
                    // Export Summary Section
                    Section(header: 
                        HStack {
                            Text("Tổng xuất thành phẩm")
                            Spacer()
                            Button {
                                showSummaryDatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(summaryDateRangeText)
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    ) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tổng số lượng xuất")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Text(FormatUtils.formatWeight(totalFinishedGoodExportedQuantity, unit: "kg"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Số phiếu xuất")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Text("\(finishedGoodExportTransactionCount) phiếu")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        HStack {
                            Text("Tổng giá trị xuất")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(formatCurrency(totalFinishedGoodExportedRevenue))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.red)
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
                                colorCircle(color)
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
                        } else if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            HStack {
                                Spacer()
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.themePrimary, lineWidth: 3)
                                        )
                                    
                                    Button(action: {
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
                            Button(action: {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showCameraPicker = true
                                } else {
                                    pickerAlertMessage = "Thiết bị không hỗ trợ camera"
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 45, height: 45)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                            
                            Button(action: {
                                if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                                    showLibraryPicker = true
                                } else {
                                    pickerAlertMessage = "Không thể mở thư viện ảnh"
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 45, height: 45)
                                    
                                    Image(systemName: "photo")
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
                
                if case .edit(let product) = mode, StoreManager.shared.currentMember?.role == .owner {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text(product.isFinishedGood ? "Xóa thành phẩm" : "Xóa hàng hóa")
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
            .fullScreenCover(isPresented: $showCameraPicker) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showLibraryPicker) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { newImage in
                if let newImage {
                     selectedImageData = newImage.jpegData(compressionQuality: 0.8)
                }
            }
            .alert(pickerAlertMessage ?? "", isPresented: Binding(get: { pickerAlertMessage != nil }, set: { _ in pickerAlertMessage = nil })) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                // Nếu markupPercent là 0% và giá vốn >0, đảm bảo giá bán = giá vốn
                let costVal = costWheelSelection > 0 ? Double(costWheelSelection) : (Double(importPrice) ?? 0)
                if markupPercent == 0 && costVal > 0 {
                    price = String(Int(costVal))
                    priceWheelSelection = Int(costVal)
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
                    productPrice: Double(importPrice) ?? 0,
                    shippingCost: 0,
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
            .sheet(isPresented: $showSummaryDatePicker) {
                VStack(spacing: 16) {
                    Text("Chọn khoảng thời gian").font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Từ ngày").font(.caption).foregroundStyle(.gray)
                            DatePicker("", selection: $summaryStartDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Đến ngày").font(.caption).foregroundStyle(.gray)
                            DatePicker("", selection: $summaryEndDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        Button("7 ngày") {
                            summaryEndDate = Date()
                            summaryStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button("30 ngày") {
                            summaryEndDate = Date()
                            summaryStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button("3 tháng") {
                            summaryEndDate = Date()
                            summaryStartDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button("1 năm") {
                            summaryEndDate = Date()
                            summaryStartDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    
                    Spacer()
                    
                    Button("Xong") {
                        showSummaryDatePicker = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .presentationDetents([.height(350)])
            }
            .sheet(isPresented: $showMarkupPicker) {
                VStack(spacing: 16) {
                    Text("Chỉnh % lợi nhuận")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Picker("% lợi nhuận", selection: Binding(
                        get: { Int(markupPercent) },
                        set: { newVal in
                            markupPercent = Double(newVal)
                            // Tự động cập nhật giá bán theo % mới
                            let costVal = Double(costWheelSelection > 0 ? costWheelSelection : (Int(Double(importPrice) ?? 0)))
                            if costVal > 0 {
                                let newPrice = costVal * (1 + markupPercent / 100)
                                priceWheelSelection = Int(newPrice)
                                price = String(Int(newPrice))
                            }
                        }
                    )) {
                        ForEach(0...999, id: \.self) { pct in
                            Text("+\(pct)%").tag(pct)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                    
                    Button("Xong") { showMarkupPicker = false }
                        .font(.headline)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.orange)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showCostWheel) {
                VStack(spacing: 12) {
                    Text("Sửa giá vốn").font(.headline)
                    Text(formatCurrency(Double(costWheelSelection)))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                    HStack(alignment: .top) {
                        VStack(spacing: 2) {
                            Button { showCostMillionsRangePicker = true } label: {
                                Text(costMillionsRangeBase <= 0 ? ">0" : ">\(costMillionsRangeBase)tr")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Triệu").font(.caption).foregroundStyle(.gray)
                            let millionsMin = costMillionsRangeBase
                            Picker("", selection: $costMillionsSelection) {
                                ForEach(Array(millionsMin...max(millionsMin, millionsMin + 500)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: costMillionsSelection) { v in
                                costWheelSelection = v * 1_000_000 + costThousandsSelection * 1_000 + costHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showCostThousandsRangePicker = true } label: {
                                Text(costThousandsRangeBase <= 0 ? ">0" : ">\(costThousandsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Ngàn").font(.caption).foregroundStyle(.gray)
                            let thousandsMin = costThousandsRangeBase
                            Picker("", selection: $costThousandsSelection) {
                                ForEach(Array(stride(from: thousandsMin, through: min(thousandsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: costThousandsSelection) { v in
                                costWheelSelection = costMillionsSelection * 1_000_000 + v * 1_000 + costHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showCostHundredsRangePicker = true } label: {
                                Text(costHundredsRangeBase <= 0 ? ">0" : "\(costHundredsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Trăm").font(.caption).foregroundStyle(.gray)
                            let hundredsMin = costHundredsRangeBase
                            Picker("", selection: $costHundredsSelection) {
                                ForEach(Array(stride(from: hundredsMin, through: min(hundredsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: costHundredsSelection) { v in
                                costWheelSelection = costMillionsSelection * 1_000_000 + costThousandsSelection * 1_000 + v
                            }
                        }
                    }
                    HStack {
                        Button("Đóng") { showCostWheel = false }
                        Spacer()
                        Button("Lưu") {
                            importPrice = String(costWheelSelection)
                            showCostWheel = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(340)])
                .onAppear {
                    let current = max(0, costWheelSelection)
                    costMillionsSelection = current / 1_000_000
                    costMillionsRangeBase = (costMillionsSelection / 10) * 10
                    let rem1 = current % 1_000_000
                    costThousandsSelection = rem1 / 1_000
                    costThousandsRangeBase = (costThousandsSelection / 100) * 100
                    let rem2 = rem1 % 1_000
                    costHundredsRangeBase = (rem2 / 100) * 100
                    costHundredsSelection = (rem2 / 10) * 10
                }
                .sheet(isPresented: $showCostMillionsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng triệu").font(.headline)
                        Picker("", selection: $costMillionsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if costMillionsSelection < costMillionsRangeBase { costMillionsSelection = costMillionsRangeBase }
                            showCostMillionsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showCostThousandsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng ngàn").font(.headline)
                        Picker("", selection: $costThousandsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if costThousandsSelection < costThousandsRangeBase || costThousandsSelection > costThousandsRangeBase + 99 { costThousandsSelection = costThousandsRangeBase }
                            showCostThousandsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showCostHundredsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng trăm").font(.headline)
                        Picker("", selection: $costHundredsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if costHundredsSelection < costHundredsRangeBase || costHundredsSelection > costHundredsRangeBase + 99 { costHundredsSelection = costHundredsRangeBase }
                            showCostHundredsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
            }
            .sheet(isPresented: $showPriceWheel) {
                VStack(spacing: 12) {
                    Text("Sửa giá bán").font(.headline)
                    Text(formatCurrency(Double(priceWheelSelection)))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                    HStack(alignment: .top) {
                        VStack(spacing: 2) {
                            Button { showPriceMillionsRangePicker = true } label: {
                                Text(priceMillionsRangeBase <= 0 ? ">0" : ">\(priceMillionsRangeBase)tr")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Triệu").font(.caption).foregroundStyle(.gray)
                            let millionsMin = priceMillionsRangeBase
                            Picker("", selection: $priceMillionsSelection) {
                                ForEach(Array(millionsMin...max(millionsMin, millionsMin + 500)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceMillionsSelection) { v in
                                priceWheelSelection = v * 1_000_000 + priceThousandsSelection * 1_000 + priceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showPriceThousandsRangePicker = true } label: {
                                Text(priceThousandsRangeBase <= 0 ? ">0" : ">\(priceThousandsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Ngàn").font(.caption).foregroundStyle(.gray)
                            let thousandsMin = priceThousandsRangeBase
                            Picker("", selection: $priceThousandsSelection) {
                                ForEach(Array(stride(from: thousandsMin, through: min(thousandsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceThousandsSelection) { v in
                                priceWheelSelection = priceMillionsSelection * 1_000_000 + v * 1_000 + priceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showPriceHundredsRangePicker = true } label: {
                                Text(priceHundredsRangeBase <= 0 ? ">0" : "\(priceHundredsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Trăm").font(.caption).foregroundStyle(.gray)
                            let hundredsMin = priceHundredsRangeBase
                            Picker("", selection: $priceHundredsSelection) {
                                ForEach(Array(stride(from: hundredsMin, through: min(hundredsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: priceHundredsSelection) { v in
                                priceWheelSelection = priceMillionsSelection * 1_000_000 + priceThousandsSelection * 1_000 + v
                            }
                        }
                    }
                    HStack {
                        Button("Đóng") { showPriceWheel = false }
                        Spacer()
                        Button("Lưu") {
                            price = String(priceWheelSelection)
                            showPriceWheel = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(340)])
                .onAppear {
                    let current = max(0, priceWheelSelection)
                    priceMillionsSelection = current / 1_000_000
                    priceMillionsRangeBase = (priceMillionsSelection / 10) * 10
                    let rem1 = current % 1_000_000
                    priceThousandsSelection = rem1 / 1_000
                    priceThousandsRangeBase = (priceThousandsSelection / 100) * 100
                    let rem2 = rem1 % 1_000
                    priceHundredsRangeBase = (rem2 / 100) * 100
                    priceHundredsSelection = (rem2 / 10) * 10
                }
                .sheet(isPresented: $showPriceMillionsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng triệu").font(.headline)
                        Picker("", selection: $priceMillionsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceMillionsSelection < priceMillionsRangeBase { priceMillionsSelection = priceMillionsRangeBase }
                            showPriceMillionsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showPriceThousandsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng ngàn").font(.headline)
                        Picker("", selection: $priceThousandsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceThousandsSelection < priceThousandsRangeBase || priceThousandsSelection > priceThousandsRangeBase + 99 { priceThousandsSelection = priceThousandsRangeBase }
                            showPriceThousandsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showPriceHundredsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng trăm").font(.headline)
                        Picker("", selection: $priceHundredsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if priceHundredsSelection < priceHundredsRangeBase || priceHundredsSelection > priceHundredsRangeBase + 99 { priceHundredsSelection = priceHundredsRangeBase }
                            showPriceHundredsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
            }
            .sheet(isPresented: $showProductPriceWheel) {
                VStack(spacing: 12) {
                    Text("Sửa giá sản phẩm").font(.headline)
                    Text(formatCurrency(Double(productPriceWheelSelection)))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                    HStack(alignment: .top) {
                        VStack(spacing: 2) {
                            Button { showProductPriceMillionsRangePicker = true } label: {
                                Text(productPriceMillionsRangeBase <= 0 ? ">0" : ">\(productPriceMillionsRangeBase)tr")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Triệu").font(.caption).foregroundStyle(.gray)
                            let millionsMin = productPriceMillionsRangeBase
                            Picker("", selection: $productPriceMillionsSelection) {
                                ForEach(Array(millionsMin...max(millionsMin, millionsMin + 500)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: productPriceMillionsSelection) { v in
                                productPriceWheelSelection = v * 1_000_000 + productPriceThousandsSelection * 1_000 + productPriceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showProductPriceThousandsRangePicker = true } label: {
                                Text(productPriceThousandsRangeBase <= 0 ? ">0" : ">\(productPriceThousandsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Ngàn").font(.caption).foregroundStyle(.gray)
                            let thousandsMin = productPriceThousandsRangeBase
                            Picker("", selection: $productPriceThousandsSelection) {
                                ForEach(Array(stride(from: thousandsMin, through: min(thousandsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: productPriceThousandsSelection) { v in
                                productPriceWheelSelection = productPriceMillionsSelection * 1_000_000 + v * 1_000 + productPriceHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showProductPriceHundredsRangePicker = true } label: {
                                Text(productPriceHundredsRangeBase <= 0 ? ">0" : "\(productPriceHundredsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Trăm").font(.caption).foregroundStyle(.gray)
                            let hundredsMin = productPriceHundredsRangeBase
                            Picker("", selection: $productPriceHundredsSelection) {
                                ForEach(Array(stride(from: hundredsMin, through: min(hundredsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: productPriceHundredsSelection) { v in
                                productPriceWheelSelection = productPriceMillionsSelection * 1_000_000 + productPriceThousandsSelection * 1_000 + v
                            }
                        }
                    }
                    HStack {
                        Button("Đóng") { showProductPriceWheel = false }
                        Spacer()
                        Button("Lưu") {
                            productPrice = String(productPriceWheelSelection)
                            showProductPriceWheel = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(340)])
                .onAppear {
                    let current = max(0, productPriceWheelSelection)
                    productPriceMillionsSelection = current / 1_000_000
                    productPriceMillionsRangeBase = (productPriceMillionsSelection / 10) * 10
                    let rem1 = current % 1_000_000
                    productPriceThousandsSelection = rem1 / 1_000
                    productPriceThousandsRangeBase = (productPriceThousandsSelection / 100) * 100
                    let rem2 = rem1 % 1_000
                    productPriceHundredsRangeBase = (rem2 / 100) * 100
                    productPriceHundredsSelection = (rem2 / 10) * 10
                }
                .sheet(isPresented: $showProductPriceMillionsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng triệu").font(.headline)
                        Picker("", selection: $productPriceMillionsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if productPriceMillionsSelection < productPriceMillionsRangeBase { productPriceMillionsSelection = productPriceMillionsRangeBase }
                            showProductPriceMillionsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showProductPriceThousandsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng ngàn").font(.headline)
                        Picker("", selection: $productPriceThousandsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if productPriceThousandsSelection < productPriceThousandsRangeBase || productPriceThousandsSelection > productPriceThousandsRangeBase + 99 { productPriceThousandsSelection = productPriceThousandsRangeBase }
                            showProductPriceThousandsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showProductPriceHundredsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng trăm").font(.headline)
                        Picker("", selection: $productPriceHundredsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if productPriceHundredsSelection < productPriceHundredsRangeBase || productPriceHundredsSelection > productPriceHundredsRangeBase + 99 { productPriceHundredsSelection = productPriceHundredsRangeBase }
                            showProductPriceHundredsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
            }
            .sheet(isPresented: $showShippingCostWheel) {
                VStack(spacing: 12) {
                    Text("Sửa chi phí vận chuyển").font(.headline)
                    Text(formatCurrency(Double(shippingCostWheelSelection)))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                    HStack(alignment: .top) {
                        VStack(spacing: 2) {
                            Button { showShippingCostMillionsRangePicker = true } label: {
                                Text(shippingCostMillionsRangeBase <= 0 ? ">0" : ">\(shippingCostMillionsRangeBase)tr")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Triệu").font(.caption).foregroundStyle(.gray)
                            let millionsMin = shippingCostMillionsRangeBase
                            Picker("", selection: $shippingCostMillionsSelection) {
                                ForEach(Array(millionsMin...max(millionsMin, millionsMin + 500)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: shippingCostMillionsSelection) { v in
                                shippingCostWheelSelection = v * 1_000_000 + shippingCostThousandsSelection * 1_000 + shippingCostHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showShippingCostThousandsRangePicker = true } label: {
                                Text(shippingCostThousandsRangeBase <= 0 ? ">0" : ">\(shippingCostThousandsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Ngàn").font(.caption).foregroundStyle(.gray)
                            let thousandsMin = shippingCostThousandsRangeBase
                            Picker("", selection: $shippingCostThousandsSelection) {
                                ForEach(Array(stride(from: thousandsMin, through: min(thousandsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: shippingCostThousandsSelection) { v in
                                shippingCostWheelSelection = shippingCostMillionsSelection * 1_000_000 + v * 1_000 + shippingCostHundredsSelection
                            }
                        }
                        VStack(spacing: 2) {
                            Button { showShippingCostHundredsRangePicker = true } label: {
                                Text(shippingCostHundredsRangeBase <= 0 ? ">0" : "\(shippingCostHundredsRangeBase)")
                                    .fontWeight(.bold).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }.buttonStyle(.plain)
                            Text("Trăm").font(.caption).foregroundStyle(.gray)
                            let hundredsMin = shippingCostHundredsRangeBase
                            Picker("", selection: $shippingCostHundredsSelection) {
                                ForEach(Array(stride(from: hundredsMin, through: min(hundredsMin + 99, 999), by: 1)), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: shippingCostHundredsSelection) { v in
                                shippingCostWheelSelection = shippingCostMillionsSelection * 1_000_000 + shippingCostThousandsSelection * 1_000 + v
                            }
                        }
                    }
                    HStack {
                        Button("Đóng") { showShippingCostWheel = false }
                        Spacer()
                        Button("Lưu") {
                            shippingCost = String(shippingCostWheelSelection)
                            showShippingCostWheel = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(340)])
                .onAppear {
                    let current = max(0, shippingCostWheelSelection)
                    shippingCostMillionsSelection = current / 1_000_000
                    shippingCostMillionsRangeBase = (shippingCostMillionsSelection / 10) * 10
                    let rem1 = current % 1_000_000
                    shippingCostThousandsSelection = rem1 / 1_000
                    shippingCostThousandsRangeBase = (shippingCostThousandsSelection / 100) * 100
                    let rem2 = rem1 % 1_000
                    shippingCostHundredsRangeBase = (rem2 / 100) * 100
                    shippingCostHundredsSelection = (rem2 / 10) * 10
                }
                .sheet(isPresented: $showShippingCostMillionsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng triệu").font(.headline)
                        Picker("", selection: $shippingCostMillionsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if shippingCostMillionsSelection < shippingCostMillionsRangeBase { shippingCostMillionsSelection = shippingCostMillionsRangeBase }
                            showShippingCostMillionsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showShippingCostThousandsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng ngàn").font(.headline)
                        Picker("", selection: $shippingCostThousandsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if shippingCostThousandsSelection < shippingCostThousandsRangeBase || shippingCostThousandsSelection > shippingCostThousandsRangeBase + 99 { shippingCostThousandsSelection = shippingCostThousandsRangeBase }
                            showShippingCostThousandsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showShippingCostHundredsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng trăm").font(.headline)
                        Picker("", selection: $shippingCostHundredsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                            }
                        }.pickerStyle(.wheel)
                        Button {
                            if shippingCostHundredsSelection < shippingCostHundredsRangeBase || shippingCostHundredsSelection > shippingCostHundredsRangeBase + 99 { shippingCostHundredsSelection = shippingCostHundredsRangeBase }
                            showShippingCostHundredsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.themePrimary).cornerRadius(10)
                        }
                    }.padding().presentationDetents([.height(300)])
                }
            }
            .sheet(isPresented: $showStockWheel) {
                VStack(spacing: 12) {
                    Text("Sửa tồn kho")
                        .font(.headline)
                    
                    // Segment chọn đơn vị
                    Picker("Đơn vị", selection: $stockUnit) {
                        Text("Kg").tag("kg")
                        Text("Cái").tag("cái")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if stockUnit == "kg" {
                        // Bánh xe Kg + Gam
                        HStack {
                            Button {
                                showStockKgRangePicker = true
                            } label: {
                                Text(stockKgRangeBase <= 0 ? ">0" : ">\(stockKgRangeBase)")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                showStockGramsRangePicker = true
                            } label: {
                                Text(stockGramsRangeBase <= 0 ? ">0g" : ">\(stockGramsRangeBase)g")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            VStack {
                                Text("Kg").font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $stockKgSelection) {
                                    ForEach(Array(stockKgRangeBase...stockWheelMax), id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: stockKgSelection) { v in
                                    if v >= stockWheelMax - 10 { stockWheelMax += 200 }
                                }
                            }
                            VStack {
                                Text("Gam").font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $stockGramsSelection) {
                                    ForEach(Array(stride(from: stockGramsRangeBase, through: stockGramsMax, by: 1)), id: \.self) { g in
                                        Text("\(g)").tag(g)
                                    }
                                }
                                .pickerStyle(.wheel)
                            }
                        }
                    } else {
                        // Bánh xe số cái
                        HStack {
                            Button {
                                showStockKgRangePicker = true
                            } label: {
                                Text(stockKgRangeBase <= 0 ? ">0" : ">\(stockKgRangeBase)")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        Picker("", selection: $stockWheelSelection) {
                            ForEach(Array(max(0, stockKgRangeBase)...stockWheelMax), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: stockWheelSelection) { v in
                            if v > stockWheelMax - 10 { stockWheelMax += 500 }
                        }
                    }
                    
                    HStack {
                        Button("Đóng") { showStockWheel = false }
                        Spacer()
                        Button("Lưu") {
                            if stockUnit == "kg" {
                                quantity = String(stockKgSelection * 1000 + stockGramsSelection)
                            } else {
                                quantity = String(stockWheelSelection)
                            }
                            showStockWheel = false
                        }
                    }
                    .font(.headline)
                }
                .padding()
                .presentationDetents([.height(stockUnit == "kg" ? 400 : 340)])
                .onAppear {
                    let current = Int(quantity) ?? 0
                    if stockUnit == "kg" {
                        stockKgSelection = current / 1000
                        stockGramsSelection = ((current % 1000) / 10) * 10
                        stockKgRangeBase = (stockKgSelection / 100) * 100
                    } else {
                        stockWheelSelection = current
                        if stockWheelSelection > stockWheelMax - 50 { stockWheelMax = stockWheelSelection + 500 }
                        stockKgRangeBase = (stockWheelSelection / 100) * 100
                    }
                }
                .sheet(isPresented: $showStockKgRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng giá trị").font(.headline)
                        Picker("", selection: $stockKgRangeBase) {
                            ForEach(Array(stride(from: 0, through: stockWheelMax, by: 100)), id: \.self) { v in
                                Text(v == 0 ? ">0" : ">\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: stockKgRangeBase) { v in
                            if v >= stockWheelMax - 100 { stockWheelMax += 500 }
                        }
                        Button {
                            if stockUnit == "kg" {
                                if stockKgSelection < stockKgRangeBase { stockKgSelection = stockKgRangeBase }
                            } else {
                                if stockWheelSelection < stockKgRangeBase { stockWheelSelection = stockKgRangeBase }
                            }
                            showStockKgRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(.white).frame(maxWidth: .infinity)
                                .padding(.vertical, 10).background(Color.themePrimary).cornerRadius(10)
                        }
                    }
                    .padding()
                    .presentationDetents([.height(320)])
                }
                .sheet(isPresented: $showStockGramsRangePicker) {
                    VStack(spacing: 16) {
                        Text("Chọn vùng Gam").font(.headline)
                        Picker("", selection: $stockGramsRangeBase) {
                            ForEach(Array(stride(from: 0, through: 990, by: 1)), id: \.self) { v in
                                Text(v == 0 ? ">0g" : ">\(v)g").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        Button {
                            if stockGramsSelection < stockGramsRangeBase { stockGramsSelection = stockGramsRangeBase }
                            showStockGramsRangePicker = false
                        } label: {
                            Text("Xong").font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(.white).frame(maxWidth: .infinity)
                                .padding(.vertical, 10).background(Color.themePrimary).cornerRadius(10)
                        }
                    }
                    .padding()
                    .presentationDetents([.height(320)])
                }
            }
            .alert("Tên đã tồn tại", isPresented: $showDuplicateNameAlert) {
                Button("Đồng ý", role: .cancel) { }
            } message: {
                let existing = viewModel.products.first { $0.name.lowercased() == name.lowercased() }
                let typeLabel = existing?.isFinishedGood == true ? "thành phẩm" : "hàng hoá"
                Text("Tên '\(name)' đã tồn tại trong danh mục \(typeLabel). Vui lòng đặt tên khác.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Load production history for both import and export when editing finished goods
            if case .edit(let product) = mode, product.isFinishedGood {
                await loadSummaryData()
            }
        }
    }
    
    // MARK: - Summary Computed Properties for Finished Goods
    
    private var summaryDateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM"
        return "\(formatter.string(from: summaryStartDate)) - \(formatter.string(from: summaryEndDate))"
    }
    
    // Cache for production transactions to avoid repeated fetches
    @State private var cachedImportTxs: [ProductionTransaction] = []
    @State private var cachedExportTxs: [ProductionTransaction] = []
    @State private var hasLoadedSummaryData: Bool = false
    
    private func loadSummaryData() async {
        guard !hasLoadedSummaryData else { return }
        let importTxs = await viewModel.fetchProductionTransactions(mode: "Nhập Thành Phẩm")
        let exportTxs = await viewModel.fetchProductionTransactions(mode: "Xuất Thành Phẩm")
        cachedImportTxs = importTxs
        cachedExportTxs = exportTxs
        hasLoadedSummaryData = true
    }
    
    private var totalFinishedGoodImportedQuantity: Int {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        let importTxs = cachedImportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return importTxs.reduce(0) { total, tx in
            let matchingItems = tx.items.filter { $0.name == productName }
            return total + matchingItems.reduce(0) { $0 + $1.quantity }
        }
    }
    
    private var totalFinishedGoodImportedCost: Double {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        let importTxs = cachedImportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return importTxs.reduce(0) { total, tx in
            let matchingItems = tx.items.filter { $0.name == productName }
            return total + matchingItems.reduce(0) { sum, item in
                let isCai = item.unit?.lowercased() == "cái"
                let itemCost = isCai
                    ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                    : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                return sum + itemCost
            }
        }
    }
    
    private var finishedGoodImportTransactionCount: Int {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        return cachedImportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate &&
            tx.items.contains { $0.name == productName }
        }.count
    }
    
    private var totalFinishedGoodExportedQuantity: Int {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        let exportTxs = cachedExportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return exportTxs.reduce(0) { total, tx in
            let matchingItems = tx.items.filter { $0.name == productName }
            return total + matchingItems.reduce(0) { $0 + $1.quantity }
        }
    }
    
    private var totalFinishedGoodExportedRevenue: Double {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        let exportTxs = cachedExportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate
        }
        return exportTxs.reduce(0) { total, tx in
            let matchingItems = tx.items.filter { $0.name == productName }
            let selectedTotal = matchingItems.reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
            let allItemsTotal = tx.items.reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
            let proportion = allItemsTotal > 0 ? selectedTotal / allItemsTotal : 0
            return total + (tx.grandTotal ?? 0) * proportion
        }
    }
    
    private var finishedGoodExportTransactionCount: Int {
        guard case .edit(let product) = mode else { return 0 }
        let productName = product.name
        return cachedExportTxs.filter { tx in
            !tx.isDeleted &&
            tx.createdAt >= summaryStartDate &&
            tx.createdAt <= summaryEndDate &&
            tx.items.contains { $0.name == productName }
        }.count
    }
    
    var title: String {
        switch mode {
        case .add: return "Thêm hàng mới"
        case .edit(let p): return p.isFinishedGood ? "Sửa thành phẩm" : "Sửa hàng hóa"
        }
    }
    
    func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 [ProductEditView] Checking duplicate for: \(trimmedName)")
        
        // Kiểm tra trùng tên (case-insensitive)
        let isDuplicate: Bool = {
            let matches = viewModel.products.filter { $0.name.lowercased() == trimmedName.lowercased() }
            print("🔍 [ProductEditView] Found matches: \(matches.count)")
            
            switch mode {
            case .add:
                return !matches.isEmpty
            case .edit(let currentProduct):
                return matches.contains { $0.id != currentProduct.id }
            }
        }()
        
        if isDuplicate {
            print("⚠️ [ProductEditView] Duplicate detected, showing alert")
            showDuplicateNameAlert = true
            return
        }
        guard let priceValue = Double(price) else { return }
        let quantityValue = Int(quantity) ?? 0
        let productPriceValue = Double(productPrice) ?? 0
        let shippingCostValue = Double(shippingCost) ?? 0
        
        let finalCostPrice = productPriceValue + shippingCostValue
        
        switch mode {
        case .add:
            viewModel.createProduct(name: name, price: priceValue, productPrice: productPriceValue, shippingCost: shippingCostValue, costPrice: finalCostPrice, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData, barcode: barcode.isEmpty ? nil : barcode, isFinishedGood: isFinishedGood, isHidden: isHidden, additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo)
        case .edit(let product):
            var updatedProduct = product
            updatedProduct.isFinishedGood = isFinishedGood
            updatedProduct.hasVAT = hasVAT
            updatedProduct.isHidden = isHidden
            viewModel.updateProduct(updatedProduct, name: name, price: priceValue, productPrice: productPriceValue, shippingCost: shippingCostValue, costPrice: finalCostPrice, category: selectedCategory, imageName: selectedIcon, color: selectedColor, quantity: quantityValue, imageData: selectedImageData, barcode: barcode.isEmpty ? nil : barcode, imageURL: selectedImageURL, isHidden: isHidden, additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo)
        }
        dismiss()
    }
}
