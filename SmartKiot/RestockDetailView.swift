import SwiftUI

struct RestockDetailView: View {
    let bill: RestockBill
    @ObservedObject var viewModel: OrderViewModel
    @Binding var showNewRestock: Bool
    @Environment(\.dismiss) var dismiss
    @State private var showEditHistory = false
    @State private var showDeleteConfirmation = false
    
    // Computed properties for cost breakdown
    var totalMerchandiseCost: Double {
        bill.items.reduce(0) { acc, item in
            let isMaterial = item.category?.lowercased() == Category.materials.rawValue.lowercased()
            let base = isMaterial ? (item.unitPrice * (Double(item.quantity) / 1000.0)) : (item.unitPrice * Double(item.quantity))
            return acc + base
        }
    }
    
    var totalAdditionalCost: Double {
        bill.items.reduce(0) { $0 + $1.additionalCost }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: General Info
                Section {
                    HStack {
                        Text("Ngày nhập")
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatDate(bill.createdAt))
                            .fontWeight(.medium)
                        if let stt = bill.sequenceNumber {
                            Text("• \(stt)")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    if let name = bill.creatorName, !name.isEmpty {
                        HStack {
                            Text("Nhân viên")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(name)
                                .fontWeight(.medium)
                        }
                    }
                    if let supplierName = bill.supplierName, !supplierName.isEmpty {
                        HStack {
                            Text("Cơ sở cung cấp")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(supplierName)
                                .fontWeight(.medium)
                        }
                    }
                    if let supplierPhone = bill.supplierPhone, !supplierPhone.isEmpty {
                        HStack {
                            Text("Số điện thoại")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(supplierPhone)
                                .fontWeight(.medium)
                        }
                    }
                    if let supplierAddress = bill.supplierAddress, !supplierAddress.isEmpty {
                        HStack {
                            Text("Địa chỉ")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(supplierAddress)
                                .fontWeight(.medium)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let note = bill.note, !note.isEmpty {
                        HStack(alignment: .top) {
                            Text("Ghi chú")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(note)
                                .fontWeight(.medium)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if bill.isDeleted {
                        HStack {
                            Text("Trạng thái")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text("Đã xoá")
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
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
                                Text(highlightedName(item.name))
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(item.totalCost))
                                    .fontWeight(.bold)
                            }
                            
                            Divider()
                            
                            // Details Grid
                            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                                GridRow {
                                    Text("Số lượng:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text("\(item.quantity)")
                                        .font(.caption)
                                }
                                
                                GridRow {
                                    Text("Đơn giá:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text(formatCurrency(item.unitPrice))
                                        .font(.caption)
                                }
                                
                                if item.additionalCost > 0 {
                                    GridRow {
                                        Text("Chi phí thêm:")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
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
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Text("Tổng cộng")
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(bill.totalCost))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themePrimary)
                    }
                } header: {
                    Text("Tổng kết tài chính")
                }
            }
            .navigationTitle("Chi tiết phiếu nhập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !bill.isDeleted {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Xóa")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !bill.isDeleted {
                        Button {
                            dismiss()
                            viewModel.editRestockBill(bill)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showNewRestock = true
                            }
                        } label: {
                            Text("Sửa")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.editedRestockBillIds.contains(bill.id) {
                        Button {
                            showEditHistory = true
                        } label: {
                            Text("Lịch sử")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditHistory) {
                RestockEditHistorySheet(viewModel: viewModel, restockBillId: bill.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Xóa phiếu nhập?", isPresented: $showDeleteConfirmation) {
                Button("Hủy", role: .cancel) { }
                Button("Xóa", role: .destructive) {
                    Task {
                        await viewModel.softDeleteRestockBill(bill)
                        dismiss()
                    }
                }
            } message: {
                Text("Phiếu sẽ được đánh dấu đã xoá và tồn kho/giá nhập sẽ được khôi phục. Phiếu vẫn còn trong lịch sử.")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        return formatter.string(from: NSNumber(value: amount)) ?? "0 đ"
    }
    
    private func highlightedName(_ name: String) -> AttributedString {
        var s = AttributedString(name)
        if let r = s.range(of: "sữa", options: .caseInsensitive) {
            s[r].foregroundColor = .red
            s[r].backgroundColor = .yellow
        }
        return s
    }
}
