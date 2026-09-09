import SwiftUI
import Combine
import Supabase

struct CostsAndImportsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Binding var selectedSubTab: Int // 0: Vận hành, 1: Phát sinh
    @Binding var showNewOperatingExpense: Bool
    @ObservedObject private var storeManager = StoreManager.shared
    
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    
    private func exportReport(_ range: ReportDateRange) {
        if let url = viewModel.exportFinancialReport(range: range) {
            self.exportURL = url
            self.showExportSheet = true
        }
    }
    
    private var canViewOperatingCosts: Bool {
        storeManager.hasPermission(.viewExpenses)
    }
    
    // Nhập hàng bị bỏ, chỉ còn chi phí vận hành
    
    var body: some View {
        NavigationStack {
            if canViewOperatingCosts {
                VStack(spacing: 0) {
                    if storeManager.currentMember?.role == .owner {
                        PendingEmployeeAdvanceCard(viewModel: viewModel).padding(.horizontal)
                    }
                    // Header
                    HStack {
                        Text("CHI PHÍ")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.themeTextDark)
                        Spacer()
                        
                        if selectedSubTab == 0 && canViewOperatingCosts {
                            // Redundant button removed
                        }
                        
                        Menu {
                            Button("Hôm nay") { exportReport(.today) }
                            Button("Tuần này") { exportReport(.thisWeek) }
                            Button("Tháng này") { exportReport(.thisMonth) }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    
                    // Bỏ phân tab, luôn hiển thị Chi phí vận hành
                    
                    if canViewOperatingCosts {
                        OperatingCostsList(viewModel: viewModel)
                    } else {
                        AccessDeniedView(title: "Vận hành")
                    }
                }
                .navigationTitle("Chi phí")
                .navigationBarHidden(true)
                .background(Color(UIColor.systemGroupedBackground))
                .sheet(isPresented: $showExportSheet) {
                    if let url = exportURL {
                        ShareSheet(items: [url])
                    }
                }
            } else {
                AccessDeniedView(title: "Chi phí & Nhập hàng")
            }
        }
    }
}

struct AccessDeniedView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("Không có quyền truy cập")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
            
            Text("Bạn cần quyền 'Xem Chi phí' để xem nội dung này.\nVui lòng liên hệ chủ cửa hàng.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarHidden(true)
    }
}

// MARK: - Subviews

struct CostsTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
                
                Rectangle()
                    .fill(isSelected ? Color.themePrimary : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
    }
}

struct OperatingCostsList: View {
    @ObservedObject var viewModel: OrderViewModel
    @State private var expenseToEdit: OperatingExpense?
    
