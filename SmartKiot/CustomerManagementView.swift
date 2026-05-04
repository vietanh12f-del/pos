import SwiftUI
import PhotosUI

// MARK: - Website Lead Model

struct WebsiteLead: Identifiable, Codable {
    var id: UUID = UUID()
    var leadType: String  // "consultation" | "appointment"
    var fullName: String
    var phone: String
    var serviceType: String?
    var note: String?
    var createdAt: Date
    var status: String  // "new" | "contacted" | "done" | "cancelled"
    // Appointment fields
    var bookingDate: String?
    var timeSlot: String?
    var email: String?
    var branch: String?
}

struct WebsiteLeadDTO: Codable {
    let id: UUID
    let lead_type: String
    let full_name: String
    let phone: String
    let service_type: String?
    let note: String?
    let created_at: Date
    let status: String
    let booking_date: String?
    let time_slot: String?
    let email: String?
    let branch: String?

    func toDomain() -> WebsiteLead {
        WebsiteLead(
            id: id, leadType: lead_type, fullName: full_name, phone: phone,
            serviceType: service_type, note: note, createdAt: created_at, status: status,
            bookingDate: booking_date, timeSlot: time_slot, email: email, branch: branch
        )
    }
}

// MARK: - Customer Management View

struct CustomerManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var parties: [TradingParty] = []
    @State private var leads: [WebsiteLead] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedType: PartyTypeFilter
    @State private var selectedParty: TradingParty? = nil
    @State private var selectedLead: WebsiteLead? = nil
    @State private var showAddParty = false

    init(initialTab: PartyTypeFilter = .buyer) {
        _selectedType = State(initialValue: initialTab)
    }

    // Trạng thái lọc leads từ website
    enum LeadStatusFilter: String, CaseIterable {
        case all       = "Tất cả"
        case new       = "Mới"
        case contacted = "Đã liên hệ"
        case done      = "Hoàn tất"
        case cancelled = "Đã huỷ"

        var statusValue: String? {
            switch self {
            case .all:       return nil
            case .new:       return "new"
            case .contacted: return "contacted"
            case .done:      return "done"
            case .cancelled: return "cancelled"
            }
        }

        var color: Color {
            switch self {
            case .all:       return .gray
            case .new:       return .teal
            case .contacted: return .blue
            case .done:      return .green
            case .cancelled: return .red
            }
        }
    }

    @State private var statusFilter: LeadStatusFilter = .all

    enum PartyTypeFilter: String, CaseIterable {
        case buyer = "Khách hàng"
        case supplier = "Cơ sở cung cấp"
        case all = "Từ Website"
        var dbType: String? {
            switch self {
            case .all: return nil
            case .buyer: return "buyer"
            case .supplier: return "supplier"
            }
        }
    }

    private var filteredParties: [TradingParty] {
        var list = parties
        if let type = selectedType.dbType {
            list = list.filter { $0.partyType == type }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.phone.lowercased().contains(q) ||
                $0.address.lowercased().contains(q)
            }
        }
        return list.sorted { $0.name < $1.name }
    }

    private var filteredLeads: [WebsiteLead] {
        var list = leads
        // Lọc theo trạng thái
        if let sv = statusFilter.statusValue {
            list = list.filter { $0.status == sv }
        }
        // Lọc theo search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.fullName.lowercased().contains(q) ||
                $0.phone.lowercased().contains(q) ||
                ($0.serviceType?.lowercased().contains(q) ?? false) ||
                ($0.email?.lowercased().contains(q) ?? false)
            }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalDebt: Double {
        filteredParties.reduce(0) { $0 + $1.totalDebt }
    }

    private var newLeadsCount: Int {
        filteredLeads.filter { $0.status == "new" }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                Picker("Loại", selection: $selectedType) {
                    ForEach(PartyTypeFilter.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.themeBackgroundLight)

                if selectedType == .all {
                    // Website leads
                    websiteLeadsContent
                } else {
                    // Buyers / Suppliers
                    if totalDebt > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                            Text("Tổng công nợ: \(formatCurrency(totalDebt))")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
                            Spacer()
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                        .background(Color.orange.opacity(0.06))
                    }
                    partiesContent
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Quản lý khách hàng")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Tìm tên, SĐT...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task { await loadAll() }
            .sheet(item: $selectedParty) { party in
                PartyDetailView(party: party)
            }
            .sheet(item: $selectedLead) { lead in
                WebsiteLeadDetailView(lead: lead) {
                    Task { await loadAll() }
                }
            }
            .sheet(isPresented: $showAddParty) {
                PartyEditSheet(
                    party: TradingParty(
                        partyType: selectedType == .supplier ? "supplier" : "buyer",
                        name: "", phone: "", address: ""
                    ),
                    onSaved: { _ in Task { await loadAll() } }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if selectedType != .all {
                    HStack {
                        Button {
                            showAddParty = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text(selectedType == .supplier ? "Thêm cơ sở" : "Thêm khách hàng")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.themePrimary))
                            .shadow(color: Color.themePrimary.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .background(Color.clear)
                }
            }
        }
    }

    // MARK: - Parties content

    private var partiesContent: some View {
        Group {
            if isLoading {
                VStack { ProgressView(); Spacer() }.padding()
            } else if filteredParties.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.4))
                    Text("Chưa có dữ liệu").foregroundStyle(.gray)
                    Spacer()
                }.padding(.top, 60)
            } else {
                List {
                    ForEach(filteredParties) { party in
                        Button { selectedParty = party } label: { PartyRowView(party: party) }
                            .listRowBackground(Color.white)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Website leads content

    private var websiteLeadsContent: some View {
        Group {
            if isLoading {
                VStack { ProgressView(); Spacer() }.padding()
            } else if leads.isEmpty {
                // Chưa có leads nào trong DB
                VStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.4))
                    Text("Chưa có khách từ website").foregroundStyle(.gray)
                    Spacer()
                }.padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    // Status filter chips — luôn hiển thị kèm số lượng mỗi trạng thái
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LeadStatusFilter.allCases, id: \.self) { f in
                                let count = f.statusValue == nil
                                    ? leads.count
                                    : leads.filter { $0.status == f.statusValue }.count
                                Button {
                                    statusFilter = f
                                } label: {
                                    HStack(spacing: 4) {
                                        if f != .all {
                                            Circle()
                                                .fill(statusFilter == f ? .white : f.color)
                                                .frame(width: 6, height: 6)
                                        }
                                        Text(f.rawValue)
                                            .font(.caption)
                                            .fontWeight(statusFilter == f ? .semibold : .regular)
                                        Text("(\(count))")
                                            .font(.caption2)
                                            .fontWeight(statusFilter == f ? .semibold : .regular)
                                            .opacity(0.8)
                                    }
                                    .foregroundStyle(statusFilter == f ? .white : f.color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule().fill(statusFilter == f ? f.color : f.color.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // Danh sách hoặc empty state cho filter hiện tại
                    if filteredLeads.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundStyle(.gray.opacity(0.35))
                            Text("Không có liên hệ nào ở trạng thái \"\(statusFilter.rawValue)\"")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredLeads) { lead in
                                Button { selectedLead = lead } label: {
                                    LeadRowView(lead: lead, onStatusChanged: { Task { await loadAll() } })
                                }
                                .listRowBackground(Color.white)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .background(Color.themeBackgroundLight)
            }
        }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let buyers = (try? SupabaseDatabaseService().fetchTradingParties(type: "buyer")) ?? []
        async let suppliers = (try? SupabaseDatabaseService().fetchTradingParties(type: "supplier")) ?? []
        async let fetchedLeads = (try? SupabaseDatabaseService().fetchWebsiteLeads()) ?? []
        let (b, s, l) = await (buyers, suppliers, fetchedLeads)
        parties = b + s
        leads = l
    }
}

// MARK: - Party Row

private struct PartyRowView: View {
    let party: TradingParty

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(party.partyType == "buyer" ? Color.teal.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: party.partyType == "buyer" ? "person.fill" : "building.2.fill")
                    .foregroundStyle(party.partyType == "buyer" ? .teal : .green)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(party.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    Text(party.partyType == "buyer" ? "KH" : "NCC")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(party.partyType == "buyer" ? .teal : .green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(party.partyType == "buyer" ? Color.teal.opacity(0.1) : Color.green.opacity(0.1)))
                }
                if !party.phone.isEmpty {
                    Text(party.phone)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            if party.totalDebt > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Nợ")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(formatCurrency(party.totalDebt))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Party Detail View

struct PartyDetailView: View {
    let party: TradingParty
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [ProductionTransaction] = []
    @State private var retailOrders: [Bill] = []
    @State private var isLoading = false
    @State private var showEdit = false
    @State private var currentParty: TradingParty

    init(party: TradingParty) {
        self.party = party
        _currentParty = State(initialValue: party)
    }

    private var isSupplier: Bool { currentParty.partyType == "supplier" }

    // Group transactions by day
    private var groupedByDay: [(date: Date, txs: [ProductionTransaction])] {
        let cal = Calendar.current
        var map: [Date: [ProductionTransaction]] = [:]
        for tx in transactions {
            let day = cal.startOfDay(for: tx.createdAt)
            map[day, default: []].append(tx)
        }
        return map.map { (date: $0.key, txs: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    infoCard

                    // Debt summary
                    if currentParty.totalDebt > 0 {
                        debtCard
                    }

                    // Transactions
                    if isLoading {
                        ProgressView().padding()
                    } else {
                        // Đơn bán lẻ
                        if !retailOrders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Đơn bán lẻ")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(retailOrders.prefix(30)) { bill in
                                    retailBillCard(bill)
                                }
                            }
                        }

                        // Giao dịch sản xuất
                        if groupedByDay.isEmpty && retailOrders.isEmpty {
                            Text("Không có giao dịch trong 30 ngày gần nhất")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .padding()
                        } else if !groupedByDay.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Giao dịch sản xuất")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(groupedByDay, id: \.date) { group in
                                    daySection(group.date, txs: group.txs)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle(currentParty.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .task { await loadTransactions() }
            .sheet(isPresented: $showEdit) {
                PartyEditSheet(party: currentParty, onSaved: { updated in
                    currentParty = updated
                }, onDeleted: {
                    dismiss()
                })
            }
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSupplier ? Color.green.opacity(0.12) : Color.teal.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: isSupplier ? "building.2.fill" : "person.fill")
                        .font(.title2)
                        .foregroundStyle(isSupplier ? .green : .teal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentParty.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(isSupplier ? "Cơ sở cung cấp" : "Khách hàng")
                        .font(.caption)
                        .foregroundStyle(isSupplier ? .green : .teal)
                }
                Spacer()
            }
            Divider()
            if !currentParty.phone.isEmpty {
                Label(currentParty.phone, systemImage: "phone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if !currentParty.address.isEmpty {
                Label(currentParty.address, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            // Ảnh khách hàng
            if !currentParty.imageURLs.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentParty.imageURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    Color.gray.opacity(0.12)
                                        .overlay(ProgressView().scaleEffect(0.7))
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Debt card

    private var debtCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Công nợ hiện tại")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(formatCurrency(currentParty.totalDebt))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Day section

    private func daySection(_ date: Date, txs: [ProductionTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDateOnly(date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)
                .padding(.horizontal)

            ForEach(txs) { tx in
                txCard(tx)
            }
        }
    }

    // MARK: - Transaction card

    private func txCard(_ tx: ProductionTransaction) -> some View {
        let debtStatus = debtHighlight(tx)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: modeIcon(tx.mode))
                    .foregroundStyle(modeColor(tx.mode))
                Text(tx.mode)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatTime(tx.createdAt))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            // Items summary
            ForEach(tx.items.prefix(3)) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(isSupplier ? FormatUtils.formatWeight(item.quantity) : "\(item.quantity) kg")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            if tx.items.count > 3 {
                Text("+ \(tx.items.count - 3) mặt hàng khác")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Divider()

            // Financial
            HStack {
                Text("Tổng cộng")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Text(formatCurrency(tx.grandTotal ?? tx.totalCost))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(modeColor(tx.mode))
            }

            // Debt info
            if let debt = tx.debtAmount, debt > 0 {
                HStack(spacing: 6) {
                    Image(systemName: debtStatus == .overdue ? "xmark.circle.fill" : debtStatus == .warning ? "exclamationmark.circle.fill" : "clock.fill")
                        .font(.caption)
                        .foregroundStyle(debtStatus.color)
                    Text("Còn nợ: \(formatCurrency(debt))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(debtStatus.color)
                    Spacer()
                    if let payDate = tx.expectedPayDate {
                        Text("Trả: \(formatDateOnly(payDate))")
                            .font(.caption)
                            .foregroundStyle(debtStatus.color)
                    } else {
                        Text("Chưa xác định")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(8)
                .background(debtStatus.color.opacity(0.08))
                .cornerRadius(8)
            } else if tx.debtAmount == 0 || tx.isPaid {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                    Text("Đã thanh toán").font(.caption).foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    // MARK: - Retail bill card

    private func retailBillCard(_ bill: Bill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.themePrimary)
                Text("Đơn bán lẻ")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let stt = bill.sequenceNumber {
                    Text("• \(stt)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text(formatTime(bill.createdAt))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Text(formatDateOnly(bill.createdAt))
                .font(.caption)
                .foregroundStyle(.gray)

            ForEach(bill.items.prefix(3)) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            if bill.items.count > 3 {
                Text("+ \(bill.items.count - 3) mặt hàng khác")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Divider()

            HStack {
                Text("Tổng cộng")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Text(formatCurrency(bill.total))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
                if bill.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    enum DebtStatus {
        case normal, warning, overdue
        var color: Color {
            switch self {
            case .normal: return .orange
            case .warning: return .yellow
            case .overdue: return .red
            }
        }
    }

    private func debtHighlight(_ tx: ProductionTransaction) -> DebtStatus {
        guard let debt = tx.debtAmount, debt > 0, let payDate = tx.expectedPayDate else {
            return .normal
        }
        let now = Date()
        let daysLeft = Calendar.current.dateComponents([.day], from: now, to: payDate).day ?? 0
        if daysLeft < 0 { return .overdue }
        if daysLeft <= 3 { return .warning }
        return .normal
    }

    // MARK: - Helpers

    private func modeIcon(_ mode: String) -> String {
        let m = mode.lowercased()
        if m.contains("nhập") { return "arrow.down.circle.fill" }
        return "arrow.up.circle.fill"
    }

    private func modeColor(_ mode: String) -> Color {
        let m = mode.lowercased()
        if m.contains("nguyên liệu") && m.contains("nhập") { return .green }
        if m.contains("nguyên liệu") && m.contains("xuất") { return .orange }
        if m.contains("thành phẩm") && m.contains("nhập") { return .blue }
        return .purple
    }

    private func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let db = SupabaseDatabaseService()

        // Fetch đơn bán lẻ theo tên khách
        async let retailTask = db.fetchOrdersByCustomerName(currentParty.name)

        // Fetch production transactions
        let modes = ["Nhập Nguyên liệu", "Xuất Nguyên liệu", "Nhập Thành Phẩm", "Xuất Thành Phẩm"]
        var all: [ProductionTransaction] = []
        for mode in modes {
            let txs = (try? await db.fetchProductionTransactions(mode: mode)) ?? []
            all += txs
        }

        // Filter production by party name + phone + date
        let name = currentParty.name.lowercased()
        let phone = currentParty.phone
        transactions = all.filter { tx in
            guard tx.createdAt >= since else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }

        // Retail orders — filter by date
        let fetched = (try? await retailTask) ?? []
        retailOrders = fetched.filter { $0.createdAt >= since }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Party Edit Sheet

struct PartyEditSheet: View {
    let party: TradingParty
    let onSaved: (TradingParty) -> Void
    var onDeleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var phone: String
    @State private var address: String
    @State private var imageURLs: [String]
    @State private var pendingImages: [UIImage] = []
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var uploadProgress: Int = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirm = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var previewImage: String? = nil
    @State private var showPreview = false

    private var isOwner: Bool {
        StoreManager.shared.currentMember?.role == .owner
    }

    init(party: TradingParty, onSaved: @escaping (TradingParty) -> Void, onDeleted: (() -> Void)? = nil) {
        self.party = party
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _name      = State(initialValue: party.name)
        _phone     = State(initialValue: party.phone)
        _address   = State(initialValue: party.address)
        _imageURLs = State(initialValue: party.imageURLs)
    }

    private var isNew: Bool { party.name.isEmpty }
    private var isSupplier: Bool { party.partyType == "supplier" }
    private var hasChanges: Bool {
        if isNew {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines) != party.name ||
        phone.trimmingCharacters(in: .whitespacesAndNewlines) != party.phone ||
        address.trimmingCharacters(in: .whitespacesAndNewlines) != party.address ||
        imageURLs != party.imageURLs ||
        !pendingImages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Thông tin ──────────────────────────────────────
                Section(header: Text(isSupplier ? "Thông tin cơ sở" : "Thông tin khách hàng")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(isSupplier ? .green : .teal)
                            .frame(width: 22)
                        TextField("Tên", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 22)
                        TextField("Số điện thoại", text: $phone)
                            .keyboardType(.phonePad)
                    }
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 22)
                        TextField("Địa chỉ", text: $address)
                    }
                }

                // ── Hình ảnh ───────────────────────────────────────
                Section(header: Text("Hình ảnh")) {
                    // Grid ảnh đã lưu + ảnh mới chọn
                    let totalCount = imageURLs.count + pendingImages.count
                    if totalCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Existing URLs
                                ForEach(imageURLs, id: \.self) { url in
                                    ZStack(alignment: .topTrailing) {
                                        AsyncImage(url: URL(string: url)) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().scaledToFill()
                                            } else {
                                                Color.gray.opacity(0.15)
                                                    .overlay(ProgressView())
                                            }
                                        }
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            previewImage = url
                                            showPreview = true
                                        }

                                        Button {
                                            imageURLs.removeAll { $0 == url }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(Color.red))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 6, y: -6)
                                    }
                                }
                                // Pending (not yet uploaded)
                                ForEach(pendingImages.indices, id: \.self) { i in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: pendingImages[i])
                                            .resizable().scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                                            )
                                        Button {
                                            pendingImages.remove(at: i)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(Color.red))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    // Nút thêm ảnh
                    HStack(spacing: 12) {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                                .font(.subheadline)
                        }

                        Divider().frame(height: 20)

                        Button {
                            showCamera = true
                        } label: {
                            Label("Chụp ảnh", systemImage: "camera.fill")
                                .font(.subheadline)
                        }
                    }

                    if !pendingImages.isEmpty {
                        Text("\(pendingImages.count) ảnh mới chưa lưu")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle(isNew ? (isSupplier ? "Thêm cơ sở" : "Thêm khách hàng") : "Chỉnh sửa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                // Nút xóa — chỉ hiện khi chỉnh sửa (không phải tạo mới) và là chủ cửa hàng
                if !isNew && isOwner {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Xóa khách hàng")
                                }
                            }
                            .foregroundStyle(.red)
                        }
                        .disabled(isDeleting || isSaving)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            HStack(spacing: 6) {
                                ProgressView()
                                if uploadProgress > 0 {
                                    Text("\(uploadProgress)/\(pendingImages.count)")
                                        .font(.caption)
                                }
                            }
                        } else {
                            Text("Lưu").fontWeight(.bold)
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasChanges)
                }
            }
            .alert("Lỗi", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Xóa khách hàng?", isPresented: $showDeleteConfirm) {
                Button("Huỷ", role: .cancel) { }
                Button("Xóa", role: .destructive) {
                    Task { await deleteParty() }
                }
            } message: {
                Text("Thao tác này không thể hoàn tác. Toàn bộ thông tin của \"\(party.name)\" sẽ bị xóa vĩnh viễn.")
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                MultiImagePicker { images in
                    pendingImages.append(contentsOf: images)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { img in if let img { pendingImages.append(img) } }
                ), sourceType: .camera)
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPreview) {
                if let url = previewImage, let imageURL = URL(string: url) {
                    NavigationStack {
                        AsyncImage(url: imageURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFit()
                            } else {
                                ProgressView()
                            }
                        }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Đóng") { showPreview = false }
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // Upload pending images
        var newURLs: [String] = []
        uploadProgress = 0
        for img in pendingImages {
            guard let data = img.jpegData(compressionQuality: 0.82) else { continue }
            let fileName = UUID().uuidString
            if let url = try? await StorageManager.shared.uploadPartyImage(
                data: data, partyId: party.id, fileName: fileName
            ) {
                newURLs.append(url)
            }
            uploadProgress += 1
        }

        var updated = party
        updated.name      = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.phone     = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.address   = address.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.imageURLs = imageURLs + newURLs
        updated.updatedAt = Date()

        do {
            try await SupabaseDatabaseService().upsertTradingParty(updated)
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteParty() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await SupabaseDatabaseService().deleteTradingParty(id: party.id)
            onDeleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Lead Row View

private struct LeadRowView: View {
    let lead: WebsiteLead
    let onStatusChanged: () -> Void

    @State private var showStatusPicker = false
    @State private var isSaving = false

    private var isPartner: Bool { lead.leadType == "partner" }

    private let statuses: [(value: String, label: String, color: Color)] = [
        ("new",       "Mới",        .teal),
        ("contacted", "Đã liên hệ", .blue),
        ("done",      "Hoàn tất",   .green),
        ("cancelled", "Đã huỷ",     .red),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(lead.fullName)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                Text(lead.phone).font(.caption).foregroundStyle(.gray)
                if isPartner, let email = lead.email, !email.isEmpty {
                    Text(email).font(.caption).foregroundStyle(.blue)
                } else if let svc = lead.serviceType, !svc.isEmpty {
                    Text(svc).font(.caption).foregroundStyle(Color.themePrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                // Status button - tap to change inline
                Button {
                    showStatusPicker = true
                } label: {
                    HStack(spacing: 4) {
                        if isSaving {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Circle().fill(statusColor(lead.status)).frame(width: 6, height: 6)
                        }
                        Text(statusLabel(lead.status))
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(statusColor(lead.status))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(statusColor(lead.status).opacity(0.7))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(statusColor(lead.status).opacity(0.1)))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                Text(typeLabel).font(.caption2).foregroundStyle(iconColor)
                if lead.leadType == "appointment", let slot = lead.timeSlot, !slot.isEmpty {
                    let dateStr = lead.bookingDate.map { " · \($0)" } ?? ""
                    Text("\(slot)\(dateStr)").font(.caption2).foregroundStyle(.blue)
                }
                Text(formatDateOnly(lead.createdAt)).font(.caption2).foregroundStyle(.gray)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Đổi trạng thái", isPresented: $showStatusPicker, titleVisibility: .visible) {
            ForEach(statuses, id: \.value) { s in
                Button(s.label) {
                    Task { await changeStatus(to: s.value) }
                }
            }
            Button("Huỷ", role: .cancel) { }
        }
    }

    private func changeStatus(to newStatus: String) async {
        guard newStatus != lead.status else { return }
        isSaving = true
        do {
            try await SupabaseDatabaseService().updateWebsiteLeadStatus(
                id: lead.id, status: newStatus, note: lead.note
            )
            onStatusChanged()
        } catch {
            print("❌ changeStatus error: \(error)")
        }
        isSaving = false
    }

    private var iconName: String {
        switch lead.leadType {
        case "partner": return "building.2.fill"
        case "appointment": return "calendar.badge.plus"
        default: return "bubble.left.fill"
        }
    }

    private var iconColor: Color {
        switch lead.leadType {
        case "partner": return .orange
        case "appointment": return .blue
        default: return .teal
        }
    }

    private var typeLabel: String {
        switch lead.leadType {
        case "partner": return "Đối tác"
        case "appointment": return "Đặt lịch"
        default: return "Tư vấn"
        }
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM"
        return f.string(from: date)
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "new":       return .teal
        case "contacted": return .blue
        case "done":      return .green
        case "cancelled": return .red
        default:          return .gray
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "new":       return "Mới"
        case "contacted": return "Đã liên hệ"
        case "done":      return "Hoàn tất"
        case "cancelled": return "Đã huỷ"
        default:          return s
        }
    }
}

// MARK: - Multi Image Picker (PHPickerViewController)

struct MultiImagePicker: UIViewControllerRepresentable {
    let onPicked: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([UIImage]) -> Void
        init(onPicked: @escaping ([UIImage]) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            var images: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage { images.append(img) }
                    group.leave()
                }
            }
            group.notify(queue: .main) { self.onPicked(images) }
        }
    }
}

// MARK: - Website Lead Detail View

struct WebsiteLeadDetailView: View {
    let lead: WebsiteLead
    let onSaved: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var currentStatus: String
    @State private var internalNote: String
    @State private var isSaving = false
    @State private var showSavedToast = false

    init(lead: WebsiteLead, onSaved: (() -> Void)? = nil) {
        self.lead = lead
        self.onSaved = onSaved
        _currentStatus = State(initialValue: lead.status)
        _internalNote = State(initialValue: lead.note ?? "")
    }

    private let statuses: [(value: String, label: String, icon: String, color: Color)] = [
        ("new",       "Mới",          "bell.fill",           .teal),
        ("contacted", "Đã liên hệ",   "phone.fill",          .blue),
        ("done",      "Hoàn tất",     "checkmark.circle.fill",.green),
        ("cancelled", "Đã huỷ",       "xmark.circle.fill",   .red),
    ]

    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section(header: Text("Thông tin liên hệ")) {
                    infoRow(label: "Họ tên", value: lead.fullName, icon: "person.fill")
                    infoRow(label: "Số điện thoại", value: lead.phone, icon: "phone.fill")
                    if let email = lead.email, !email.isEmpty {
                        infoRow(label: "Email", value: email, icon: "envelope.fill")
                    }
                    if let svc = lead.serviceType, !svc.isEmpty {
                        infoRow(label: "Dịch vụ", value: svc, icon: "sparkles")
                    }
                }

                // Appointment details
                if lead.leadType == "appointment" {
                    Section(header: Text("Thông tin đặt lịch")) {
                        if let date = lead.bookingDate, !date.isEmpty {
                            infoRow(label: "Ngày hẹn", value: date, icon: "calendar")
                        }
                        if let slot = lead.timeSlot, !slot.isEmpty {
                            infoRow(label: "Giờ hẹn", value: slot, icon: "clock.fill")
                        }
                        if let branch = lead.branch, !branch.isEmpty {
                            infoRow(label: "Chi nhánh", value: branch, icon: "mappin.circle.fill")
                        }
                    }
                }

                // Status section
                Section(header: Text("Trạng thái")) {
                    ForEach(statuses, id: \.value) { s in
                        Button {
                            currentStatus = s.value
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: s.icon)
                                    .foregroundStyle(s.color)
                                    .frame(width: 22)
                                Text(s.label)
                                    .foregroundStyle(Color.themeTextDark)
                                Spacer()
                                if currentStatus == s.value {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(s.color)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .listRowBackground(currentStatus == s.value ? s.color.opacity(0.06) : Color.white)
                    }
                }

                // Note section
                Section(header: Text("Ghi chú nội bộ")) {
                    ZStack(alignment: .topLeading) {
                        if internalNote.isEmpty {
                            Text("Thêm ghi chú...")
                                .foregroundStyle(.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $internalNote)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                    }
                }

                // Metadata
                Section {
                    HStack {
                        Text("Loại").foregroundStyle(.gray)
                        Spacer()
                        Text(typeLabel(lead.leadType))
                    }
                    HStack {
                        Text("Thời gian").foregroundStyle(.gray)
                        Spacer()
                        Text(formatDateTime(lead.createdAt)).font(.caption)
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lưu").fontWeight(.bold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("✅ Đã lưu")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Capsule().fill(Color.green))
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSavedToast)
        }
    }

    private var navTitle: String {
        switch lead.leadType {
        case "appointment": return "Đặt lịch hẹn"
        case "partner":     return "Đăng ký đối tác"
        default:            return "Tư vấn dịch vụ"
        }
    }

    private func typeLabel(_ t: String) -> String {
        switch t {
        case "appointment": return "Đặt lịch"
        case "partner":     return "Đối tác"
        default:            return "Tư vấn"
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseDatabaseService().updateWebsiteLeadStatus(
                id: lead.id,
                status: currentStatus,
                note: internalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : internalNote
            )
            dismiss()
            onSaved?()
        } catch {
            print("❌ updateWebsiteLeadStatus error: \(error)")
        }
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.themePrimary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.gray)
                Text(value).font(.subheadline)
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm dd/MM/yyyy"
        return f.string(from: date)
    }
}
