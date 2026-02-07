import SwiftUI

struct AddOperatingExpenseView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""
    
    // Common suggestions for Operating Expenses
    let suggestions = ["Tiền nhà", "Tiền điện", "Tiền nước", "Lương nhân viên", "Internet", "Văn phòng phẩm", "Marketing"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thông tin chi phí")) {
                    TextField("Tên khoản chi (VD: Tiền nhà)", text: $title)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: { title = suggestion }) {
                                    Text(suggestion)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(15)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Số tiền", text: $amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { newValue in
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                amount = filtered
                            }
                        }
                    
                    if let value = parseDouble(amount) {
                        Text(formatCurrency(value))
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                    
                    TextField("Ghi chú (Tùy chọn)", text: $note)
                }
            }
            .navigationTitle("Thêm chi phí vận hành")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        if let value = parseDouble(amount), !title.isEmpty {
                            viewModel.addOperatingExpense(title: title, amount: value, note: note.isEmpty ? nil : note)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty || parseDouble(amount) == nil)
                }
            }
        }
    }
    
    // Helper to parse localized double strings
    private func parseDouble(_ string: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current // Use device locale
        formatter.numberStyle = .decimal
        // Try current locale first
        if let number = formatter.number(from: string) {
            return number.doubleValue
        }
        // Fallback to dot as decimal separator
        let dotString = string.replacingOccurrences(of: ",", with: ".")
        return Double(dotString)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
