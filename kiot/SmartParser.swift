import Foundation
import NaturalLanguage

enum SmartIntent: String {
    case order // Bán hàng
    case restock // Nhập hàng
}

class SmartParser {
    
    /// Parses a raw string into structured order data using heuristics and NLP
    /// Supports inputs like:
    /// - "2 coffee 30k"
    /// - "coffee 30k 2"
    /// - "bún bò 2 tô 50000 giảm 10k"
    /// - "nhập 50 hoa hồng đỏ giá 5k"
    static func parse(text: String) -> (name: String, quantity: Int, price: Double, discount: Double, discountIsPercent: Bool, isTotal: Bool?, intent: SmartIntent?)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let lowerText = trimmed.lowercased()
        
        // 1. Detect Intent using NLP classification keywords
        var intent: SmartIntent? = nil
        let restockKeywords = ["nhập", "mua thêm", "restock", "về kho", "nhập kho"]
        let orderKeywords = ["bán", "khách mua", "order", "tính tiền", "lên đơn", "tạo đơn"]
        
        if restockKeywords.contains(where: { lowerText.contains($0) }) {
            intent = .restock
        } else if orderKeywords.contains(where: { lowerText.contains($0) }) {
            intent = .order
        }
        
        // 2. Detect Price Context (Total vs Unit)
        var isTotal: Bool? = nil
        if lowerText.contains("tổng") || lowerText.contains("hết") || lowerText.contains("thành tiền") || lowerText.contains("total") || lowerText.contains("sum") {
            isTotal = true
        } else if lowerText.contains("mỗi") || lowerText.contains("từng") || lowerText.contains("unit") || lowerText.contains("each") || lowerText.contains("/") || lowerText.contains("per") {
            isTotal = false
        }
        
        // Use NLTagger for better tokenization and part-of-speech tagging
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed
        
