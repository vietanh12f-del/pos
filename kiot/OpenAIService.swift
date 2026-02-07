import Foundation

struct GPTResponse: Codable {
    let intent: String
    let items: [GPTItem]
}

struct GPTItem: Codable {
    let name: String
    let quantity: Int
    let price: Double
    let discount: Double
    let discountIsPercent: Bool
    let additionalCost: Double
    let isTotal: Bool
}

class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey = "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"
    private let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    func parseOrder(text: String) async throws -> GPTResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are a smart assistant for a POS app (Kiot). Parse the user's voice command into a structured JSON format.
        
        Intent can be "order" (selling) or "restock" (buying/importing).
        If the user says "nhập", "mua thêm", "về kho", intent is "restock".
        If the user says "bán", "khách mua", "lấy cho khách", intent is "order".
        Default to "order" if unclear.
        
        Return a JSON object with:
        - intent: "order" or "restock"
        - items: Array of objects:
            - name: product name (string)
            - quantity: number (default 1)
            - price: number (0 if unknown)
            - discount: number (0 if none)
            - discountIsPercent: boolean (true if discount is %, false if currency)
            - additionalCost: number (0 if none. e.g. "phí ship", "phí vận chuyển")
            - isTotal: boolean (true if price is total for all items, false if unit price. Default false)
        
        Example 1: "Bán 2 cà phê 30k" -> {"intent": "order", "items": [{"name": "cà phê", "quantity": 2, "price": 30000, "discount": 0, "discountIsPercent": false, "additionalCost": 0, "isTotal": false}]}
        Example 2: "Nhập 50 hoa hồng giá 5k phí ship 30k" -> {"intent": "restock", "items": [{"name": "hoa hồng", "quantity": 50, "price": 5000, "discount": 0, "discountIsPercent": false, "additionalCost": 30000, "isTotal": false}]}
        Example 3: "3 trà sữa 50%" -> {"intent": "order", "items": [{"name": "trà sữa", "quantity": 3, "price": 0, "discount": 50, "discountIsPercent": true, "additionalCost": 0, "isTotal": false}]}
        
        Handle Vietnamese currency units: k = 1000, tr/triệu = 1000000.
        """
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo", // Or gpt-4o-mini for speed/cost
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct OpenAIResponse: Decodable {
            let choices: [Choice]
            struct Choice: Decodable {
                let message: Message
            }
            struct Message: Decodable {
                let content: String
            }
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = openAIResponse.choices.first?.message.content ?? "{}"
        
        // Clean up content just in case
        let cleanContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return try JSONDecoder().decode(GPTResponse.self, from: jsonData)
    }
}
