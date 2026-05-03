import Foundation

struct FormatUtils {
    static func formatWeight(_ grams: Int, unit: String? = nil) -> String {
        if let u = unit, u.lowercased() == "cái" {
            return "\(grams) cái"
        }
        let value = Double(max(0, grams)) / 1000.0
        let remainder = max(0, grams % 1000)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.decimalSeparator = ","
        let fd = remainder == 0 ? 0 : (remainder % 100 == 0 ? 1 : 2)
        f.minimumFractionDigits = fd
        f.maximumFractionDigits = fd
        let s = f.string(from: NSNumber(value: value)) ?? "0"
        return "\(s) kg"
    }
    static func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    static func formatKgDecimal(fromGrams grams: Int) -> String {
        let value = Double(max(0, grams)) / 1000.0
        let remainder = max(0, grams % 1000)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.decimalSeparator = ","
        let fd = remainder == 0 ? 0 : (remainder % 100 == 0 ? 1 : 2)
        f.minimumFractionDigits = fd
        f.maximumFractionDigits = fd
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
    static func parseKgDecimalToGrams(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let kg = Double(normalized) else { return nil }
        let grams = Int(round(kg * 1000.0))
        return max(0, grams)
    }

    static func generateSequenceNumber() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