        var tokens: [String] = []
        var tokenRanges: [Range<String.Index>] = []
        
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
            tokens.append(String(trimmed[tokenRange]))
            tokenRanges.append(tokenRange)
            return true
        }
        
        // Data holders
        var quantity: Int?
        var price: Double?
        var discount: Double = 0
        var discountIsPercent: Bool = false
        var nameParts: [String] = []
        
        // Regex for price with suffix (e.g., 30k, 30k, 50.000)
        let priceRegex = try? NSRegularExpression(pattern: "^(\\d+(?:[.,]\\d+)?)(k|đ|d|%)?$", options: .caseInsensitive)
        
        // Regex for discount keywords
        let discountKeywords = ["giảm", "off", "bớt", "chiết khấu", "discount", "km"]
        
        // Pass 1: Identify clear roles (Numbers, Prices, Discounts)
        var usedIndices = Set<Int>()
        
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            let lowerToken = token.lowercased()
            
            // Check for Discount Keyword
            if discountKeywords.contains(lowerToken) {
                usedIndices.insert(i)
                // Look ahead for value
                if i + 1 < tokens.count {
                    let nextToken = tokens[i+1]
                    if let (val, indices, isPercent) = parsePriceOrNumber(token: nextToken, at: i+1, tokens: tokens, priceRegex: priceRegex) {
                        discount = val
                        discountIsPercent = isPercent
                        indices.forEach { usedIndices.insert($0) }
                        i = indices.max()! // Advance
                    }
                }
                i += 1
                continue
            }
            
            // Check for Price/Number
            // We prioritize detecting Price if it has suffix or is large
            if let (val, indices, isPercent) = parsePriceOrNumber(token: token, at: i, tokens: tokens, priceRegex: priceRegex, checkSuffix: true) {
                // If we found a price-like number
                // Check if it's likely a price or quantity
                // If > 1000 or has suffix, it's price
                // If < 1000 and integer, could be quantity, UNLESS we already have quantity
                
                let isLikelyPrice = val >= 1000 || indices.count > 1 // indices > 1 means it consumed a suffix token like 'k'
                
                if isLikelyPrice {
                    if price == nil {
                        price = val
                        indices.forEach { usedIndices.insert($0) }
                        i = indices.max()!
                    }
                } else {
                    // Ambiguous number (e.g. "50")
                    // If we haven't found quantity, assume quantity
                    if quantity == nil {
                        quantity = Int(val)
                        indices.forEach { usedIndices.insert($0) }
                        i = indices.max()!
                    } else if price == nil {
                        // We have quantity, so this must be price
                        price = val
                        indices.forEach { usedIndices.insert($0) }
                        i = indices.max()!
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
            "mười": 10, "muoi": 10,
            "chục": 10, "chuc": 10
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
        
        // Pass 3: Smart Name Extraction
        // Filter out intent keywords and filler words from name
        let intentKeywords = restockKeywords + orderKeywords + ["cho", "của", "với", "lấy"]
        
        for (index, token) in tokens.enumerated() {
            if !usedIndices.contains(index) {
                let lower = token.lowercased()
                if !intentKeywords.contains(lower) {
                    // Use NLTagger to skip verbs/conjunctions if we want strict noun parsing?
                    // For now, simple keyword filtering is safer for product names which can be anything.
                    nameParts.append(token)
                }
            }
        }
        
        let finalName = nameParts.joined(separator: " ")
        if finalName.isEmpty { return nil }
        
        return (name: finalName, quantity: quantity ?? 1, price: price ?? 0, discount: discount, discountIsPercent: discountIsPercent, isTotal: isTotal, intent: intent)
    }
    
    // Helper to parse "30k", "50.000", "2"
    private static func parsePriceOrNumber(token: String, at index: Int, tokens: [String], priceRegex: NSRegularExpression?, checkSuffix: Bool = true) -> (Double, [Int], Bool)? {
        let lowerToken = token.lowercased()
        
        if let match = priceRegex?.firstMatch(in: lowerToken, range: NSRange(location: 0, length: lowerToken.utf16.count)) {
            let numberRange = match.range(at: 1)
            if let swiftRange = Range(numberRange, in: lowerToken) {
                var numberString = String(lowerToken[swiftRange])
                
                // Normalize separators
                let hasDot = numberString.contains(".")
                let hasComma = numberString.contains(",")
                
                if hasDot || hasComma {
                    let unified = numberString.replacingOccurrences(of: ",", with: ".")
                    let parts = unified.components(separatedBy: ".")
                    
                    if let lastPart = parts.last, lastPart.count == 3 {
                        // Thousands separator (e.g., 2.000)
                        numberString = numberString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    } else {
                        // Decimal (e.g., 2.5)
                        numberString = numberString.replacingOccurrences(of: ",", with: ".")
                    }
                }

                if let value = Double(numberString) {
                    var finalValue = value
                    var consumedIndices = [index]
                    var isPercent = false
                    
                    let suffixRange = match.range(at: 2)
                    let hasSuffix = suffixRange.location != NSNotFound
                    
                    var effectiveMultiplier: Double = 1.0
                    
                    if !hasSuffix && checkSuffix && index + 1 < tokens.count {
                        let nextToken = tokens[index+1].lowercased()
                        if ["k", "nghìn", "nghin"].contains(nextToken) {
                            effectiveMultiplier = 1000.0
                            consumedIndices.append(index+1)
                        } else if ["đ", "d", "vnd"].contains(nextToken) {
                            // Just currency symbol, doesn't multiply but confirms it's a price/value
                            consumedIndices.append(index+1)
                        } else if nextToken == "%" {
                             // Percentage discount context
                             consumedIndices.append(index+1)
                             isPercent = true
                        }
                    }
                    
                    if hasSuffix {
                        let suffix = (lowerToken as NSString).substring(with: suffixRange).lowercased()
                        if suffix == "k" {
                            finalValue = value * 1000
                        } else if suffix == "%" {
                            isPercent = true
                        }
                    } else {
                        finalValue = value * effectiveMultiplier
                    }
                    
                    // Special case for % in the string itself (e.g. "10%")
                    if lowerToken.contains("%") {
                         isPercent = true
                    }
                    
                    return (finalValue, consumedIndices, isPercent)
                }
            }
        }
        return nil
    }
    
    static func findBestMatch(name: String, in products: [Product]) -> Product? {
        let normalizedInput = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        
        // 1. Exact match (insensitive)
        if let exact = products.first(where: { $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased() == normalizedInput }) {
            return exact
        }
        
        // 2. Contains match
        let containsMatches = products.filter { product in
            let pName = product.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            return pName.contains(normalizedInput) || normalizedInput.contains(pName)
        }
        
        if !containsMatches.isEmpty {
            // Pick the one with closest length
            return containsMatches.min(by: { p1, p2 in
                let p1Name = p1.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                let p2Name = p2.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                return abs(p1Name.count - normalizedInput.count) < abs(p2Name.count - normalizedInput.count)
            })
        }
        
        // 3. Fuzzy Match (Levenshtein)
        var bestMatch: Product?
        var minDistance = Int.max
        
        for product in products {
            let pName = product.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let dist = normalizedInput.levenshtein(pName)
            
            // Threshold: Allow reasonable edits (approx 40% of length for short words)
            let threshold = max(2, Int(Double(pName.count) * 0.4))
            
            if dist <= threshold && dist < minDistance {
                minDistance = dist
                bestMatch = product
            }
        }
        
        return bestMatch
    }
}

extension String {
    func levenshtein(_ other: String) -> Int {
        let s1 = Array(self)
        let s2 = Array(other)
        let (m, n) = (s1.count, s2.count)
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var d = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                d[i][j] = Swift.min(
                    d[i - 1][j] + 1,      // deletion
                    d[i][j - 1] + 1,      // insertion
                    d[i - 1][j - 1] + cost // substitution
                )
            }
        }
        return d[m][n]
    }
}
