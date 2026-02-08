import Foundation
import Supabase
import UIKit

class StorageManager {
    static let shared = StorageManager()
    private let client = SupabaseConfig.client
    
    private let productBucket = "product-images"
    
    // Upload image to Supabase Storage and return public URL
    func uploadProductImage(data: Data, fileName: String) async throws -> String {
        let path = "\(fileName).jpg"
        let file = File(name: path, data: data, fileName: path, contentType: "image/jpeg")
        
        // 1. Upload
        // Note: upsert = true allows overwriting if exists
        try await client.storage
            .from(productBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
        
        // 2. Get Public URL
        let publicURL = try client.storage
            .from(productBucket)
            .getPublicURL(path: path)
            
        return publicURL.absoluteString
    }
    
    // Helper to generate unique filename
    func generateImageName() -> String {
        return UUID().uuidString
    }
}
