import SwiftUI

struct DebtListView: View {
    let orders: [Bill]
    let dateRange: String
    
    @State private var searchText = ""
    @State private var sortOption: DebtSortOption = .debtAmount
    @Environment(\.dismiss) private var dismiss
    
    enum DebtSortOption: String, CaseIterable {
        case debtAmount = "Số tiền nợ"
        case orderDate = "Ngày đặt hàng"
        case customerName = "Tên khách hàng"
        case expectedPayDate = "Hạn thanh toán"
    }
    
    private var debtOrders: [Bill] {
        orders.filter { order in
            (order.debtAmount ?? 0) > 0
        }
    }
    
    private var filteredOrders: [Bill] {
        var filtered = debtOrders
        
        // Lọc theo từ khóa tìm kiếm
        if !searchText.isEmpty {
            filtered = filtered.filter { order in
                let matchesCustomer = order.customerName?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesPhone = order.customerPhone?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesOrderCode = order.sequenceNumber?.localizedCaseInsensitiveContains(searchText) ?? false
                return matchesCustomer || matchesPhone || matchesOrderCode
            }
        }
        
        // Sắp xếp
        switch sortOption {
        case .debtAmount:
            return filtered.sorted { ($0.debtAmount ?? 0) > ($1.debtAmount ?? 0) }
        case .orderDate:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .customerName:
            return filtered.sorted { ($0.customerName ?? "") < ($1.customerName ?? "") }
        case .expectedPayDate:
            return filtered.sorted { order1, order2 in
                let date1 = order1.expectedPayDate ?? Date.distantFuture
                let date2 = order2.expectedPayDate ?? Date.distantFuture
                return date1 < date2
            }
        }
    }
    
    private var debtStats: (totalDebt: Double, customerCount: Int, overdueCount: Int) {
        let totalDebt = debtOrders.reduce(0) { $0 + ($1.debtAmount ?? 0) }
        let customerCount = Set(debtOrders.compactMap { $0.customerName }).count
        let overdueCount = debtOrders.filter { order in
            guard let expectedDate = order.expectedPayDate else { return false }
            return expectedDate < Date()
        }.count
        
        return (totalDebt, customerCount, overdueCount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header thống kê tóm tắt
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng công nợ")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(debtStats.totalDebt))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Số khách hàng")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(debtStats.customerCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quá hạn")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(debtStats.overdueCount)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(debtStats.overdueCount > 0 ? .red : .green)
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
                
                // Bộ lọc và tìm kiếm
                VStack(spacing: 12) {
                    // Thanh tìm kiếm
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        
                        TextField("Tìm kiếm khách hàng...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Sắp xếp
                    HStack {
                        Text("Sắp xếp:")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(DebtSortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if option == sortOption {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortOption.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.themePrimary.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Danh sách công nợ
                if filteredOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "checkmark.circle" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "Không có công nợ trong khoảng thời gian này" : "Không tìm thấy khách hàng nào")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        
                        if searchText.isEmpty {
                            Text("Tất cả khách hàng đã thanh toán đầy đủ")
                                .font(.subheadline)
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                } else {
                    List {
                        ForEach(filteredOrders) { order in
                            DebtRow(order: order)
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
            .navigationTitle("Danh sách công nợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct DebtRow: View {
    let order: Bill
    
    private var isOverdue: Bool {
        guard let expectedDate = order.expectedPayDate else { return false }
        return expectedDate < Date()
    }
    
    private var daysDifference: Int {
        guard let expectedDate = order.expectedPayDate else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: expectedDate).day ?? 0
        return days
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header với thông tin khách hàng
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(order.customerName ?? "Khách vãng lai")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themeTextDark)
                        
                        if isOverdue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    if let phone = order.customerPhone, !phone.isEmpty {
                        Text("📞 \(phone)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    if let address = order.customerAddress, !address.isEmpty {
                        Text("📍 \(address)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(order.debtAmount ?? 0))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    
                    Text("Đơn #\(order.sequenceNumber ?? "---")")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            // Thông tin đơn hàng và thanh toán
            VStack(spacing: 6) {
                HStack {
                    Label("Tổng đơn:", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(formatCurrency(order.total))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.themeTextDark)
                    
                    Spacer()
                    
                    Label("Đã trả:", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(formatCurrency(order.paidAmount ?? 0))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                
                HStack {
                    Label("Ngày đặt:", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(formatOrderDate(order.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.themeTextDark)
                    
                    Spacer()
                    
                    if let expectedDate = order.expectedPayDate {
                        Label("Hạn trả:", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : .blue)
                        Text(formatOrderDate(expectedDate))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(isOverdue ? .red : .blue)
                    }
                }
                
                // Trạng thái thanh toán
                HStack {
                    if isOverdue {
                        Label("Quá hạn \(-daysDifference) ngày", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    } else if daysDifference <= 3 {
                        Label("Sắp đến hạn", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    if let note = order.note, !note.isEmpty {
                        Text("📝 \(note)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    private func formatOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    DebtListView(
        orders: [],
        dateRange: "01/01/2024 - 31/01/2024"
    )
}