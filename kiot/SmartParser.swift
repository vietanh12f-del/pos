import Foundation
import NaturalLanguage

class SmartParser {
    
    /// Parses a raw string into structured order data using heuristics and NLP
    /// Supports inputs like:
    /// - "2 coffee 30k"
    /// - "coffee 30k 2"
    /// - "bún bò 2 tô 50000"
    static func parse(text: String) -> (name: String, quantity: Int, price: Double, isTotal: Bool?)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Detect price context keywords
        let lowerText = trimmed.lowercased()
        var isTotal: Bool? = nil
        
        if lowerText.contains("tổng") || lowerText.contains("hết") || lowerText.contains("thành tiền") || lowerText.contains("total") || lowerText.contains("sum") {
            isTotal = true
        } else if lowerText.contains("mỗi") || lowerText.contains("từng") || lowerText.contains("unit") || lowerText.contains("each") || lowerText.contains("/") || lowerText.contains("per") {
            isTotal = false
        }
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = trimmed
        
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { tokenRange, _ in
            tokens.append(String(trimmed[tokenRange]))
            return true
        }
        
        // Data holders
        var quantity: Int?
        var price: Double?
        var nameParts: [String] = []
        
        // Regex for price with suffix (e.g., 30k, 30k, 50.000)
        // Matches number followed optionally by 'k' or 'd'/'đ'
        let priceRegex = try? NSRegularExpression(pattern: "^(\\d+(?:[.,]\\d+)?)(k|đ|d)?$", options: .caseInsensitive)
        
        // Pass 1: Identify clear roles (Numbers, Prices)
        var usedIndices = Set<Int>()
        
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            let lowerToken = token.lowercased()
            var handled = false
            
            // Check if it matches price pattern (has k/d suffix or is large number)
            if let match = priceRegex?.firstMatch(in: lowerToken, range: NSRange(location: 0, length: lowerToken.utf16.count)) {
                let numberRange = match.range(at: 1)
                if let swiftRange = Range(numberRange, in: lowerToken) {
                    var numberString = String(lowerToken[swiftRange])
                    
                    // Smart Number Parsing for Vietnamese Context
                    // Handle "2.000" or "2,000" as 2000 (Thousands separator)
                    // Handle "2,5" or "2.5" as 2.5 (Decimal separator)
                    
                    let hasDot = numberString.contains(".")
                    let hasComma = numberString.contains(",")
                    
                    if hasDot || hasComma {
                        // Normalize separators to a common char for analysis
                        let unified = numberString.replacingOccurrences(of: ",", with: ".")
                        let parts = unified.components(separatedBy: ".")
                        
                        if let lastPart = parts.last, lastPart.count == 3 {
                            // High probability of thousands separator (e.g., 2.000 or 1.500)
                            // Remove all non-numeric characters to treat as integer
                            numberString = numberString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        } else {
                            // Probable decimal (e.g., 2.5 or 2,5)
                            // Replace comma with dot for Swift Double parsing
                            numberString = numberString.replacingOccurrences(of: ",", with: ".")
                        }
                    }

                    if let value = Double(numberString) {
                        let suffixRange = match.range(at: 2)
                        let hasSuffix = suffixRange.location != NSNotFound
                        
                        // Check for detached suffix in next token (e.g. "30" "k")
                        var effectiveMultiplier: Double = 1.0
                        var consumedNextToken = false
                        
                        if !hasSuffix && i + 1 < tokens.count {
                            let nextToken = tokens[i+1].lowercased()
                            if ["k", "nghìn", "nghin"].contains(nextToken) {
                                effectiveMultiplier = 1000.0
                                consumedNextToken = true
                            } else if ["đ", "d", "vnd"].contains(nextToken) {
                                consumedNextToken = true
                            }
                        }
                        
                        // Heuristic: If > 1000 or has suffix (attached or detached), it's definitely PRICE
                        if hasSuffix {
                            // "30k" -> 30000
                            let suffix = (lowerToken as NSString).substring(with: suffixRange).lowercased()
                            if suffix == "k" {
                                price = value * 1000
                            } else {
                                price = value
                            }
                            usedIndices.insert(i)
                            handled = true
                        } else if effectiveMultiplier > 1.0 {
                            price = value * effectiveMultiplier
                            usedIndices.insert(i)
                            usedIndices.insert(i+1)
                            i += 1 // Skip next token
                            handled = true
                        } else if value >= 1000 {
                            price = value
                            usedIndices.insert(i)
                            if consumedNextToken {
                                usedIndices.insert(i+1)
                                i += 1
                            }
                            handled = true
                        }
                    }
                }
            }
            i += 1
        }
        
        // Pass 2: Identify Quantity (Small integers that weren't prices)
        // Also handle Vietnamese number words (một, hai, ba...)
        let numberWords: [String: Int] = [
            "một": 1, "mot": 1,
            "hai": 2,
            "ba": 3,
            "bốn": 4, "bon": 4,
            "năm": 5, "nam": 5,
            "sáu": 6, "sau": 6,
            "bảy": 7, "bay": 7,
            "tám": 8, "tam": 8,
            "chín": 9, "chin": 9,
            "mười": 10, "muoi": 10
        ]
        
        if quantity == nil {
            for (index, token) in tokens.enumerated() {
                if usedIndices.contains(index) { continue }
                
                let lowerToken = token.lowercased()
                
                // Check for numeric digit
                if let val = Int(token), val > 0 && val < 1000 {
                    quantity = val
                    usedIndices.insert(index)
                    break
                }
                
                // Check for number word
                if let val = numberWords[lowerToken] {
                    quantity = val
                    usedIndices.insert(index)
                    break
                }
            }
        }
        
        // Pass 3: Everything else is Name
        for (index, token) in tokens.enumerated() {
            if !usedIndices.contains(index) {
                nameParts.append(token)
            }
        }
        
        let finalName = nameParts.joined(separator: " ")
        if finalName.isEmpty { return nil }
        
        return (name: finalName, quantity: quantity ?? 1, price: price ?? 0, isTotal: isTotal)
    }
}
