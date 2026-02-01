import SwiftUI
import Vision
import PhotosUI
import UIKit

struct InvoiceScannerView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var recognizedItems: [RestockItem] = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack {
                if recognizedItems.isEmpty && !isScanning {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.themePrimary)
                        
                        Text("Quét hóa đơn nhập hàng")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Chọn ảnh hóa đơn để tự động nhận diện sản phẩm, số lượng và giá.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.gray)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                showCamera = true
                            }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title)
                                    Text("Chụp ảnh")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color.themePrimary)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title)
                                    Text("Thư viện")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color.gray.opacity(0.1))
                                .foregroundStyle(Color.themePrimary)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                } else if isScanning {
                    ProgressView("Đang phân tích hóa đơn...")
                } else {
                    // Review List
                    List {
                        Section(header: Text("Sản phẩm tìm thấy")) {
                            ForEach($recognizedItems) { $item in
                                HStack {
                                    TextField("Tên", text: $item.name)
                                        .fontWeight(.medium)
                                    
                                    Divider()
                                    
                                    TextField("SL", value: $item.quantity, format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(width: 50)
                                    
                                    Divider()
                                    
                                    TextField("Giá", value: $item.unitPrice, format: .currency(code: "VND"))
                                        .keyboardType(.decimalPad)
                                        .frame(width: 100)
                                }
                            }
                            .onDelete { indexSet in
                                recognizedItems.remove(atOffsets: indexSet)
                            }
                        }
                        
                        Section {
                            Button(action: {
                                addItemsToRestock()
                            }) {
                                Text("Thêm vào phiếu nhập")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundStyle(Color.themePrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quét hóa đơn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem {
                    scanImage(newItem)
                }
            }
            .onChange(of: capturedImage) { newImage in
                if let newImage {
                    isScanning = true
                    recognizeText(from: newImage)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .alert("Lỗi", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func scanImage(_ item: PhotosPickerItem) {
        isScanning = true
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data, let uiImage = UIImage(data: data) {
                        recognizeText(from: uiImage)
                    } else {
                        isScanning = false
                        errorMessage = "Không thể tải ảnh."
                    }
                case .failure(let error):
                    isScanning = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            isScanning = false
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            defer { DispatchQueue.main.async { isScanning = false } }
            
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                DispatchQueue.main.async { errorMessage = "Không tìm thấy văn bản." }
                return
            }
            
            let fullText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            print("OCR Text: \(fullText)")
            
            DispatchQueue.main.async {
                self.parseText(fullText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["vi-VN", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    private func parseText(_ text: String) {
        var items: [RestockItem] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            // Logic: Look for regex patterns
            // 1. Quantity first: "3 hoa hồng 50k"
            // 2. Name first: "Hoa hồng 3 bó 50k"
            
            // Simple Smart Parsing Logic
            // Clean the line
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanLine.isEmpty { continue }
            
            // Try to use SmartParser logic here or ad-hoc regex
            // Regex for: (Quantity) (Name) (Price)
            // e.g., "10 Hoa hồng đỏ 5000" or "Hoa hồng đỏ 10 5000"
            
            // Let's assume a common format in VN invoices: Name - Quantity - Price OR Quantity - Name - Price
            
            // Attempt to extract numbers
            let components = cleanLine.components(separatedBy: .whitespaces)
            var numbers: [Double] = []
            var words: [String] = []
            
            for comp in components {
                // Remove 'k' or ',' or '.'
                let cleanComp = comp.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "k", with: "000", options: .caseInsensitive)
                if let val = Double(cleanComp) {
                    numbers.append(val)
                } else {
                    words.append(comp)
                }
            }
            
            if !words.isEmpty && !numbers.isEmpty {
                let name = words.joined(separator: " ")
                
                var quantity = 1
                var price: Double = 0
                
                // Heuristics
                if numbers.count >= 2 {
                    // Usually smaller number is quantity, larger is price
                    let sorted = numbers.sorted()
                    if sorted[0] < 1000 && sorted[1] > 1000 {
                        quantity = Int(sorted[0])
                        price = sorted[1]
                    } else {
                        // Ambiguous, assume first is quantity
                        quantity = Int(numbers[0])
                        price = numbers[1]
                    }
                } else if numbers.count == 1 {
                    // Only one number. Is it price or quantity?
                    let num = numbers[0]
                    if num > 1000 {
                        price = num
                    } else {
                        quantity = Int(num)
                    }
                }
                
                // If price seems to be total, calculate unit?
                // For now, let's assume OCR picks up Unit Price usually, or Total.
                // Let's stick to what we found.
                
                if quantity > 0 {
                     items.append(RestockItem(name: name, quantity: quantity, unitPrice: price, additionalCost: 0, suggestedPrice: price * 1.3))
                }
            }
        }
        
        self.recognizedItems = items
        
        if items.isEmpty {
            self.errorMessage = "Không nhận diện được sản phẩm nào. Vui lòng thử lại hoặc nhập thủ công."
        }
    }
    
    private func addItemsToRestock() {
        for item in recognizedItems {
            viewModel.addRestockItem(item.name, unitPrice: item.unitPrice, quantity: item.quantity, additionalCost: item.additionalCost, suggestedPrice: item.suggestedPrice)
        }
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .camera
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
