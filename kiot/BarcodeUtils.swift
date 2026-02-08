import SwiftUI
import CoreImage.CIFilterBuiltins

struct BarcodeGenerator {
    static let shared = BarcodeGenerator()
    private let context = CIContext()
    private let filter = CIFilter.code128BarcodeGenerator()
    
    func generateBarcode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image (barcodes are very small by default)
        let transform = CGAffineTransform(scaleX: 3, y: 3)
        let scaledImage = outputImage.transformed(by: transform)
        
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    func generateRandomBarcode() -> String {
        // Generate a random 12-digit number (common for UPC/EAN without checksum)
        // or just a unique ID. Let's use 893 (Vietnam) + 9 random digits.
        let prefix = "893"
        let randomDigits = String((0..<9).map { _ in "0123456789".randomElement()! })
        return prefix + randomDigits
    }
}
