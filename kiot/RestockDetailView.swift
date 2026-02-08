import SwiftUI

struct RestockDetailView: View {
    let bill: RestockBill
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showNewRestock: Bool
    @Environment(\.dismiss) var dismiss
    
    // Computed properties for cost breakdown
    var totalMerchandiseCost: Double {
        bill.items.reduce(0) { $0 + ($1.unitPrice * Double($1.quantity)) }
    }
    
    var totalAdditionalCost: Double {
        bill.items.reduce(0) { $0 + $1.additionalCost }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: General Info
                Section {
                    HStack {
                        Text("Ngày nhập")
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatDate(bill.createdAt))
                            .font(.system(.body).weight(.medium))
                    }
                    
                    HStack {
                        Text("Mã phiếu")
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(bill.id.uuidString.prefix(8).uppercased())
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                } header: {
                    Text("Thông tin chung")
                }
                
                // Section 2: Items
                Section {
                    ForEach(bill.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            // Name and Total
                            HStack {
                                Text(item.name)
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(item.totalCost))
                                    .bold()
                            }
                            
                            Divider()
                            
                            // Details Grid
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Số lượng:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .frame(width: 80, alignment: .leading)
                                    Text("\(item.quantity)")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Text("Đơn giá:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .frame(width: 80, alignment: .leading)
                                    Text(formatCurrency(item.unitPrice))
                                        .font(.caption)
                                }
                                
                                if item.additionalCost > 0 {
                                    HStack {
                                        Text("Chi phí thêm:")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .frame(width: 80, alignment: .leading)
                                        Text(formatCurrency(item.additionalCost))
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text("Hàng hóa")
                        Spacer()
                        Text("\(bill.items.count) mặt hàng")
                            .font(.caption)
                            .textCase(nil)
                    }
                }
                
                // Section 3: Cost Summary
                Section {
                    HStack {
                        Text("Tiền hàng")
                        Spacer()
                        Text(formatCurrency(totalMerchandiseCost))
                    }
                    
                    if totalAdditionalCost > 0 {
                        HStack {
                            Text("Chi phí phát sinh")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(formatCurrency(totalAdditionalCost))
                                .foregroundStyle(.orange)
                                .font(.system(.body).weight(.medium))
                        }
                    }
                    
                    HStack {
                        Text("Tổng cộng")
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(bill.totalCost))
                            .font(.title3)
                            .bold()
                            .foregroundStyle(Color.themePrimary)
                    }
                } header: {
                    Text("Tổng kết tài chính")
                }
            }
            .navigationTitle("Chi tiết phiếu nhập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sửa") {
                        // Trigger edit mode
                        // 1. Dismiss this detail view
                        dismiss()
                        
                        // 2. Trigger edit in ViewModel (which reverts inventory and loads items)
                        viewModel.editRestockBill(bill)
                        
                        // 3. Open the RestockEntryView
                        // We need a slight delay or binding update to ensure the sheet opens after dismiss
                        // But since showNewRestock is a binding passed from InventoryView, setting it true here 
                        // might conflict with the dismissal of this sheet if they are managed by the same parent state?
                        // Actually, 'selectedRestockBill' controls THIS sheet. 'showNewRestock' controls the OTHER sheet.
                        // If we set showNewRestock = true immediately, SwiftUI might complain about presenting a sheet while dismissing another.
                        // Let's try executing it on the main thread with a slight delay.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showNewRestock = true
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
