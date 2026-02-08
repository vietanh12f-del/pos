import Foundation
import UIKit

struct ExternalProductInfo {
    let name: String
    let barcode: String
    let imageURL: String?
    let brand: String?
}

class BarcodeLookupService {
    static let shared = BarcodeLookupService()
    
    private init() {}
    
    func lookup(barcode: String) async throws -> ExternalProductInfo? {
        // 1. Try OpenFoodFacts (Best for FMCG, Food, Beverages like Pepsi, Coca)
        if let product = await lookupOpenFoodFacts(barcode: barcode) {
            return product
        }
        
        // 2. Can add more fallbacks here (e.g. Google Books for ISBN, etc.)
        
        return nil
    }
    
    private func lookupOpenFoodFacts(barcode: String) async -> ExternalProductInfo? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Simple parsing
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Int, status == 1,
               let product = json["product"] as? [String: Any] {
                
                let productName = (product["product_name"] as? String) ?? (product["product_name_vi"] as? String) ?? "Unknown Product"
                let imageURL = product["image_url"] as? String
                let brands = product["brands"] as? String
                
                // Refine name
                var finalName = productName
                if let brands = brands, !brands.isEmpty {
                    finalName = "\(brands) - \(productName)"
                }
                
                return ExternalProductInfo(
                    name: finalName,
                    barcode: barcode,
                    imageURL: imageURL,
                    brand: brands
                )
            }
        } catch {
            print("OpenFoodFacts Lookup Error: \(error)")
        }
        
        return nil
    }
    
    // Helper to download image
    func downloadImage(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}
