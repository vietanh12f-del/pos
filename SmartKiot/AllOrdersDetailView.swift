import SwiftUI

struct AllOrdersDetailView: View {
    let orders: [Bill]
    let dateRange: String
    
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    private var filteredOrders: [Bill] {
        if searchText.isEmpty {
            return orders.sorted { $0.createdAt > $1.createdAt }
        } else {
            return orders.filter { order in
                // Tìm kiếm theo mã đơn, tên nhân viên, hoặc tên sản phẩm
                let matchesCode = order.sequenceNumber?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesEmployee = order.creatorName?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesProduct = order.items.contains { item in
                    item.name.localizedCaseInsensitiveContains(searchText)
                }
                return matchesCode || matchesEmployee || matchesProduct
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header với thống kê tóm tắt
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng đơn hàng")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(orders.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tổng doanh thu")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(orders.reduce(0) { $0 + $1.total }))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Số lượng sản phẩm")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            let totalQuantity = orders.reduce(0) { total, order in
                                total + order.items.reduce(0) { sum, item in sum + item.quantity }
                            }
                            
                            Text("\(totalQuantity)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Khoảng thời gian")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(dateRange)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                .padding()
                
                // Thanh tìm kiếm
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    
                    TextField("Tìm kiếm đơn hàng...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Danh sách đơn hàng
                if filteredOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "Không có đơn hàng trong khoảng thời gian này" : "Không tìm thấy đơn hàng nào")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        
                        if !searchText.isEmpty {
                            Text("Thử tìm kiếm với từ khóa khác")
                                .font(.subheadline)
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                } else {
                    List {
                        ForEach(filteredOrders) { order in
                            OrderDetailRow(order: order)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.themeBackgroundLight)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.themeBackgroundLight)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Chi tiết tất cả đơn hàng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct OrderDetailRow: View {
    @ObservedObject private var authManager = AuthManager.shared
    let order: Bill
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header với mã đơn và thời gian
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Đơn #\(order.sequenceNumber ?? "---")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themeTextDark)
                        
                        if let creator = order.creatorName, !creator.isEmpty {
                            Text("• \(creator)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    Text(formatOrderTime(order.createdAt))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(order.total))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themePrimary)
                    
                    Text("\(order.items.reduce(0) { $0 + $1.quantity }) SP")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            
            // Danh sách sản phẩm
            VStack(alignment: .leading, spacing: 6) {
                ForEach(order.items.indices, id: \.self) { index in
                    let item = order.items[index]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(item.quantity)x")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.themePrimary)
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.themeTextDark)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            priceColumn("Giá bán / SP", amount: item.price)
                            if authManager.canViewCostPrice {
                                priceColumn("Giá vốn / SP", amount: item.costPrice)
                            }
                            priceColumn("Thành tiền", amount: item.total)
                        }
                    }
                    .padding(.vertical, 6)
                    if index < order.items.count - 1 { Divider() }
                }
            }
            .padding(.leading, 8)
            
            // Thông tin thanh toán
            if order.isPaid {
                HStack {
                    Label("Đã thanh toán", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    if let paidAmount = order.paidAmount {
                        Text("Đã trả: \(formatCurrency(paidAmount))")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    if let debt = order.debtAmount, debt > 0 {
                        Text("Còn nợ: \(formatCurrency(debt))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    private func priceColumn(_ title: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.gray)
            Text(formatCurrency(amount))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.themeTextDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatOrderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    AllOrdersDetailView(
        orders: [],
        dateRange: "01/01/2024 - 31/01/2024"
    )
}