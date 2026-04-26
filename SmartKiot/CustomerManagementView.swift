import SwiftUI

// MARK: - Customer Management View

struct CustomerManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var parties: [TradingParty] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedType: PartyTypeFilter = .all
    @State private var selectedParty: TradingParty? = nil

    enum PartyTypeFilter: String, CaseIterable {
        case all = "Tất cả"
        case buyer = "Khách hàng"
        case supplier = "Cơ sở cung cấp"
        var dbType: String? {
            switch self {
            case .all: return nil
            case .buyer: return "buyer"
            case .supplier: return "supplier"
            }
        }
    }

    private var filtered: [TradingParty] {
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

    private var totalDebt: Double {
        filtered.reduce(0) { $0 + $1.totalDebt }
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

                // Debt summary
                if totalDebt > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Tổng công nợ: \(formatCurrency(totalDebt))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.06))
                }

                if isLoading {
                    VStack { ProgressView(); Spacer() }.padding()
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.4))
                        Text("Chưa có dữ liệu")
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(filtered) { party in
                            Button {
                                selectedParty = party
                            } label: {
                                PartyRowView(party: party)
                            }
                            .listRowBackground(Color.white)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Quản lý khách hàng")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Tìm tên, SĐT, địa chỉ...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task { await loadParties() }
            .sheet(item: $selectedParty) { party in
                PartyDetailView(party: party)
            }
        }
    }

    private func loadParties() async {
        isLoading = true
        defer { isLoading = false }
        async let buyers = (try? SupabaseDatabaseService().fetchTradingParties(type: "buyer")) ?? []
        async let suppliers = (try? SupabaseDatabaseService().fetchTradingParties(type: "supplier")) ?? []
        let (b, s) = await (buyers, suppliers)
        parties = b + s
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
