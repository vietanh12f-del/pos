import SwiftUI
import PhotosUI

// MARK: - Website Lead Model

struct WebsiteLead: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var storeId: UUID?
    var leadType: String  // "consultation" | "appointment" | "feedback"
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
    var source: String?

    var leadTypeLabel: String {
        switch leadType {
        case "appointment": return "Đặt lịch"
        case "feedback":    return "Góp ý"
        default:            return "Tư vấn"
        }
    }

    var statusLabel: String {
        switch status {
        case "contacted": return "Đã liên hệ"
        case "done":      return "Hoàn thành"
        case "cancelled": return "Đã huỷ"
        default:          return "Mới"
        }
    }
}

struct WebsiteLeadDTO: Codable {
    let id: UUID
    let store_id: UUID?
    let lead_type: String
    let full_name: String
    let phone: String
    let service_type: String?
    let note: String?
    let created_at: Date
    let status: String?
    let booking_date: String?
    let time_slot: String?
    let email: String?
    let branch: String?
    let source: String?

    func toDomain() -> WebsiteLead {
        WebsiteLead(
            id: id, storeId: store_id, leadType: lead_type, fullName: full_name, phone: phone,
            serviceType: service_type, note: note, createdAt: created_at, status: status ?? "new",
            bookingDate: booking_date, timeSlot: time_slot, email: email, branch: branch, source: source
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
    @State private var allProductionTransactions: [ProductionTransaction] = []

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
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.name.smartContains(q) ||
                $0.phone.smartContains(q) ||
                $0.address.smartContains(q)
            }
        }
        // "Vừa update" = trong vòng 24 giờ
        let recentThreshold = Date().addingTimeInterval(-86400)
        return list.sorted { (a, b) in
            let aHasDebt = a.totalDebt > 0
            let bHasDebt = b.totalDebt > 0
            let aRecent = a.updatedAt > recentThreshold
            let bRecent = b.updatedAt > recentThreshold

            // Ưu tiên 1: có nợ + vừa update
            let aTopPriority = aHasDebt && aRecent
            let bTopPriority = bHasDebt && bRecent
            if aTopPriority != bTopPriority { return aTopPriority }

            // Ưu tiên 2: có nợ (dù không vừa update)
            if aHasDebt != bHasDebt { return aHasDebt }

            // Ưu tiên 3: vừa update (không nợ)
            if aRecent != bRecent { return aRecent }

            // Trong cùng nhóm: sort theo updatedAt mới nhất
            return a.updatedAt > b.updatedAt
        }
    }

    private var filteredLeads: [WebsiteLead] {
        var list = leads
        // Lọc theo trạng thái
        if let sv = statusFilter.statusValue {
            list = list.filter { $0.status == sv }
        }
        // Lọc theo search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.fullName.smartContains(q) ||
                $0.phone.smartContains(q) ||
                ($0.serviceType?.smartContains(q) ?? false) ||
                ($0.email?.smartContains(q) ?? false)
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
                        let debtLabel = selectedType == .supplier ? "Tổng thiếu nợ" : "Tổng công nợ"
                        let formattedDebt = formatCurrency(totalDebt)
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                            Text("\(debtLabel): \(formattedDebt)")
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
                PartyDetailView(party: party, onDeleted: {
                    Task { await loadAll() }
                }, onDebtSaved: {
                    Task { await loadAll() }
                })
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

    private func calculateTotalDebt(for party: TradingParty, allProductionTxs: [ProductionTransaction], retailOrders: [Bill] = []) -> Double {
        let name = party.name.lowercased()
        let phone = party.phone
        let txDebt = allProductionTxs.filter { tx in
            guard !tx.isDeleted else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }.reduce(0) { $0 + $1.effectiveDebt }
        
        let retailDebt = retailOrders.filter { bill in
            guard !bill.isDeleted else { return false }
            let matchName = (bill.customerName ?? "").lowercased() == name
            let matchPhone = phone.isEmpty ? false : bill.customerPhone == phone
            return matchName || matchPhone
        }.reduce(0) { $0 + $1.effectiveDebt }
        
        return txDebt + retailDebt
    }
    
    private func getLastTransactionDate(for party: TradingParty) -> Date? {
        let name = party.name.lowercased()
        let phone = party.phone
        return allProductionTransactions.filter { tx in
            guard !tx.isDeleted else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }.max { $0.createdAt < $1.createdAt }?.createdAt
    }

    private func loadAll() async {
        isLoading = true

        let db = SupabaseDatabaseService()

        async let buyers = (try? db.fetchTradingParties(type: "buyer")) ?? []
        async let suppliers = (try? db.fetchTradingParties(type: "supplier")) ?? []
        async let fetchedLeads = (try? db.fetchWebsiteLeads()) ?? []
        async let productionTransactions = (try? db.fetchProductionTransactions(mode: nil)) ?? []
        async let allRetailOrders = (try? db.fetchOrders()) ?? []

        let (b, s, l) = await (buyers, suppliers, fetchedLeads)
        parties = deduplicatedParties(b + s)
        leads = l
        isLoading = false

        let (allProductionTxs, retailOrders) = await (productionTransactions, allRetailOrders)
        allProductionTransactions = allProductionTxs

        var updatedParties: [TradingParty] = []
        for party in b + s {
            var updated = party
            let newTotalDebt = calculateTotalDebt(for: party, allProductionTxs: allProductionTxs, retailOrders: retailOrders)
            updated.totalDebt = newTotalDebt
            
            // Only upsert if totalDebt has changed
            if party.totalDebt != newTotalDebt {
                do {
                    try await db.upsertTradingParty(updated)
                } catch {
                    print("❌ Failed to update totalDebt for \(party.name): \(error)")
                }
            }
            
            updatedParties.append(updated)
        }

        parties = deduplicatedParties(updatedParties)
    }

    private func deduplicatedParties(_ source: [TradingParty]) -> [TradingParty] {
        var uniquePartiesDict: [String: TradingParty] = [:]
        for party in source {
            let key = "\(party.name.lowercased())|\(party.phone.lowercased())"
            if let existing = uniquePartiesDict[key] {
                if party.updatedAt > existing.updatedAt {
                    uniquePartiesDict[key] = party
                }
            } else {
                uniquePartiesDict[key] = party
            }
        }

        return Array(uniquePartiesDict.values)
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
    var onDeleted: (() -> Void)? = nil
    var onDebtSaved: (() async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [ProductionTransaction] = []
    @State private var allPartyTxs: [ProductionTransaction] = [] // All transactions for the party (all time)
    @State private var allRetailOrders: [Bill] = [] // All retail orders for the party (all time)
    @State private var retailOrders: [Bill] = [] // Last 30 days retail orders (for list UI)
    @State private var showAllRetailHistory = false
    @State private var selectedRetailMonth: Int? = Calendar.current.component(.month, from: Date())
    @State private var selectedRetailYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isLoading = false
    @State private var showEdit = false
    @State private var currentParty: TradingParty
    @State private var showBillDetail: Bool = false
    @State private var selectedBillForDetail: Bill?
    @StateObject private var orderViewModel = OrderViewModel()
    @State private var showProductionDetail: Bool = false
    @State private var selectedProductionTx: ProductionTransaction?
    @State private var showFeatureInDevelopment = false
    @State private var showDebtEdit = false
    @State private var editedTransactions: [UUID: (debtAmount: Double, expectedPayDate: Date?)] = [:]
    @State private var editedRetailOrderDebts: [UUID: Double] = [:] // billId -> newDebtAmount
    @State private var showEditHistoryPopover = false
    @State private var selectedEditHistoryTxId: UUID?
    @State private var editHistoryEntries: [ProductionEdit] = []
    @State private var showDebtHistory = false

    init(party: TradingParty, onDeleted: (() -> Void)? = nil, onDebtSaved: (() async -> Void)? = nil) {
        self.party = party
        self.onDeleted = onDeleted
        self.onDebtSaved = onDebtSaved
        _currentParty = State(initialValue: party)
    }

    private var isSupplier: Bool { currentParty.partyType == "supplier" }

    private var retailYears: [Int] {
        let years = Set(allRetailOrders.map { Calendar.current.component(.year, from: $0.createdAt) })
        let currentYear = Calendar.current.component(.year, from: Date())
        let selectableYears = Set((currentYear - 5)...(currentYear + 1))
        return Array(years.union(selectableYears)).sorted(by: >)
    }

    private var filteredRetailOrders: [Bill] {
        guard !showAllRetailHistory else {
            return allRetailOrders.sorted { $0.createdAt > $1.createdAt }
        }
        let calendar = Calendar.current
        return allRetailOrders
            .filter { bill in
                guard calendar.component(.year, from: bill.createdAt) == selectedRetailYear else { return false }
                if let month = selectedRetailMonth {
                    return calendar.component(.month, from: bill.createdAt) == month
                }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredRetailTotal: Double {
        filteredRetailOrders.reduce(0) { $0 + $1.total }
    }

    private var filteredRetailPaid: Double {
        filteredRetailOrders.reduce(0) { sum, bill in
            if bill.paymentStatus == .paidFull { return sum + bill.total }
            return sum + (bill.paidAmount ?? 0)
        }
    }

    private var filteredRetailDebt: Double {
        filteredRetailOrders.reduce(0) { $0 + $1.effectiveDebt }
    }
    
    private enum DebtStatus {
        case onTime
        case extended
        case overdue(days: Int)
        case paid
        case noDueDate
        
        var label: String {
            switch self {
            case .onTime: return "Trả đúng hạn"
            case .extended: return "Gia hạn"
            case .overdue(let days): return "Trả trễ \(days) ngày"
            case .paid: return "Đã trả"
            case .noDueDate: return "Chưa xác định hạn trả"
            }
        }
        
        var color: Color {
            switch self {
            case .onTime: return .green
            case .extended: return .orange
            case .overdue: return .red
            case .paid: return .green
            case .noDueDate: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .onTime: return "checkmark.circle.fill"
            case .extended: return "clock.arrow.2.circlepath"
            case .overdue: return "exclamationmark.circle.fill"
            case .paid: return "checkmark.circle.fill"
            case .noDueDate: return "questionmark.circle.fill"
            }
        }
    }
    
    private func getDebtStatus(for tx: ProductionTransaction) -> DebtStatus {
        let hasDebt = tx.effectiveDebt > 0
        guard let dueDate = tx.expectedPayDate else {
            return hasDebt ? .noDueDate : .paid
        }
        
        if !hasDebt {
            let cal = Calendar.current
            let txDate = cal.startOfDay(for: tx.createdAt)
            let dueDateStart = cal.startOfDay(for: dueDate)
            return txDate <= dueDateStart ? .onTime : .overdue(days: cal.dateComponents([.day], from: dueDateStart, to: txDate).day ?? 0)
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let dueDateStart = Calendar.current.startOfDay(for: dueDate)
        
        if dueDateStart > today {
            return .extended
        }
        
        let daysOverdue = Calendar.current.dateComponents([.day], from: dueDateStart, to: today).day ?? 0
        return .overdue(days: daysOverdue)
    }

    // Group transactions by day
    private var groupedByDay: [(date: Date, txs: [ProductionTransaction])] {
        let cal = Calendar.current
        var map: [Date: [ProductionTransaction]] = [:]
        for tx in transactions {
            let day = cal.startOfDay(for: tx.createdAt)
            map[day, default: []].append(tx)
        }
        return map.map { (date: $0.key, txs: $0.value.sorted { (a, b) in
            if a.effectiveDebt > 0 && b.effectiveDebt <= 0 {
                return true
            }
            if a.effectiveDebt <= 0 && b.effectiveDebt > 0 {
                return false
            }
            if a.effectiveDebt > 0 && b.effectiveDebt > 0 {
                if a.effectiveDebt != b.effectiveDebt {
                    return a.effectiveDebt > b.effectiveDebt
                }
            }
            return a.createdAt > b.createdAt
        }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    infoCard

                    // Debt summary
                    debtCard

                    // Transactions
                    if isLoading {
                        ProgressView().padding()
                    } else {
                        // Đơn bán lẻ
                        if !allRetailOrders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                retailPurchaseSummaryCard

                                Text("Đơn bán lẻ")
                                    .font(.headline)
                                    .padding(.horizontal)

                                if filteredRetailOrders.isEmpty {
                                    Text("Không có đơn bán lẻ trong kỳ đã chọn")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }

                                ForEach(filteredRetailOrders) { bill in
                                    Button {
                                        selectedBillForDetail = bill
                                        showBillDetail = true
                                    } label: {
                                        retailBillCard(bill)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Giao dịch sản xuất
                        if groupedByDay.isEmpty && allRetailOrders.isEmpty {
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
            .task { 
                async let transactions: Void = loadTransactions()
                async let editedIds: Void = orderViewModel.loadEditedProductionTxIds()
                _ = await (transactions, editedIds)
            }
            .sheet(isPresented: $showEdit) {
                PartyEditSheet(party: currentParty, onSaved: { updated in
                    currentParty = updated
                }, onDeleted: {
                    onDeleted?()
                    dismiss()
                })
            }
            .sheet(isPresented: $showBillDetail, onDismiss: {
                // Reload sau khi đóng để cập nhật nếu có xoá/sửa
                Task { await loadTransactions() }
            }) {
                if let bill = selectedBillForDetail {
                    NavigationStack {
                        BillDetailView(bill: bill, viewModel: orderViewModel, onDeleted: {
                            // Xoá ngay lập tức khỏi list để UX tức thì, không cần chờ reload
                            retailOrders.removeAll { $0.id == bill.id }
                            allRetailOrders.removeAll { $0.id == bill.id }
                        }, showEditButton: false)
                    }
                }
            }
            .sheet(isPresented: $showProductionDetail) {
                if let tx = selectedProductionTx {
                    NavigationStack {
                        ProductionBillDetailView(tx: tx, viewModel: orderViewModel)
                    }
                }
            }
            .sheet(isPresented: $showDebtEdit) {
                DebtEditView(
                    transactions: allPartyTxs,
                    allRetailOrders: allRetailOrders,
                    isSupplier: isSupplier,
                    editedTxIds: orderViewModel.editedProductionTxIds,
                    fetchEdits: { txId in
                        await orderViewModel.fetchProductionEdits(for: txId)
                    },
                    editedTransactions: $editedTransactions,
                    editedRetailOrderDebts: $editedRetailOrderDebts,
                    onSave: {
                        await saveDebtEdits()
                    },
                    onCancel: {
                        showDebtEdit = false
                    }
                )
            }
            .sheet(isPresented: $showDebtHistory) {
                NavigationStack {
                    List {
                        ForEach(allPartyTxs.sorted(by: { $0.createdAt > $1.createdAt })) { tx in
                            let status = getDebtStatus(for: tx)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(tx.mode)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if let stt = tx.sequenceNumber {
                                        Text("• \(stt)")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    Text(formatDateOnly(tx.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                HStack {
                                    Image(systemName: status.icon)
                                        .foregroundStyle(status.color)
                                    Text(status.label)
                                        .font(.caption)
                                        .foregroundStyle(status.color)
                                    if orderViewModel.editedProductionTxIds.contains(tx.id) {
                                        Button {
                                            Task {
                                                let edits = await orderViewModel.fetchProductionEdits(for: tx.id)
                                                await MainActor.run {
                                                    selectedEditHistoryTxId = tx.id
                                                    editHistoryEntries = edits
                                                    showEditHistoryPopover = true
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }
                                HStack {
                                    Text("Công nợ:")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text(formatCurrency(tx.effectiveDebt))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                if let dueDate = tx.expectedPayDate {
                                    HStack {
                                        Text("Hạn trả:")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text(formatDateOnly(dueDate))
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle(isSupplier ? "Lịch sử thiếu nợ" : "Lịch sử công nợ")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") {
                                showDebtHistory = false
                            }
                        }
                    }
                    .sheet(isPresented: $showEditHistoryPopover) {
                        NavigationStack {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Lịch sử chỉnh sửa")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                if editHistoryEntries.isEmpty {
                                    Text("Không có lịch sử chỉnh sửa")
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                } else {
                                    List(editHistoryEntries) { edit in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(formatDateTime(edit.createdAt))
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                                Spacer()
                                                if let editorName = edit.editorName {
                                                    Text(editorName)
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                }
                                            }
                                            
                                            if let details = edit.details, !details.isEmpty {
                                                ForEach(details, id: \.self) { detail in
                                                    Text("• \(detail)")
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .listStyle(.plain)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .navigationTitle("Lịch sử chỉnh sửa")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Đóng") {
                                        showEditHistoryPopover = false
                                    }
                                }
                            }
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
            }
            .sheet(isPresented: $showEditHistoryPopover) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lịch sử chỉnh sửa")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if editHistoryEntries.isEmpty {
                            Text("Không có lịch sử chỉnh sửa")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        } else {
                            List(editHistoryEntries) { edit in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(formatDateTime(edit.createdAt))
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        if let editorName = edit.editorName {
                                            Text(editorName)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    
                                    if let details = edit.details, !details.isEmpty {
                                        ForEach(details, id: \.self) { detail in
                                            Text("• \(detail)")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .listStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Lịch sử chỉnh sửa")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") {
                                showEditHistoryPopover = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Tính năng đang phát triển", isPresented: $showFeatureInDevelopment) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Tính năng gửi email lấy ý kiến khách hàng sẽ được cập nhật trong phiên bản tới!")
            }
        }
    }
    
    private func saveDebtEdits() async {
        let viewModel = orderViewModel
        
        // Save production transaction debts
        for tx in allPartyTxs {
            guard let edits = editedTransactions[tx.id] else { continue }
            let debtChanged = tx.effectiveDebt != edits.debtAmount
            let payDateChanged = tx.expectedPayDate != edits.expectedPayDate
            guard debtChanged || payDateChanged else { continue }
            var updatedTx = tx
            updatedTx.debtAmount = edits.debtAmount
            updatedTx.expectedPayDate = edits.expectedPayDate
            await viewModel.updateProductionTransaction(original: tx, updated: updatedTx)
        }
        
        // Save retail order debts
        for bill in allRetailOrders {
            guard let newDebt = editedRetailOrderDebts[bill.id] else { continue }
            guard bill.effectiveDebt != newDebt else { continue }
            var updatedBill = bill
            updatedBill.debtAmount = newDebt > 0 ? newDebt : nil
            updatedBill.paidAmount = newDebt <= 0 ? bill.total : bill.paidAmount
            updatedBill.isPaid = newDebt <= 0
            do {
                try await SupabaseDatabaseService().updateOrder(updatedBill)
            } catch {
                print("❌ Failed to update retail order debt: \(error)")
            }
        }
        
        // Cập nhật updatedAt của party để đưa lên đầu list
        var updatedParty = currentParty
        updatedParty.updatedAt = Date()
        updatedParty.totalDebt = totalDebt
        try? await SupabaseDatabaseService().upsertTradingParty(updatedParty)
        
        await MainActor.run {
            showDebtEdit = false
        }
        
        await loadTransactions()
        await viewModel.loadEditedProductionTxIds()
        await onDebtSaved?()
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
            if !currentParty.email.isEmpty {
                Label(currentParty.email, systemImage: "envelope.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if let birthday = currentParty.birthday {
                Label(formatDateOnly(birthday), systemImage: "birthday.cake.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if !isSupplier {
                let categoryLabel: String = {
                    switch currentParty.customerCategory {
                    case "patient": return "Bệnh nhân"
                    case "partner": return "Đối tác"
                    default: return "Khách mua sản phẩm"
                    }
                }()
                Label(categoryLabel, systemImage: currentParty.customerCategory == "patient" ? "heart.text.square.fill" : currentParty.customerCategory == "partner" ? "handshake.fill" : "cart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if currentParty.customerCategory == "patient" {
                Divider()
                if !currentParty.diseaseDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mô tả bệnh:").font(.caption).foregroundStyle(.gray.opacity(0.7))
                        Text(currentParty.diseaseDescription).font(.subheadline).foregroundStyle(.gray)
                    }
                }
                if !currentParty.patientNote.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ghi chú:").font(.caption).foregroundStyle(.gray.opacity(0.7))
                        Text(currentParty.patientNote).font(.subheadline).foregroundStyle(.gray)
                    }
                }
                if !currentParty.treatmentName.isEmpty || !currentParty.treatmentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Liệu trình đang sử dụng:").font(.caption).foregroundStyle(.gray.opacity(0.7))
                        if !currentParty.treatmentName.isEmpty {
                            Text(currentParty.treatmentName).font(.subheadline).foregroundStyle(.gray)
                        }
                        if !currentParty.treatmentSessions.isEmpty {
                            ForEach(Array(currentParty.treatmentSessions.enumerated()), id: \.element.id) { index, session in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        let statusColor: Color = switch session.status {
                                            case "completed": .green
                                            case "cancelled": .red
                                            default: .orange
                                        }
                                        Circle().fill(statusColor).frame(width: 8, height: 8)
                                        Text("Buổi \(index + 1)")
                                            .font(.subheadline)
                                            .foregroundStyle(.gray)
                                        if let time = session.time {
                                            Text(formatDateTime(time))
                                                .font(.subheadline)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        if !session.name.isEmpty {
                                            Text(session.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        let statusLabel: String = switch session.status {
                                            case "completed": "Hoàn thành"
                                            case "cancelled": "Đã huỷ"
                                            default: "Chờ"
                                        }
                                        Text(statusLabel)
                                            .font(.caption)
                                            .foregroundStyle(statusColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(statusColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    if session.status == "completed" {
                                        HStack {
                                            Button {
                                                showFeatureInDevelopment = true
                                            } label: {
                                                Label("Gửi email lấy ý kiến", systemImage: "envelope.fill")
                                            }
                                            .buttonStyle(.borderedProminent)
                                            Spacer()
                                        }
                                        if !session.feedback.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Ý kiến khách hàng:")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray.opacity(0.7))
                                                Text(session.feedback)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
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

    private var totalDebt: Double {
        let txDebt = allPartyTxs.reduce(0) { $0 + $1.effectiveDebt }
        let retailDebt = allRetailOrders.reduce(0) { $0 + $1.effectiveDebt }
        return txDebt + retailDebt
    }

    private var debtCard: some View {
        HStack(spacing: 12) {
            Image(systemName: totalDebt > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(totalDebt > 0 ? .red : .green)
            VStack(alignment: .leading, spacing: 4) {
                Text(isSupplier ? "Thiếu nợ hiện tại" : "Công nợ hiện tại")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(formatCurrency(totalDebt))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(totalDebt > 0 ? .red : .green)
            }
            Spacer()
            Button {
                // Initialize editedTransactions with current values
                var initialEdits: [UUID: (debtAmount: Double, expectedPayDate: Date?)] = [:]
                for tx in allPartyTxs {
                    initialEdits[tx.id] = (
                        debtAmount: tx.effectiveDebt,
                        expectedPayDate: tx.expectedPayDate
                    )
                }
                editedTransactions = initialEdits
                // Init retail order debts
                var initialRetailDebts: [UUID: Double] = [:]
                for bill in allRetailOrders where bill.effectiveDebt > 0 {
                    initialRetailDebts[bill.id] = bill.effectiveDebt
                }
                editedRetailOrderDebts = initialRetailDebts
                showDebtEdit = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.themePrimary)
            }
            Button {
                showDebtHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title)
                    .foregroundStyle(Color.themePrimary)
            }
        }
        .padding(14)
        .background(totalDebt > 0 ? Color.red.opacity(0.06) : Color.green.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var retailPurchaseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Thống kê mua hàng")
                        .font(.headline)
                        .foregroundStyle(Color.themeTextDark)
                    Text(retailFilterLabel)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Menu {
                    Button("Từ trước đến nay") { showAllRetailHistory = true }
                    Divider()
                    Button("Tất cả tháng") {
                        showAllRetailHistory = false
                        selectedRetailMonth = nil
                    }
                    Divider()
                    ForEach(1...12, id: \.self) { month in
                        Button("Tháng \(month)") {
                            showAllRetailHistory = false
                            selectedRetailMonth = month
                        }
                    }
                } label: {
                    Label(retailMonthMenuTitle, systemImage: "calendar")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(retailYears, id: \.self) { year in
                        Button(String(year)) {
                            showAllRetailHistory = false
                            selectedRetailYear = year
                        }
                    }
                } label: {
                    Text(verbatim: showAllRetailHistory ? "Tất cả" : String(selectedRetailYear))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .disabled(showAllRetailHistory)
            }

            HStack(spacing: 10) {
                retailMetric("Tổng đã mua", formatCurrency(filteredRetailTotal), .themePrimary)
                retailMetric("Số đơn", "\(filteredRetailOrders.count)", .gray)
            }
            HStack(spacing: 10) {
                retailMetric("Đã trả", formatCurrency(filteredRetailPaid), .green)
                retailMetric("Công nợ", formatCurrency(filteredRetailDebt), filteredRetailDebt > 0 ? .red : .green)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var retailMonthMenuTitle: String {
        if showAllRetailHistory {
            return "Từ trước đến nay"
        }
        return selectedRetailMonth.map { "Tháng \($0)" } ?? "Tất cả tháng"
    }

    private var retailFilterLabel: String {
        if showAllRetailHistory {
            return "Toàn bộ lịch sử"
        }
        if let month = selectedRetailMonth {
            return "Tháng \(month)/\(selectedRetailYear)"
        }
        return "Cả năm \(selectedRetailYear)"
    }

    private func retailMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
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
                    Button {
                        selectedProductionTx = tx
                        showProductionDetail = true
                    } label: {
                        txCard(tx)
                    }
                    .buttonStyle(.plain)
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
                if let stt = tx.sequenceNumber {
                    Text("• \(stt)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
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
                    Text(FormatUtils.formatWeight(item.quantity, unit: item.unit))
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
            if tx.effectiveDebt > 0 {
                let debt = tx.effectiveDebt
                HStack(spacing: 6) {
                    Image(systemName: debtStatus == .overdue ? "xmark.circle.fill" : debtStatus == .warning ? "exclamationmark.circle.fill" : "clock.fill")
                        .font(.caption)
                        .foregroundStyle(debtStatus.color)
                    Text("Còn nợ: \(formatCurrency(debt))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(debtStatus.color)
                    if orderViewModel.editedProductionTxIds.contains(tx.id) {
                        Button {
                            Task {
                                let edits = await orderViewModel.fetchProductionEdits(for: tx.id)
                                await MainActor.run {
                                    selectedEditHistoryTxId = tx.id
                                    editHistoryEntries = edits
                                    showEditHistoryPopover = true
                                }
                            }
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }
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
            } else if tx.effectiveDebt <= 0 {
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
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.4))
                .padding(.trailing, 14)
        }
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
            if bill.effectiveDebt > 0 {
                let debt = bill.effectiveDebt
                HStack {
                    Text("Công nợ:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(formatCurrency(debt))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            } else if let paid = bill.paidAmount, paid < bill.total {
                HStack {
                    Text("Đã trả:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(formatCurrency(paid))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.4))
                .padding(.trailing, 14)
        }
        .padding(.horizontal)
    }

    enum TransactionDebtHighlightStatus {
        case normal, warning, overdue
        var color: Color {
            switch self {
            case .normal: return .orange
            case .warning: return .yellow
            case .overdue: return .red
            }
        }
    }

    private func debtHighlight(_ tx: ProductionTransaction) -> TransactionDebtHighlightStatus {
        guard tx.effectiveDebt > 0, let payDate = tx.expectedPayDate else {
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
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm dd/MM/yyyy"
        return f.string(from: date)
    }

    private func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let db = SupabaseDatabaseService()

        async let retailTask = db.fetchOrdersByCustomerName(currentParty.name)
        async let productionTask = db.fetchProductionTransactions(mode: nil)

        // Filter production by party name + phone, exclude deleted — for total debt (all time)
        let name = currentParty.name.lowercased()
        let phone = currentParty.phone
        let all = (try? await productionTask) ?? []
        let allPartyTxsFiltered = all.filter { tx in
            guard !tx.isDeleted else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }
        
        // Await fetched retail orders once
        let fetched = (try? await retailTask) ?? []
        
        await MainActor.run {
            self.allPartyTxs = allPartyTxsFiltered
            // For display, use only last 30 days
            self.transactions = allPartyTxsFiltered.filter { $0.createdAt >= since }
            
            let allRetailFetched = fetched.filter { !$0.isDeleted }
            self.allRetailOrders = allRetailFetched
            // For retail list UI display, also use last 30 days
            self.retailOrders = allRetailFetched.filter { $0.createdAt >= since }
            
            // Update currentParty.totalDebt to reflect all-time total (optional, but keeps consistency)
            let txDebtAllTime = allPartyTxsFiltered.reduce(0) { $0 + $1.effectiveDebt }
            let retailDebtAllTime = allRetailFetched.reduce(0) { $0 + $1.effectiveDebt }
            let allTimeTotalDebt = txDebtAllTime + retailDebtAllTime
            self.currentParty.totalDebt = allTimeTotalDebt
        }
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
    @State private var taxCode: String
    @State private var email: String
    @State private var birthday: Date?
    @State private var showBirthdayPicker = false
    @State private var customerCategory: String
    @State private var diseaseDescription: String
    @State private var patientNote: String
    @State private var treatmentName: String
    @State private var treatmentSessions: [TreatmentSession]
    @State private var showSessionEditor = false
    @State private var editingSessionIndex: Int? = nil
    @State private var tempSession: TreatmentSession = TreatmentSession()
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
        _taxCode   = State(initialValue: party.taxCode ?? "")
        _email     = State(initialValue: party.email)
        _birthday  = State(initialValue: party.birthday)
        _customerCategory = State(initialValue: party.customerCategory)
        _diseaseDescription = State(initialValue: party.diseaseDescription)
        _patientNote = State(initialValue: party.patientNote)
        _treatmentName = State(initialValue: party.treatmentName)
        _treatmentSessions = State(initialValue: party.treatmentSessions)
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
        email.trimmingCharacters(in: .whitespacesAndNewlines) != party.email ||
        birthday != party.birthday ||
        customerCategory != party.customerCategory ||
        diseaseDescription.trimmingCharacters(in: .whitespacesAndNewlines) != party.diseaseDescription ||
        patientNote.trimmingCharacters(in: .whitespacesAndNewlines) != party.patientNote ||
        treatmentName.trimmingCharacters(in: .whitespacesAndNewlines) != party.treatmentName ||
        treatmentSessions != party.treatmentSessions ||
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
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundStyle(.gray)
                            .frame(width: 22)
                        TextField("MST", text: $taxCode)
                    }
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 22)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    HStack {
                        Image(systemName: "birthday.cake.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 22)
                        Button {
                            showBirthdayPicker.toggle()
                        } label: {
                            if let birthday = birthday {
                                Text(formatDateOnly(birthday))
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Chọn ngày sinh")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    if !isSupplier {
                        Picker("Phân loại khách hàng", selection: $customerCategory) {
                            Text("Khách mua sản phẩm").tag("buyer")
                            Text("Bệnh nhân").tag("patient")
                            Text("Đối tác").tag("partner")
                        }
                    }
                }
                
                if customerCategory == "patient" {
                    Section(header: Text("Thông tin bệnh nhân")) {
                        TextEditor(text: $diseaseDescription)
                            .frame(minHeight: 80)
                            .overlay(
                                Text("Mô tả bệnh")
                                    .foregroundColor(diseaseDescription.isEmpty ? .gray.opacity(0.5) : .clear)
                                    .padding(.top, 8),
                                alignment: .topLeading
                            )
                        TextEditor(text: $patientNote)
                            .frame(minHeight: 80)
                            .overlay(
                                Text("Ghi chú")
                                    .foregroundColor(patientNote.isEmpty ? .gray.opacity(0.5) : .clear)
                                    .padding(.top, 8),
                                alignment: .topLeading
                            )
                    }
                    
                    Section(header: Text("Liệu trình đang sử dụng")) {
                        TextField("Tên liệu trình", text: $treatmentName)
                        ForEach(Array(treatmentSessions.enumerated()), id: \.element.id) { index, session in
                            HStack(spacing: 8) {
                                Text("Buổi \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                if let time = session.time {
                                    Text(formatDateTime(time))
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                let statusColor: Color = switch session.status {
                                    case "completed": .green
                                    case "cancelled": .red
                                    default: .orange
                                }
                                Text(session.status == "pending" ? "Chờ" : session.status == "completed" ? "Hoàn thành" : "Đã huỷ")
                                    .font(.caption)
                                    .foregroundStyle(statusColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(statusColor.opacity(0.1))
                                    .clipShape(Capsule())
                                Button {
                                    editingSessionIndex = index
                                    tempSession = treatmentSessions[index]
                                    showSessionEditor = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                            }
                        }
                        .onDelete(perform: { offsets in
                            treatmentSessions.remove(atOffsets: offsets)
                        })
                        Button {
                            treatmentSessions.append(TreatmentSession(name: "Buổi \(treatmentSessions.count + 1)", time: Date(), status: "pending"))
                        } label: {
                            Label("Thêm buổi", systemImage: "plus.circle.fill")
                        }
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
            .sheet(isPresented: $showBirthdayPicker) {
                BirthdayPickerSheet(
                    birthday: $birthday,
                    isPresented: $showBirthdayPicker
                )
            }
            .sheet(isPresented: $showSessionEditor) {
                if let index = editingSessionIndex, index < treatmentSessions.count {
                    NavigationStack {
                        Form {
                            Section(header: Text("Thông tin buổi")) {
                                HStack {
                                    Text("Buổi \(index + 1)")
                                        .foregroundStyle(.gray)
                                    Spacer()
                                }
                                TextField("Tên buổi", text: $tempSession.name)
                                DatePicker(
                                    "Thời gian",
                                    selection: Binding(
                                        get: { tempSession.time ?? Date() },
                                        set: { tempSession.time = $0 }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                Picker("Trạng thái", selection: $tempSession.status) {
                                    Text("Chờ").tag("pending")
                                    Text("Hoàn thành").tag("completed")
                                    Text("Đã huỷ").tag("cancelled")
                                }
                            }
                            if tempSession.status == "completed" {
                                Section(header: Text("Ý kiến khách hàng")) {
                                    TextEditor(text: $tempSession.feedback)
                                        .frame(minHeight: 100)
                                        .overlay(
                                            Text("Nhập ý kiến khách hàng")
                                                .foregroundColor(tempSession.feedback.isEmpty ? .gray.opacity(0.5) : .clear)
                                                .padding(.top, 8),
                                            alignment: .topLeading
                                        )
                                }
                            }
                        }
                        .navigationTitle("Chỉnh sửa buổi")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Huỷ") { showSessionEditor = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Lưu") {
                                    treatmentSessions[index] = tempSession
                                    showSessionEditor = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for existing party first (only if it's a new party or name/phone changed)
        var finalId = party.id
        let db = SupabaseDatabaseService()
        do {
            if let existing = try await db.fetchTradingPartyByNameOrPhone(trimmedName, trimmedPhone, party.partyType) {
                // If existing ID is different from current party's, use existing ID to prevent duplicates
                if existing.id != party.id {
                    finalId = existing.id
                }
            }
        } catch {
            print("⚠️ Could not check for existing party: \(error)")
        }

        // Upload pending images
        var newURLs: [String] = []
        uploadProgress = 0
        for img in pendingImages {
            guard let data = img.jpegData(compressionQuality: 0.82) else { continue }
            let fileName = UUID().uuidString
            if let url = try? await StorageManager.shared.uploadPartyImage(
                data: data, partyId: finalId, fileName: fileName
            ) {
                newURLs.append(url)
            }
            uploadProgress += 1
        }

        var updated = party
        updated.id = finalId
        updated.name      = trimmedName
        updated.phone     = trimmedPhone
        updated.address   = address.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.taxCode   = taxCode.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.email     = email.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.birthday  = birthday
        updated.customerCategory = customerCategory
        updated.diseaseDescription = diseaseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.patientNote = patientNote.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.treatmentName = treatmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.treatmentSessions = treatmentSessions
        updated.imageURLs = imageURLs + newURLs
        updated.updatedAt = Date()

        do {
            try await db.upsertTradingParty(updated)
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
    
    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}

private struct BirthdayPickerSheet: View {
    @Binding var birthday: Date?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            DatePicker(
                "Ngày sinh",
                selection: Binding(
                    get: { birthday ?? Date() },
                    set: { birthday = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Chọn ngày sinh")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { isPresented = false }
                }
                if birthday != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { 
                            birthday = nil
                            isPresented = false
                        } label: {
                            Text("Xoá")
                        }
                    }
                }
            }
        }
    }
}

private struct SessionIndexWrapper: Identifiable {
    let id: UUID = UUID()
    let index: Int
}

private struct TreatmentSessionEditSheet: View {
    @Binding var session: TreatmentSession
    @Binding var isPresented: Bool
    let index: Int
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thông tin buổi")) {
                    HStack {
                        Text("Buổi \(index + 1)")
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                    TextField("Tên buổi", text: $session.name)
                    DatePicker(
                        "Thời gian",
                        selection: Binding(
                            get: { session.time ?? Date() },
                            set: { session.time = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Picker("Trạng thái", selection: $session.status) {
                        Text("Chờ").tag("pending")
                        Text("Hoàn thành").tag("completed")
                        Text("Đã huỷ").tag("cancelled")
                    }
                }
            }
            .navigationTitle("Chỉnh sửa buổi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
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
        case "partner":     return "building.2.fill"
        case "appointment": return "calendar.badge.plus"
        case "feedback":    return "bubble.left.fill"
        default:            return "person.fill.questionmark"
        }
    }

    private var iconColor: Color {
        switch lead.leadType {
        case "partner":     return .orange
        case "appointment": return .blue
        case "feedback":    return .purple
        default:            return .teal
        }
    }

    private var typeLabel: String {
        switch lead.leadType {
        case "partner":     return "Đối tác"
        case "appointment": return "Đặt lịch"
        case "feedback":    return "Góp ý"
        default:            return "Tư vấn"
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
        case "feedback":    return "Góp ý"
        default:            return "Tư vấn dịch vụ"
        }
    }

    private func typeLabel(_ t: String) -> String {
        switch t {
        case "appointment": return "Đặt lịch"
        case "partner":     return "Đối tác"
        case "feedback":    return "Góp ý"
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

private struct DebtEditView: View {
    let transactions: [ProductionTransaction]
    let allRetailOrders: [Bill]
    let isSupplier: Bool
    let editedTxIds: Set<UUID>
    let fetchEdits: (UUID) async -> [ProductionEdit]
    @Binding var editedTransactions: [UUID: (debtAmount: Double, expectedPayDate: Date?)]
    @Binding var editedRetailOrderDebts: [UUID: Double]
    let onSave: () async -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showEditHistory = false
    @State private var selectedEditHistoryTxId: UUID?
    @State private var editHistoryEntries: [ProductionEdit] = []
    @State private var showDebtAmountWheel = false
    @State private var selectedDebtTxId: UUID?
    @State private var debtAmountSelection = 0
    @State private var debtAmountMillionsSelection = 0
    @State private var debtAmountThousandsSelection = 0
    @State private var debtAmountHundredsSelection = 0
    @State private var debtAmountMillionsRangeBase = 0
    @State private var debtAmountThousandsRangeBase = 0
    @State private var debtAmountHundredsRangeBase = 0
    @State private var showDebtAmountMillionsRangePicker = false
    @State private var showDebtAmountThousandsRangePicker = false
    @State private var showDebtAmountHundredsRangePicker = false
    @State private var showPayOffAll = false
    @State private var isSaving = false
    
    private var debtAmountMillionsRange: [Int] {
        let millionsMin = debtAmountMillionsRangeBase
        let upperBound = max(millionsMin, millionsMin + 500)
        return Array(millionsMin...upperBound)
    }
    
    private var debtAmountThousandsRange: [Int] {
        let thousandsMin = debtAmountThousandsRangeBase
        let upperBound = min(thousandsMin + 999, 999)
        return Array(thousandsMin...upperBound)
    }
    
    private var debtAmountHundredsRange: [Int] {
        let hundredsMin = debtAmountHundredsRangeBase
        let upperBound = min(hundredsMin + 99, 999)
        return Array(stride(from: hundredsMin, through: upperBound, by: 1))
    }
    
    private var sortedTransactions: [ProductionTransaction] {
        transactions.sorted { (a, b) in
            if a.effectiveDebt > 0 && b.effectiveDebt <= 0 {
                return true
            }
            if a.effectiveDebt <= 0 && b.effectiveDebt > 0 {
                return false
            }
            if a.effectiveDebt > 0 && b.effectiveDebt > 0 {
                if a.effectiveDebt != b.effectiveDebt {
                    return a.effectiveDebt > b.effectiveDebt
                }
            }
            return a.createdAt > b.createdAt
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private var totalEditedDebt: Double {
        let txDebt = editedTransactions.values.reduce(0) { $0 + $1.debtAmount }
        let retailDebt = editedRetailOrderDebts.values.reduce(0) { $0 + $1 }
        return txDebt + retailDebt
    }
    
    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.numberStyle = .currency
        f.currencyCode = "VND"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "\(amount) đ"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    if totalEditedDebt > 0 {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Tổng \(isSupplier ? "thiếu nợ" : "công nợ"): \(formatCurrency(totalEditedDebt))")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("Trả hết") {
                        showPayOffAll = true
                    }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.themePrimary)
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(totalEditedDebt > 0 ? Color.orange.opacity(0.06) : Color.clear)
                
                List {
                    // Production transactions section
                    if !sortedTransactions.isEmpty {
                        Section(header: Text("Giao dịch sản xuất").font(.headline)) {
                            ForEach(sortedTransactions) { tx in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(tx.mode)
                                            .font(.subheadline).fontWeight(.semibold)
                                        if let stt = tx.sequenceNumber {
                                            Text("• \(stt)")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(formatDateOnly(tx.createdAt))
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                    
                                    if !tx.items.isEmpty {
                                        Text(tx.items.map { $0.name }.joined(separator: ", "))
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Text(isSupplier ? "Thiếu nợ" : "Công nợ")
                                            .font(.subheadline).foregroundStyle(.gray)
                                        if editedTxIds.contains(tx.id) {
                                            Button {
                                                Task {
                                                    let edits = await fetchEdits(tx.id)
                                                    await MainActor.run {
                                                        selectedEditHistoryTxId = tx.id
                                                        editHistoryEntries = edits
                                                        showEditHistory = true
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        Spacer()
                                        Button {
                                            selectedDebtTxId = tx.id
                                            let currentDebt = editedTransactions[tx.id]?.debtAmount ?? tx.effectiveDebt
                                            debtAmountSelection = Int(currentDebt)
                                            showDebtAmountWheel = true
                                        } label: {
                                            let currentDebtVal: Double = editedTransactions[tx.id]?.debtAmount ?? tx.effectiveDebt
                                            let formattedText: String = formatCurrency(currentDebtVal)
                                            Text(formattedText)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text("đ").font(.subheadline).foregroundStyle(.gray)
                                    }
                                    
                                    HStack {
                                        Text("Dự kiến trả")
                                            .font(.subheadline).foregroundStyle(.gray)
                                        Spacer()
                                        let currentDate = editedTransactions[tx.id]?.expectedPayDate ?? tx.expectedPayDate
                                        Button {
                                            if var edits = editedTransactions[tx.id] {
                                                edits.expectedPayDate = edits.expectedPayDate == nil ? Date() : nil
                                                editedTransactions[tx.id] = edits
                                            } else {
                                                editedTransactions[tx.id] = (debtAmount: tx.effectiveDebt, expectedPayDate: Date())
                                            }
                                        } label: {
                                            let dateText: String = currentDate == nil
                                                ? "Chưa xác định"
                                                : formatDateOnly(currentDate!)
                                            let dateColor: Color = currentDate == nil ? .gray : Color.themePrimary
                                            Text(dateText)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(dateColor)
                                        }
                                        if currentDate != nil {
                                            DatePicker(
                                                "",
                                                selection: Binding(
                                                    get: { currentDate! },
                                                    set: { newDate in
                                                        if var edits = editedTransactions[tx.id] {
                                                            edits.expectedPayDate = newDate
                                                            editedTransactions[tx.id] = edits
                                                        } else {
                                                            editedTransactions[tx.id] = (debtAmount: tx.effectiveDebt, expectedPayDate: newDate)
                                                        }
                                                    }
                                                ),
                                                displayedComponents: [.date]
                                            )
                                            .labelsHidden()
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // Retail orders section - only show orders with debt > 0
                    let retailOrdersWithDebt = allRetailOrders.filter { (editedRetailOrderDebts[$0.id] ?? $0.effectiveDebt) > 0 }
                    if !retailOrdersWithDebt.isEmpty {
                        Section(header: Text("Đơn bán lẻ").font(.headline)) {
                            ForEach(retailOrdersWithDebt) { bill in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Đơn bán lẻ")
                                            .font(.subheadline).fontWeight(.semibold)
                                        if let stt = bill.sequenceNumber {
                                            Text("• \(stt)")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(formatDateOnly(bill.createdAt))
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                    
                                    if !bill.items.isEmpty {
                                        Text(bill.items.map { $0.name }.joined(separator: ", "))
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Text("Công nợ")
                                            .font(.subheadline).foregroundStyle(.gray)
                                        Spacer()
                                        Button {
                                            selectedDebtTxId = bill.id
                                            let currentDebt = editedRetailOrderDebts[bill.id] ?? bill.effectiveDebt
                                            debtAmountSelection = Int(currentDebt)
                                            showDebtAmountWheel = true
                                        } label: {
                                            let currentDebt = editedRetailOrderDebts[bill.id] ?? bill.effectiveDebt
                                            Text(formatCurrency(currentDebt))
                                                .font(.subheadline).fontWeight(.semibold)
                                        }
                                        Text("đ").font(.subheadline).foregroundStyle(.gray)
                                    }
                                    
                                    HStack {
                                        Text("Tổng đơn hàng")
                                            .font(.subheadline).foregroundStyle(.gray)
                                        Spacer()
                                        Text(formatCurrency(bill.total))
                                            .font(.subheadline)
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(isSupplier ? "Chỉnh sửa thiếu nợ" : "Chỉnh sửa công nợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { onCancel() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            isSaving = true
                            await onSave()
                            isSaving = false
                        }
                    }
                        .fontWeight(.bold)
                        .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Đang lưu...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(Color.gray.opacity(0.9))
                        .cornerRadius(16)
                    }
                }
            }
            .sheet(isPresented: $showEditHistory) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lịch sử chỉnh sửa")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if editHistoryEntries.isEmpty {
                            Text("Không có lịch sử chỉnh sửa")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        } else {
                            List(editHistoryEntries) { edit in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(formatDateTime(edit.createdAt))
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        if let editorName = edit.editorName {
                                            Text(editorName)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    
                                    if let details = edit.details, !details.isEmpty {
                                        ForEach(details, id: \.self) { detail in
                                            Text("• \(detail)")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .listStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Lịch sử chỉnh sửa")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") {
                                showEditHistory = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPayOffAll) {
                NavigationStack {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Xác nhận trả hết")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Tổng số tiền cần trả: \(formatCurrency(totalEditedDebt))")
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        
                        Divider()
                        
                        List {
                            ForEach(sortedTransactions) { tx in
                                let currentDebt = editedTransactions[tx.id]?.debtAmount ?? tx.effectiveDebt
                                if currentDebt > 0 {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tx.mode)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(formatDateOnly(tx.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(formatCurrency(currentDebt))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            ForEach(allRetailOrders) { bill in
                                let currentDebt = editedRetailOrderDebts[bill.id] ?? bill.effectiveDebt
                                if currentDebt > 0 {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Đơn bán lẻ")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(bill.sequenceNumber ?? formatDateOnly(bill.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(formatCurrency(currentDebt))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        
                        Divider()
                        
                        Button {
                            for tx in transactions {
                                if var existing = editedTransactions[tx.id] {
                                    existing.debtAmount = 0
                                    editedTransactions[tx.id] = existing
                                } else if tx.effectiveDebt > 0 {
                                    editedTransactions[tx.id] = (debtAmount: 0, expectedPayDate: tx.expectedPayDate)
                                }
                            }
                            // Set retail orders debt về 0
                            for bill in allRetailOrders where (editedRetailOrderDebts[bill.id] ?? bill.effectiveDebt) > 0 {
                                editedRetailOrderDebts[bill.id] = 0
                            }
                            showPayOffAll = false
                            Task {
                                isSaving = true
                                await onSave()
                                isSaving = false
                            }
                        } label: {
                            Text("Xác nhận trả hết")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.themePrimary)
                                .cornerRadius(12)
                        }
                        .disabled(isSaving)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    .navigationTitle("Trả hết nợ")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Đóng") {
                                showPayOffAll = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDebtAmountWheel) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text(isSupplier ? "Sửa thiếu nợ" : "Sửa công nợ").font(.headline)
                        Text(formatCurrency(Double(debtAmountSelection)))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                        HStack(alignment: .top) {
                            VStack(spacing: 2) {
                                Button { showDebtAmountMillionsRangePicker = true } label: {
                                    Text(debtAmountMillionsRangeBase <= 0 ? ">0" : ">\(debtAmountMillionsRangeBase)tr")
                                        .fontWeight(.bold).font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Triệu")
                                    .font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $debtAmountMillionsSelection) {
                                    ForEach(debtAmountMillionsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: debtAmountMillionsSelection) { v in
                                    debtAmountSelection = v * 1_000_000 + debtAmountThousandsSelection * 1_000 + debtAmountHundredsSelection
                                }
                            }
                            VStack(spacing: 2) {
                                Button { showDebtAmountThousandsRangePicker = true } label: {
                                    Text(debtAmountThousandsRangeBase <= 0 ? ">0" : ">\(debtAmountThousandsRangeBase)")
                                        .fontWeight(.bold).font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Ngàn")
                                    .font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $debtAmountThousandsSelection) {
                                    ForEach(debtAmountThousandsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: debtAmountThousandsSelection) { v in
                                    debtAmountSelection = debtAmountMillionsSelection * 1_000_000 + v * 1_000 + debtAmountHundredsSelection
                                }
                            }
                            VStack(spacing: 2) {
                                Button { showDebtAmountHundredsRangePicker = true } label: {
                                    Text(debtAmountHundredsRangeBase <= 0 ? ">0" : "\(debtAmountHundredsRangeBase)")
                                        .fontWeight(.bold).font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                                Text("Trăm")
                                    .font(.caption).foregroundStyle(.gray)
                                Picker("", selection: $debtAmountHundredsSelection) {
                                    ForEach(debtAmountHundredsRange, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .onChange(of: debtAmountHundredsSelection) { v in
                                    debtAmountSelection = debtAmountMillionsSelection * 1_000_000 + debtAmountThousandsSelection * 1_000 + v
                                }
                            }
                        }
                        HStack {
                            Button("Đóng") { showDebtAmountWheel = false }
                            Spacer()
                            Button("Lưu") {
                                if let txId = selectedDebtTxId {
                                    // Check if it's a production transaction first
                                    if let tx = transactions.first(where: { $0.id == txId }) {
                                        if var edits = editedTransactions[txId] {
                                            edits.debtAmount = Double(debtAmountSelection)
                                            editedTransactions[txId] = edits
                                        } else {
                                            editedTransactions[txId] = (debtAmount: Double(debtAmountSelection), expectedPayDate: tx.expectedPayDate)
                                        }
                                    }
                                    // Otherwise, check if it's a retail order
                                    else if allRetailOrders.contains(where: { $0.id == txId }) {
                                        editedRetailOrderDebts[txId] = Double(debtAmountSelection)
                                    }
                                }
                                showDebtAmountWheel = false
                            }
                        }
                        .font(.headline)
                    }
                    .padding()
                    .presentationDetents([.height(340)])
                    .onAppear {
                        let current = max(0, debtAmountSelection)
                        debtAmountMillionsSelection = current / 1_000_000
                        debtAmountMillionsRangeBase = (debtAmountMillionsSelection / 10) * 10
                        let rem1 = current % 1_000_000
                        debtAmountThousandsSelection = rem1 / 1_000
                        debtAmountThousandsRangeBase = (debtAmountThousandsSelection / 100) * 100
                        let rem2 = rem1 % 1_000
                        debtAmountHundredsRangeBase = (rem2 / 100) * 100
                        debtAmountHundredsSelection = (rem2 / 10) * 10
                    }
                    .sheet(isPresented: $showDebtAmountMillionsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng triệu").font(.headline)
                            Picker("", selection: $debtAmountMillionsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 900, by: 50)), id: \.self) { v in
                                    Text(v == 0 ? ">0" : ">\(v)tr").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if debtAmountMillionsSelection < debtAmountMillionsRangeBase {
                                    debtAmountMillionsSelection = debtAmountMillionsRangeBase
                                }
                                showDebtAmountMillionsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                    .sheet(isPresented: $showDebtAmountThousandsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng ngàn").font(.headline)
                            Picker("", selection: $debtAmountThousandsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 999, by: 100)), id: \.self) { v in
                                    Text(v == 0 ? ">0" : ">\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if debtAmountThousandsSelection < debtAmountThousandsRangeBase {
                                    debtAmountThousandsSelection = debtAmountThousandsRangeBase
                                }
                                showDebtAmountThousandsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                    .sheet(isPresented: $showDebtAmountHundredsRangePicker) {
                        VStack(spacing: 16) {
                            Text("Chọn vùng trăm").font(.headline)
                            Picker("", selection: $debtAmountHundredsRangeBase) {
                                ForEach(Array(stride(from: 0, through: 900, by: 100)), id: \.self) { v in
                                    Text(v == 0 ? "0-99" : "\(v)-\(v+99)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            Button {
                                if debtAmountHundredsSelection < debtAmountHundredsRangeBase || debtAmountHundredsSelection > debtAmountHundredsRangeBase + 99 {
                                    debtAmountHundredsSelection = debtAmountHundredsRangeBase
                                }
                                showDebtAmountHundredsRangePicker = false
                            } label: {
                                Text("Xong")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.themePrimary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .presentationDetents([.height(300)])
                    }
                }
            }
        }
    }
}
