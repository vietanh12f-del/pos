import SwiftUI

struct OrderHistoryView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var navigateToBillId: UUID?
    @State private var selectedBill: Bill?
    @State private var highlightedBillId: UUID?
    @State private var showSoldSearch: Bool = false
    @State private var soldSearchText: String = ""
    @State private var soldStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var soldEndDate: Date = Date()
    
    init(viewModel: OrderViewModel, navigateToBillId: Binding<UUID?> = .constant(nil)) {
        self.viewModel = viewModel
        self._navigateToBillId = navigateToBillId
        // Customize Navigation Bar Title Appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBackgroundLight.ignoresSafeArea()
                
                if !StoreManager.shared.hasPermission(.viewOrders) {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Bạn không có quyền xem lịch sử đơn hàng")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else if viewModel.pastOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        Text("Chưa có đơn hàng nào")
                            .font(.headline)
                            .foregroundStyle(Color.gray)
                    }
                } else {
                    ScrollViewReader { proxy in
                    List {
                        ForEach(sections, id: \.title) { section in
                            Section(header: Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gray)
                                .padding(.vertical, 4)) {
                                    ForEach(section.bills) { bill in
                                        Button(action: { selectedBill = bill }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(formatTime(bill.createdAt))
                                                            .font(.caption)
                                                            .foregroundStyle(Color.gray)
                                                        
                                                        if let stt = bill.sequenceNumber {
                                                            Text("• \(stt)")
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                                .foregroundStyle(Color.themePrimary)
                                                        }
                                                    }
                                                    
                                                    Text(billItemsSummary(bill))
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(Color.themeTextDark)
                                                        .lineLimit(1)
                                                    
                                                    if let creator = bill.creatorName {
                                                        Text("Người tạo: \(creator)")
                                                            .font(.caption2)
                                                            .foregroundStyle(Color.gray)
                                                    }
                                                    if let customer = bill.customerName, !customer.isEmpty {
                                                        Text("Khách: \(customer)")
                                                            .font(.caption2)
                                                            .foregroundStyle(Color.gray)
                                                    }
                                                    if viewModel.hasHistory(for: bill.id) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "clock.arrow.circlepath")
                                                                .font(.caption2)
                                                                .foregroundStyle(.orange)
                                                            Text("Đã chỉnh sửa")
                                                                .font(.caption2)
                                                                .fontWeight(.bold)
                                                                .foregroundStyle(.orange)
                                                        }
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange.opacity(0.08))
                                                        .cornerRadius(6)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(formatCurrency(bill.total))
                                                        .font(.headline)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(bill.isPaid ? Color.themePrimary : Color.red)
                                                    
                                                    if !bill.isPaid {
                                                        Text("Chưa nhận tiền")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(Color.red)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.red.opacity(0.1))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        .listRowBackground(
                                            highlightedBillId == bill.id
                                                ? Color.themePrimary.opacity(0.08)
                                                : Color.white
                                        )
                                        .id(bill.id)
                                        .contextMenu {
                                            Button(action: {
                                                viewModel.startEditing(bill)
                                            }) {
                                                Label("Sửa", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                viewModel.deleteOrder(bill)
                                            }) {
                                                Label("Xóa", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .onDelete { indexSet in
                                        for index in indexSet {
                                            let bill = section.bills[index]
                                            viewModel.deleteOrder(bill)
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await viewModel.loadData(force: true) }
                    .scrollContentBackground(.hidden)
                    .background(Color.themeBackgroundLight)
                    .onChange(of: highlightedBillId) { _, billId in
                        if let billId {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(billId, anchor: .center)
                            }
                        }
                    }
                    } // end ScrollViewReader
                }
            }
            .navigationTitle("Lịch sử đơn hàng")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSoldSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                    }
                }
            }
            .sheet(item: $selectedBill) { bill in
                BillDetailView(bill: bill, viewModel: viewModel)
            }
            .onChange(of: navigateToBillId) { _, billId in
                guard let billId else { return }
                if let bill = viewModel.pastOrders.first(where: { $0.id == billId }) {
                    selectedBill = bill
                    highlightedBillId = billId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        highlightedBillId = nil
                    }
                }
                navigateToBillId = nil
            }
            .sheet(isPresented: $showSoldSearch) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("Sản phẩm đã bán")
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.gray)
                            DatePicker("Từ", selection: $soldStartDate, displayedComponents: .date)
                            DatePicker("Đến", selection: $soldEndDate, displayedComponents: .date)
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.gray)
                            TextField("Tìm theo tên sản phẩm", text: $soldSearchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !soldSearchText.isEmpty {
                                Button(action: { soldSearchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        let sold = viewModel.soldProductsTotals(
                            range: .custom(start: soldStartDate, end: soldEndDate),
                            search: soldSearchText
                        )
                        
                        List {
                            ForEach(sold, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    Text("\(item.quantity)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.gray)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .listStyle(.plain)
                    }
                    .navigationTitle("Tìm kiếm")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Đóng") { showSoldSearch = false }
                        }
                    }
                    .background(Color.themeBackgroundLight)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    var sections: [(title: String, bills: [Bill])] {
        let grouped = Dictionary(grouping: viewModel.pastOrders) { bill -> Date in
            Calendar.current.startOfDay(for: bill.createdAt)
        }
        
        return grouped.keys.sorted(by: >).map { date in
            let title: String
            if Calendar.current.isDateInToday(date) {
                title = "Hôm nay"
            } else if Calendar.current.isDateInYesterday(date) {
                title = "Hôm qua"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "vi_VN")
                formatter.dateFormat = "dd/MM/yyyy"
                title = formatter.string(from: date)
            }
            let bills = grouped[date]?.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
            return (title: title, bills: bills)
        }
    }
}
