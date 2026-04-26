import SwiftUI

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
    @State private var selectedType: PartyTypeFilter = .buyer
    @State private var selectedParty: TradingParty? = nil
    @State private var selectedLead: WebsiteLead? = nil

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
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return leads.sorted { $0.createdAt > $1.createdAt } }
        return leads.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.phone.lowercased().contains(q) ||
            ($0.serviceType?.lowercased().contains(q) ?? false)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalDebt: Double {
        filteredParties.reduce(0) { $0 + $1.totalDebt }
    }

    private var newLeadsCount: Int {
        leads.filter { $0.status == "new" }.count
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
                WebsiteLeadDetailView(lead: lead)
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
            } else if filteredLeads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.4))
                    Text("Chưa có khách từ website").foregroundStyle(.gray)
                    Spacer()
                }.padding(.top, 60)
            } else {
                // Summary bar
                HStack(spacing: 16) {
                    Label("\(leads.count) liên hệ", systemImage: "person.crop.circle")
                        .font(.caption).foregroundStyle(.gray)
                    if newLeadsCount > 0 {
                        Label("\(newLeadsCount) mới", systemImage: "bell.fill")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.teal)
                    }
                    Spacer()
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color.teal.opacity(0.05))

                List {
                    ForEach(filteredLeads) { lead in
                        Button { selectedLead = lead } label: { LeadRowView(lead: lead) }
                            .listRowBackground(Color.white)
                    }
                }
                .listStyle(.plain)
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
    @State private var isLoading = false

    private var isSupplier: Bool { party.partyType == "supplier" }

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
                    if party.totalDebt > 0 {
                        debtCard
                    }

                    // Transactions
                    if isLoading {
                        ProgressView().padding()
                    } else if groupedByDay.isEmpty {
                        Text("Không có giao dịch trong 30 ngày gần nhất")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Giao dịch 30 ngày gần nhất")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(groupedByDay, id: \.date) { group in
                                daySection(group.date, txs: group.txs)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle(party.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task { await loadTransactions() }
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
                    Text(party.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(isSupplier ? "Cơ sở cung cấp" : "Khách hàng")
                        .font(.caption)
                        .foregroundStyle(isSupplier ? .green : .teal)
                }
                Spacer()
            }
            Divider()
            if !party.phone.isEmpty {
                Label(party.phone, systemImage: "phone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if !party.address.isEmpty {
                Label(party.address, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
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
                Text(formatCurrency(party.totalDebt))
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

    // MARK: - Debt highlight logic

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

        // Fetch all production transaction modes
        let modes = ["Nhập Nguyên liệu", "Xuất Nguyên liệu", "Nhập Thành Phẩm", "Xuất Thành Phẩm"]
        var all: [ProductionTransaction] = []
        for mode in modes {
            let txs = (try? await db.fetchProductionTransactions(mode: mode)) ?? []
            all += txs
        }

        // Filter by party name + phone + date
        let name = party.name.lowercased()
        let phone = party.phone
        transactions = all.filter { tx in
            guard tx.createdAt >= since else { return false }
            let matchName = tx.buyerName?.lowercased() == name
            let matchPhone = phone.isEmpty ? false : tx.buyerPhone == phone
            return matchName || matchPhone
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

// MARK: - Lead Row View

private struct LeadRowView: View {
    let lead: WebsiteLead

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(lead.leadType == "appointment" ? Color.blue.opacity(0.12) : Color.teal.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: lead.leadType == "appointment" ? "calendar.badge.plus" : "bubble.left.fill")
                    .foregroundStyle(lead.leadType == "appointment" ? .blue : .teal)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(lead.fullName)
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                    if lead.status == "new" {
                        Text("Mới")
                            .font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.teal))
                    }
                }
                Text(lead.phone).font(.caption).foregroundStyle(.gray)
                if let svc = lead.serviceType, !svc.isEmpty {
                    Text(svc).font(.caption).foregroundStyle(Color.themePrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(lead.leadType == "appointment" ? "Đặt lịch" : "Tư vấn")
                    .font(.caption2).foregroundStyle(lead.leadType == "appointment" ? .blue : .teal)
                Text(formatDateOnly(lead.createdAt)).font(.caption2).foregroundStyle(.gray)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray)
        }
        .padding(.vertical, 4)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM"
        return f.string(from: date)
    }
}

// MARK: - Website Lead Detail View

struct WebsiteLeadDetailView: View {
    let lead: WebsiteLead
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Thông tin liên hệ")) {
                    infoRow(label: "Họ tên", value: lead.fullName, icon: "person.fill")
                    infoRow(label: "Số điện thoại", value: lead.phone, icon: "phone.fill")
                    if let svc = lead.serviceType, !svc.isEmpty {
                        infoRow(label: "Dịch vụ", value: svc, icon: "sparkles")
                    }
                    if let note = lead.note, !note.isEmpty {
                        infoRow(label: "Ghi chú", value: note, icon: "note.text")
                    }
                }

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
                        if let email = lead.email, !email.isEmpty {
                            infoRow(label: "Email", value: email, icon: "envelope.fill")
                        }
                    }
                }

                Section(header: Text("Trạng thái")) {
                    HStack {
                        Image(systemName: statusIcon(lead.status))
                            .foregroundStyle(statusColor(lead.status))
                        Text(statusLabel(lead.status))
                            .foregroundStyle(statusColor(lead.status))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatDateTime(lead.createdAt))
                            .font(.caption).foregroundStyle(.gray)
                    }
                }
            }
            .navigationTitle(lead.leadType == "appointment" ? "Đặt lịch hẹn" : "Tư vấn dịch vụ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
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

    private func statusIcon(_ s: String) -> String {
        switch s {
        case "new": return "bell.fill"
        case "contacted": return "phone.fill"
        case "done": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "new": return .teal
        case "contacted": return .blue
        case "done": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "new": return "Mới"
        case "contacted": return "Đã liên hệ"
        case "done": return "Hoàn tất"
        case "cancelled": return "Đã huỷ"
        default: return s
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