    var body: some View {
        List {
            if viewModel.operatingExpenses.isEmpty {
                Text("Chưa có chi phí vận hành nào.")
                    .foregroundStyle(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.operatingExpenses) { expense in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(expense.createdAt))
                                .font(.caption)
                                .foregroundStyle(.gray)
                            if let name = expense.creatorName, !name.isEmpty {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Text(formatCurrency(expense.amount))
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        
                        Text(expense.title)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if let note = expense.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading) {
                        Button {
                            expenseToEdit = expense
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteOperatingExpense(viewModel.operatingExpenses[index])
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadData(force: true) }
        .sheet(item: $expenseToEdit) { expense in
            AddOperatingExpenseView(viewModel: viewModel, existingExpense: expense)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct ImportCostsList: View {
    @ObservedObject var viewModel: OrderViewModel
    
    var body: some View {
        List {
            if viewModel.restockHistory.isEmpty {
                Text("Chưa có lịch sử nhập hàng.")
                    .foregroundStyle(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.restockHistory) { bill in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(bill.createdAt))
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            if let stt = bill.sequenceNumber {
                                Text("• \(stt)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.themePrimary)
                            }
                            
                            if let name = bill.creatorName, !name.isEmpty {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                        }
                        
                        // Profit Impact Badge
                        let profitImpact = bill.items.reduce(0) { $0 + $1.additionalCost }
                        if profitImpact > 0 {
                            HStack {
                                Spacer()
                                Text("Giảm lợi nhuận: -\(formatCurrency(profitImpact))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(4)
                            }
                            .padding(.top, 2)
                        }
                        
                        Divider()
                        
                        // Itemized List
                        ForEach(bill.items) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundStyle(.gray)
                                VStack(alignment: .leading) {
                                    Text("\(item.name)")
                                        .fontWeight(.medium)
                                    Text("SL: \(item.quantity) x \(formatCurrency(item.unitPrice))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if item.additionalCost > 0 {
                                        Text("+ Chi phí khác: \(formatCurrency(item.additionalCost))")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteRestockBill(bill)
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.editRestockBill(bill)
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                // No delete here for now, or add if needed (viewModel.deleteRestockBill)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadData(force: true) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Order fees and employee reimbursements
struct EmployeeAdvance: Identifiable, Decodable {
    let id: UUID
    let orderID: UUID
    let sequence: String
    let createdAt: Date
    let fee: OrderFee
    let deleted: Bool
    let settledAt: Date?
    let settledBy: UUID?
    let batchID: UUID?
}

@MainActor
final class EmployeeAdvanceStore: ObservableObject {
    static let shared = EmployeeAdvanceStore()
    @Published var advances: [EmployeeAdvance] = []
    @Published var loading = false
    @Published var error: String?
    private var storeID: UUID?
    var pendingTotal: Double { advances.filter { $0.settledAt == nil }.reduce(0) { $0 + $1.fee.amount } }

    func refresh() async {
        guard let id = StoreManager.shared.currentStore?.id,
              StoreManager.shared.currentMember?.role == .owner else { advances = []; return }
        if storeID != id { advances = []; storeID = id }
        loading = true
        error = nil
        defer { loading = false }
        do {
            struct Params: Encodable { let p_store: UUID }
            let result: [EmployeeAdvance] = try await SupabaseConfig.client.database
                .rpc("list_employee_advances", params: Params(p_store: id)).execute().value
            guard StoreManager.shared.currentStore?.id == id else { return }
            advances = result
        } catch { self.error = "Không tải được khoản hoàn ứng. Vui lòng thử lại.\n\(error.localizedDescription)" }
    }

    func settle(_ ids: [UUID]) async throws {
        guard let id = StoreManager.shared.currentStore?.id else { return }
        struct Params: Encodable { let p_store: UUID; let p_fees: [UUID]; let p_expected: [OrderFee] }
        _ = try await SupabaseConfig.client.database.rpc("settle_employee_advances", params: Params(p_store: id, p_fees: ids, p_expected: advances.filter { ids.contains($0.id) }.map(\.fee))).execute()
        await refresh()
    }
    func undo(_ batch: UUID) async throws {
        guard let id = StoreManager.shared.currentStore?.id else { return }
        struct Params: Encodable { let p_store: UUID; let p_batch: UUID }
        _ = try await SupabaseConfig.client.database.rpc("undo_employee_settlement", params: Params(p_store: id, p_batch: batch)).execute()
        await refresh()
    }
}

struct OrderFeeEditor: View {
    @ObservedObject private var advances = EmployeeAdvanceStore.shared
    private func isSettled(_ id: UUID) -> Bool { advances.advances.contains { $0.id == id && $0.settledAt != nil } }
    @Binding var fees: [OrderFee]
    @State private var draft: [OrderFee]
    @State private var names = ["Phí chành xe", "Phí giao hàng"]
    @State private var employees: [(StoreMember, String)] = []
    @State private var newName = ""
    @State private var error: String?
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss
    init(fees: Binding<[OrderFee]>) {
        _fees = fees
        _draft = State(initialValue: fees.wrappedValue)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Chọn loại phí") {
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Button {
                                if let i = draft.firstIndex(where: { $0.name == name }) { draft.remove(at: i) }
                                else { draft.append(OrderFee(name: name)) }
                            } label: {
                                Label(name, systemImage: draft.contains(where: { $0.name == name }) ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(draft.first(where: { $0.name == name }).map { isSettled($0.id) } ?? false)
                            Spacer()
                            Text(formatCurrency(draft.first(where: { $0.name == name })?.amount ?? 0))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        TextField("Tên phí khác", text: $newName)
                        Button("Tạo") { Task { await addType() } }
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                    }
                }
                ForEach($draft) { $fee in
                    Section {
                        if isSettled(fee.id) {
                            Text("Đã hoàn ứng. Cần hoàn tác trong Hoàn ứng nhân viên trước khi sửa khoản này.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        feeFields(fee: $fee)
                            .disabled(isSettled(fee.id))
                    } header: { Text(fee.name) }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Chi phí đơn hàng")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { fees = draft; dismiss() }.disabled(!draft.allSatisfy(\.isValid) || busy)
                }
            }
            .task { await load() }
        }
    }

    private func feeFields(fee: Binding<OrderFee>) -> some View {
        FeeFields(fee: fee, employees: employees)
    }
    private struct FeeFields: View {
        @Binding var fee: OrderFee
        let employees: [(StoreMember, String)]
        var body: some View {
            Group {
                        HStack {
                            Text("Số tiền")
                            TextField("0", value: $fee.amount, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        Picker("Bên chịu phí", selection: $fee.bearer) {
                            Text("Shop chịu").tag("shop")
                            Text("Khách chịu").tag("customer")
                        }
                        .onChange(of: fee.bearer) { bearer in
                            if bearer == "shop" && fee.funding == "customer" { fee.funding = "company" }
                        }
                        Picker("Nguồn tiền", selection: $fee.funding) {
                            Text("Công ty").tag("company")
                            Text("Nhân viên ứng trước").tag("employee")
                            if fee.bearer == "customer" { Text("Khách trả trực tiếp").tag("customer") }
                        }
                        if fee.funding == "employee" {
                            Picker("Nhân viên", selection: $fee.employeeID) {
                                Text("Chọn nhân viên").tag(nil as UUID?)
                                ForEach(employees, id: \.0.id) { member, name in
                                    Text(name).tag(Optional(member.id))
                                }
                                if let id = fee.employeeID, !employees.contains(where: { $0.0.id == id }) {
                                    Text(fee.employeeName ?? "Nhân viên cũ").tag(Optional(id))
                                }
                            }
                            .onChange(of: fee.employeeID) { id in
                                fee.employeeName = employees.first(where: { $0.0.id == id })?.1 ?? fee.employeeName
                            }
                            Text("Hoàn ứng được chủ shop xác nhận trong Chi phí → Hoàn ứng nhân viên sau khi lưu đơn.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(fee.bearer == "shop"
                             ? "Shop chịu: không cộng vào tiền khách trả; trừ vào lợi nhuận đơn hàng."
                             : fee.funding == "customer"
                             ? "Khách trả trực tiếp bên dịch vụ: không cộng vào số tiền shop thu."
                             : "Shop thu hộ: cộng vào tổng thanh toán, không tính vào doanh thu bán hàng.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
    }
    private func load() async {
                if StoreManager.shared.currentMember?.role == .owner { await advances.refresh() }
                names = Array(Set(names + draft.map(\.name))).sorted()
                employees = await StoreManager.shared.getEmployees().filter { $0.0.role != .owner && ($0.0.status == .active || ($0.0.status == nil && $0.0.userId != nil)) }
                do {
                    guard let id = StoreManager.shared.currentStore?.id else { return }
                    struct FeeType: Decodable { let name: String }
                    let types: [FeeType] = try await SupabaseConfig.client.database.from("order_fee_types")
                        .select("name").eq("store_id", value: id).execute().value
                    names = Array(Set(names + types.map(\.name))).sorted()
                } catch { self.error = "Không tải được danh mục phí. \(error.localizedDescription)" }
    }
    private func addType() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = StoreManager.shared.currentStore?.id, !name.isEmpty else { return }
        if names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { error = "Loại phí đã có trong danh sách."; return }
        busy = true
        defer { busy = false }
        do {
            struct FeeType: Encodable { let store_id: UUID; let name: String }
            try await SupabaseConfig.client.database.from("order_fee_types").insert(FeeType(store_id: id, name: name)).execute()
            names.append(name); draft.append(OrderFee(name: name)); newName = ""; error = nil
        } catch { self.error = "Không tạo được loại phí. \(error.localizedDescription)" }
    }
}

struct EmployeeReimbursementView: View {
    @ObservedObject var viewModel: OrderViewModel
    @ObservedObject private var store = EmployeeAdvanceStore.shared
    @State private var filter = 0
    @State private var selected: Set<UUID> = []
    @State private var busy = false
    @State private var error: String?
    @State private var openedBill: Bill?
    @State private var filterDate = false
    @State private var start = Calendar.current.startOfDay(for: Date())
    @State private var end = Date()
    private var visible: [EmployeeAdvance] {
        store.advances.filter { row in
            if filter == 0 { return row.settledAt == nil }
            if filter == 1 {
                guard let date = row.settledAt else { return false }
                return !filterDate || (date >= Calendar.current.startOfDay(for: start) && date < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))!)
            }
            return true
        }
    }
    var body: some View {
        List {
            Section {
                Text("Cần hoàn: \(formatCurrency(store.pendingTotal))").font(.headline)
                Text("Tổng chưa hoàn đến hiện tại · Không theo bộ lọc thời gian.").font(.caption).foregroundStyle(.secondary)
                Picker("Trạng thái", selection: $filter) {
                    Text("Chưa hoàn").tag(0); Text("Đã hoàn").tag(1); Text("Tất cả").tag(2)
                }.pickerStyle(.segmented).onChange(of: filter) { _ in selected = [] }
                if filter == 1 {
                    Toggle("Lọc theo ngày hoàn", isOn: $filterDate)
                    if filterDate {
                        DatePicker("Từ", selection: $start, displayedComponents: .date)
                        DatePicker("Đến", selection: $end, in: start..., displayedComponents: .date)
                    }
                }
            }
            if store.loading { ProgressView() }
            if let message = store.error { Text(message).foregroundStyle(.red); Button("Thử lại") { Task { await store.refresh() } } }
            if let error { Text(error).foregroundStyle(.red) }
            if visible.isEmpty && !store.loading && store.error == nil { Text("Không có khoản hoàn ứng.") }
            ForEach(Array(Set(visible.compactMap { $0.fee.employeeID })).sorted { $0.uuidString < $1.uuidString }, id: \.self) { employee in
                let rows = visible.filter { $0.fee.employeeID == employee }
                Section {
                    DisclosureGroup {
                    ForEach(rows) { row in
                        HStack(alignment: .top) {
                            if row.settledAt == nil {
                                Button {
                                    if selected.contains(row.id) { selected.remove(row.id) } else { selected.insert(row.id) }
                                } label: { Image(systemName: selected.contains(row.id) ? "checkmark.circle.fill" : "circle") }
                                .buttonStyle(.borderless)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Button("\(row.sequence) · \(row.fee.name)") { Task { await open(row.orderID) } }.buttonStyle(.borderless)
                                Text(row.deleted ? "Đơn đã huỷ/xoá — vẫn cần đối soát tiền ứng" : row.createdAt.formatted(date: .numeric, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                                if let date = row.settledAt, let batch = row.batchID {
                                    Text("Đã hoàn: \(date.formatted())").font(.caption).foregroundStyle(.green)
                                    Button("Hoàn tác lần hoàn này") { Task { await undo(batch) } }.font(.caption).buttonStyle(.borderless)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(row.fee.amount)).font(.subheadline)
                        }
                    }
                    let pending = rows.filter { $0.settledAt == nil }
                    if !pending.isEmpty {
                        Button("Chọn tất cả \(pending.count) khoản") { selected.formUnion(pending.map(\.id)) }
                        let chosen = pending.filter { selected.contains($0.id) }
                        Button("Đã hoàn \(formatCurrency(chosen.reduce(0) { $0 + $1.fee.amount })) — \(chosen.count) khoản") {
                            Task { await settle(chosen.map(\.id)) }
                        }.disabled(chosen.isEmpty || busy)
                    }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rows.first?.fee.employeeName ?? "Nhân viên").font(.headline)
                            Text("\(rows.filter { $0.settledAt == nil }.count) khoản chưa hoàn · \(formatCurrency(rows.filter { $0.settledAt == nil }.reduce(0) { $0 + $1.fee.amount }))")
                                .font(.subheadline)
                        }
                    }
                }
            }
            Section {
                Text("Chỉ xác nhận sau khi đã trả tiền cho nhân viên. Thao tác này ghi nhận hoàn ứng, không thực hiện chuyển khoản và không tính thêm chi phí.").font(.caption)
            }
        }
        .disabled(busy)
        .navigationTitle("Hoàn ứng nhân viên")
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
        .sheet(item: $openedBill) { bill in BillDetailView(bill: bill, viewModel: viewModel) }
    }
    private func settle(_ ids: [UUID]) async {
        busy = true; defer { busy = false }
        do { try await store.settle(ids); selected.subtract(ids); error = nil }
        catch { self.error = "Không lưu được hoàn ứng: \(error.localizedDescription)"; await store.refresh() }
    }
    private func undo(_ batch: UUID) async {
        busy = true; defer { busy = false }
        do { try await store.undo(batch); error = nil }
        catch { self.error = "Không hoàn tác được: \(error.localizedDescription)" }
    }
    private func open(_ id: UUID) async {
        do { openedBill = try await SupabaseDatabaseService().fetchOrder(id: id) }
        catch { self.error = "Không mở được đơn: \(error.localizedDescription)" }
    }
}

struct PendingEmployeeAdvanceCard: View {
    @ObservedObject var viewModel: OrderViewModel
    @ObservedObject private var store = EmployeeAdvanceStore.shared
    var body: some View {
        NavigationLink(destination: EmployeeReimbursementView(viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cần hoàn nhân viên").font(.subheadline)
                    Spacer()
                    Text(store.loading ? "Đang tải…" : store.error != nil ? "Thử lại" : formatCurrency(store.pendingTotal)).font(.headline)
                }
                Text("Tổng chưa hoàn đến hiện tại · Không theo bộ lọc thời gian").font(.caption).foregroundStyle(.secondary)
            }.padding().background(Color.white).cornerRadius(12)
        }.buttonStyle(.plain)
        .task(id: StoreManager.shared.currentStore?.id) { await store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OrderFeesChanged"))) { _ in
            Task { await store.refresh() }
        }
    }
}

struct CustomerOrderFeeRows: View {
    let fees: [OrderFee]
    var body: some View {
        ForEach(fees.filter { $0.bearer == "customer" }) { fee in
            HStack {
                Text("\(fee.name) — \(fee.funding == "customer" ? "Khách trả trực tiếp" : "Thu hộ")")
                Spacer()
                Text(formatCurrency(fee.amount))
            }.font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
