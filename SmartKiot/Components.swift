import SwiftUI

// MARK: - Theme Colors
extension Color {
    static let themePrimary = Color(red: 25/255, green: 230/255, blue: 196/255)
    static let themeBackgroundLight = Color(red: 246/255, green: 248/255, blue: 248/255)
    static let themeBackgroundDark = Color(red: 17/255, green: 33/255, blue: 30/255)
    static let themeTextDark = Color(red: 17/255, green: 24/255, blue: 23/255)
}

// MARK: - Helpers
func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "vi_VN")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func colorForString(_ name: String) -> Color {
    switch name {
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "pink": return .pink
    case "gray": return .gray
    case "black": return .black
    case "brown": return .brown
    default: return .gray
    }
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.timeZone = .current
    return formatter.string(from: date)
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.timeZone = .current
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter.string(from: date)
}

func formatDateShort(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter.string(from: date)
}

func billItemsSummary(_ bill: Bill) -> String {
    if bill.items.isEmpty { return "No items" }
    let items = bill.items.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", ")
    return items
}

// MARK: - Components

struct TabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray.opacity(0.5))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(), value: isSelected)
                
                if isSelected {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: isSelected ? 50 : 35) // Reduced width for fitting 6 items
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: String
    let isPositive: Bool
    var info: String? = nil

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
                Spacer()
                if let info {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .alert(title, isPresented: $showInfo) {
                        Button("Đã hiểu", role: .cancel) {}
                    } message: {
                        Text(info)
                    }
                }
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
            
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(trend)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(isPositive ? Color.green : Color.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct ToggleableFeeStatCard: View {
    @Binding var selectedBearer: String
    let shopValue: String
    let customerValue: String
    @State private var showInfo = false

    private var isShopSelected: Bool { selectedBearer == "shop" }
    private var title: String { isShopSelected ? "Phí shop chịu" : "Phí khách chịu" }
    private var value: String { isShopSelected ? shopValue : customerValue }
    private var icon: String { isShopSelected ? "truck.box" : "person.fill" }
    private var info: String {
        isShopSelected
        ? "Phí shop chịu của các đơn trong kỳ. Không cộng vào tiền khách trả; được trừ một lần khi tính lợi nhuận."
        : "Phí khách chịu của các đơn trong kỳ. Đây là khoản khách trả hoặc shop thu hộ; không trừ vào lợi nhuận như phí shop chịu."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
                Menu {
                    Button {
                        selectedBearer = "shop"
                    } label: {
                        Label("Phí shop chịu", systemImage: isShopSelected ? "checkmark" : "truck.box")
                    }
                    Button {
                        selectedBearer = "customer"
                    } label: {
                        Label("Phí khách chịu", systemImage: !isShopSelected ? "checkmark" : "person")
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.themePrimary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .alert(title, isPresented: $showInfo) {
                    Button("Đã hiểu", role: .cancel) {}
                } message: {
                    Text(info)
                }
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(isShopSelected ? Color.red : Color.green)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPrimary ? Color.themePrimary : Color.white)
            .foregroundStyle(isPrimary ? Color.white : Color.themeTextDark)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: isPrimary ? 0 : 1)
            )
        }
    }
}

struct OrderRow: View {
    let bill: Bill
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(bill.createdAt))
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                if let stt = bill.sequenceNumber {
                    Text(stt)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text(billItemsSummary(bill))
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextDark)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formatCurrency(bill.total))
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
