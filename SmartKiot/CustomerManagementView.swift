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
        return list.sorted { $0.updatedAt > $1.updatedAt }
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

    private func calculateTotalDebt(for party: TradingParty, allProductionTxs: [ProductionTransaction]) -> Double {
        let name = party.name.lowercased()
        let phone = party.phone
        return allProductionTxs.filter { tx in
            guard !tx.isDeleted else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }.reduce(0) { $0 + ($1.debtAmount ?? 0) }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch all production transactions first
        let db = SupabaseDatabaseService()
        let modes = ["Nhập Nguyên liệu", "Xuất Nguyên liệu", "Nhập Thành Phẩm", "Xuất Thành Phẩm"]
        var allProductionTxs: [ProductionTransaction] = []
        for mode in modes {
            let txs = (try? await db.fetchProductionTransactions(mode: mode)) ?? []
            allProductionTxs += txs
        }
        
        // Then fetch buyers and suppliers
        async let buyers = (try? db.fetchTradingParties(type: "buyer")) ?? []
        async let suppliers = (try? db.fetchTradingParties(type: "supplier")) ?? []
        async let fetchedLeads = (try? db.fetchWebsiteLeads()) ?? []
        let (b, s, l) = await (buyers, suppliers, fetchedLeads)
        
        // Calculate total debt for each party
        var updatedParties: [TradingParty] = []
        for party in b + s {
            var updated = party
            let newTotalDebt = calculateTotalDebt(for: party, allProductionTxs: allProductionTxs)
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
        
        parties = updatedParties
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
    var onDeleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [ProductionTransaction] = []
    @State private var allPartyTxs: [ProductionTransaction] = [] // All transactions for the party (all time)
    @State private var retailOrders: [Bill] = []
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
    @State private var showEditHistoryPopover = false
    @State private var selectedEditHistoryTxId: UUID?
    @State private var editHistoryEntries: [ProductionEdit] = []

    init(party: TradingParty, onDeleted: (() -> Void)? = nil) {
        self.party = party
        self.onDeleted = onDeleted
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
                    if totalDebt > 0 {
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
            .task { 
                await loadTransactions()
                await orderViewModel.loadEditedProductionTxIds()
            }
            .sheet(isPresented: $showEdit) {
                PartyEditSheet(party: currentParty, onSaved: { updated in
                    currentParty = updated
                }, onDeleted: {
                    onDeleted?()
                    dismiss()
                })
            }
            .sheet(isPresented: $showBillDetail) {
                if let bill = selectedBillForDetail {
                    NavigationStack {
                        BillDetailView(bill: bill, viewModel: orderViewModel)
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
                    isSupplier: isSupplier,
                    editedTxIds: orderViewModel.editedProductionTxIds,
                    fetchEdits: { txId in
                        await orderViewModel.fetchProductionEdits(for: txId)
                    },
                    editedTransactions: $editedTransactions,
                    onSave: {
                        Task { await saveDebtEdits() }
                    },
                    onCancel: {
                        showDebtEdit = false
                    }
                )
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
        
        for tx in allPartyTxs {
            guard let edits = editedTransactions[tx.id] else { continue }
            
            // Check if anything actually changed
            let debtChanged = (tx.debtAmount ?? 0) != edits.debtAmount
            let payDateChanged = tx.expectedPayDate != edits.expectedPayDate
            
            guard debtChanged || payDateChanged else { continue }
            
            var updatedTx = tx
            updatedTx.debtAmount = edits.debtAmount
            updatedTx.expectedPayDate = edits.expectedPayDate
            
            await viewModel.updateProductionTransaction(original: tx, updated: updatedTx)
        }
        
        await MainActor.run {
            showDebtEdit = false
        }
        
        await loadTransactions()
        await viewModel.loadEditedProductionTxIds()
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
        allPartyTxs.reduce(0) { $0 + ($1.debtAmount ?? 0) }
    }

    private var debtCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text(isSupplier ? "Thiếu nợ hiện tại" : "Công nợ hiện tại")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(formatCurrency(totalDebt))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
            Spacer()
            Button {
                // Initialize editedTransactions with current values
                var initialEdits: [UUID: (debtAmount: Double, expectedPayDate: Date?)] = [:]
                for tx in allPartyTxs {
                    initialEdits[tx.id] = (
                        debtAmount: tx.debtAmount ?? 0,
                        expectedPayDate: tx.expectedPayDate
                    )
                }
                editedTransactions = initialEdits
                showDebtEdit = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.themePrimary)
            }
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
            if let debt = tx.debtAmount, debt > 0 {
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

        // Fetch đơn bán lẻ theo tên khách
        async let retailTask = db.fetchOrdersByCustomerName(currentParty.name)

        // Fetch production transactions
        let modes = ["Nhập Nguyên liệu", "Xuất Nguyên liệu", "Nhập Thành Phẩm", "Xuất Thành Phẩm"]
        var all: [ProductionTransaction] = []
        for mode in modes {
            let txs = (try? await db.fetchProductionTransactions(mode: mode)) ?? []
            all += txs
        }

        // Filter production by party name + phone, exclude deleted — for total debt (all time)
        let name = currentParty.name.lowercased()
        let phone = currentParty.phone
        let allPartyTxsFiltered = all.filter { tx in
            guard !tx.isDeleted else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
        }
        
        await MainActor.run {
            self.allPartyTxs = allPartyTxsFiltered
            // For display, use only last 30 days
            self.transactions = allPartyTxsFiltered.filter { $0.createdAt >= since }
            
            // Update currentParty.totalDebt to reflect all-time total (optional, but keeps consistency)
            let allTimeTotalDebt = allPartyTxsFiltered.reduce(0) { $0 + ($1.debtAmount ?? 0) }
            self.currentParty.totalDebt = allTimeTotalDebt
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
    let isSupplier: Bool
    let editedTxIds: Set<UUID>
    let fetchEdits: (UUID) async -> [ProductionEdit]
    @Binding var editedTransactions: [UUID: (debtAmount: Double, expectedPayDate: Date?)]
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showEditHistory = false
    @State private var selectedEditHistoryTxId: UUID?
    @State private var editHistoryEntries: [ProductionEdit] = []
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private var totalEditedDebt: Double {
        editedTransactions.values.reduce(0) { $0 + $1.debtAmount }
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
                if totalEditedDebt > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Tổng \(isSupplier ? "thiếu nợ" : "công nợ"): \(formatCurrency(totalEditedDebt))")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                    .background(Color.orange.opacity(0.06))
                }
                
                List {
                    ForEach(transactions) { tx in
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(tx.mode)
                                        .font(.subheadline).fontWeight(.semibold)
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
                                    TextField("0", text: Binding(
                                        get: {
                                            guard let edits = editedTransactions[tx.id] else { return "0" }
                                            let numberFormatter = NumberFormatter()
                                            numberFormatter.locale = Locale(identifier: "vi_VN")
                                            numberFormatter.numberStyle = .decimal
                                            return numberFormatter.string(from: NSNumber(value: edits.debtAmount)) ?? "\(Int(edits.debtAmount))"
                                        },
                                        set: { newValue in
                                            let clean = newValue.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
                                            let number = Double(clean) ?? 0
                                            if var edits = editedTransactions[tx.id] {
                                                edits.debtAmount = number
                                                editedTransactions[tx.id] = edits
                                            } else {
                                                editedTransactions[tx.id] = (debtAmount: number, expectedPayDate: tx.expectedPayDate)
                                            }
                                        }
                                    ))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline).fontWeight(.semibold)
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
                                            editedTransactions[tx.id] = (debtAmount: tx.debtAmount ?? 0, expectedPayDate: Date())
                                        }
                                    } label: {
                                        Text(currentDate == nil ? "Chưa xác định" : formatDateOnly(currentDate!))
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(currentDate == nil ? .gray : Color.themePrimary)
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
                                                        editedTransactions[tx.id] = (debtAmount: tx.debtAmount ?? 0, expectedPayDate: newDate)
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
                .listStyle(.plain)
            }
            .navigationTitle(isSupplier ? "Chỉnh sửa thiếu nợ" : "Chỉnh sửa công nợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { onSave() }
                        .fontWeight(.bold)
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
        }
    }
}
