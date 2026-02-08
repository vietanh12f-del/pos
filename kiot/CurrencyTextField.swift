import SwiftUI

struct CurrencyTextField: View {
    var title: String
    @Binding var text: String
    var font: Font = .body
    var foregroundStyle: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            
            TextField("0", text: Binding(
                get: {
                    if text.isEmpty { return "" }
                    if let doubleValue = Double(text) {
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .decimal
                        formatter.groupingSeparator = ","
                        return formatter.string(from: NSNumber(value: doubleValue)) ?? text
                    }
                    return text
                },
                set: { newValue in
                    let filtered = newValue.filter { "0123456789.".contains($0) }
                    text = filtered
                }
            ))
            .keyboardType(.decimalPad)
            .font(font)
            .foregroundStyle(foregroundStyle)
        }
    }
}
