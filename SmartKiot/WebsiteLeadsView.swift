import SwiftUI

struct WebsiteLeadsView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var leads: [WebsiteLead] = []
    @State private var isLoading = false
    @State private var selectedFilter: String = "all"
    @State private var selectedLead: WebsiteLead?
    @State private var showDetail = false
    @State private var searchText = ""

    init(viewModel: OrderViewModel) {
        self.viewModel = viewModel
    }

    private let db = SupabaseDatabaseService()

    private var filters: [(id: String, label: String)] = [
        ("all",          "Tất cả"),
        ("feedback",     "Góp ý"),
        ("consultation", "Tư vấn"),
        ("appointment",  "Đặt lịch"),
    ]

    private var filtered: [WebsiteLead] {
        leads.filter { lead in
            let matchType = selectedFilter == "all" || lead.leadType == selectedFilter
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchSearch = q.isEmpty
                || lead.fullName.lowercased().contains(q)
                || lead.phone.contains(q)
                || (lead.note?.lowercased().contains(q) ?? false)
            return matchType && matchSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.id) { f in
                            let count = f.id == "all" ? leads.count
                                : leads.filter { $0.leadType == f.id }.count
                            Button {
                                selectedFilter = f.id
                            } label: {
                                HStack(spacing: 4) {
                                    Text(f.label)
                                        .font(.subheadline)
                                        .fontWeight(selectedFilter == f.id ? .bold : .regular)
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(selectedFilter == f.id ? .white : Color.themePrimary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(selectedFilter == f.id
                                                    ? Color.white.opacity(0.3)
                                                    : Color.themePrimary.opacity(0.12))
                                            )
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedFilter == f.id
                                        ? Color.themePrimary
                                        : Color.white)
                                )
                                .foregroundStyle(selectedFilter == f.id ? .white : Color.themeTextDark)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color.white)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                    TextField("Tìm tên, SĐT, nội dung...", text: $searchText)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.gray.opacity(0.3))
                        Text("Chưa có tin nhắn nào")
                            .font(.headline).foregroundStyle(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { lead in
                            LeadRow(lead: lead)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedLead = lead
                                    showDetail = true
                                }
                                .listRowBackground(lead.status == "new"
                                    ? Color.themePrimary.opacity(0.04)
                                    : Color.white)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.themeBackgroundLight)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Hộp thư từ website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $selectedLead) { lead in
            LeadDetailSheet(lead: lead) { updatedLead in
                if let idx = leads.firstIndex(where: { $0.id == updatedLead.id }) {
                    leads[idx] = updatedLead
                }
                Task {
                    try? await db.updateWebsiteLeadStatus(
                        id: updatedLead.id,
                        status: updatedLead.status,
                        note: updatedLead.note
                    )
                    await WebsiteLeadNotificationService.shared.refreshNewLeadsCount()
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let rows = try? await db.fetchWebsiteLeads() {
            leads = rows
        }
        await WebsiteLeadNotificationService.shared.refreshNewLeadsCount()
    }
}

// MARK: - Lead Row

private struct LeadRow: View {
    let lead: WebsiteLead

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(lead.status == "new" ? 0.15 : 0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: typeIcon)
                    .font(.subheadline)
                    .foregroundStyle(typeColor.opacity(lead.status == "new" ? 1 : 0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(lead.fullName)
                        .font(.subheadline)
                        .fontWeight(lead.status == "new" ? .semibold : .regular)
                        .foregroundStyle(Color.themeTextDark)
                    if lead.status == "new" {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                    }
                    Spacer()
                    Text(lead.leadTypeLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(typeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(typeColor.opacity(0.1)))
                }

                Text(lead.phone)
                    .font(.caption)
                    .foregroundStyle(.gray)

                if let note = lead.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatRelative(lead.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.gray)
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var typeIcon: String {
        switch lead.leadType {
        case "feedback":    return "bubble.left.fill"
        case "appointment": return "calendar.badge.clock"
        default:            return "person.fill.questionmark"
        }
    }

    private var typeColor: Color {
        switch lead.leadType {
        case "feedback":    return .purple
        case "appointment": return .blue
        default:            return .teal
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch lead.status {
            case "contacted": return ("Đã liên hệ", .orange)
            case "done":      return ("Xong", .green)
            case "cancelled": return ("Huỷ", .gray)
            default:          return ("Mới", .red)
            }
        }()
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func formatRelative(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff/60))p" }
        if diff < 86400 { return "\(Int(diff/3600))h" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM"
        return f.string(from: date)
    }
}

// MARK: - Lead Detail Sheet

struct LeadDetailSheet: View {
    @State var lead: WebsiteLead
    let onUpdate: (WebsiteLead) -> Void
    @Environment(\.dismiss) private var dismiss

    private let statuses: [(id: String, label: String, color: Color)] = [
        ("new",       "Mới",        .red),
        ("contacted", "Đã liên hệ", .orange),
        ("done",      "Hoàn thành", .green),
        ("cancelled", "Đã huỷ",     .gray),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin") {
                    LabeledContent("Họ tên", value: lead.fullName)
                    LabeledContent("SĐT", value: lead.phone)
                    if let email = lead.email, !email.isEmpty {
                        LabeledContent("Email", value: email)
                    }
                    LabeledContent("Loại", value: lead.leadTypeLabel)
                    if let service = lead.serviceType, !service.isEmpty {
                        LabeledContent("Dịch vụ", value: service)
                    }
                    if let branch = lead.branch, !branch.isEmpty {
                        LabeledContent("Chi nhánh", value: branch)
                    }
                    if let slot = lead.timeSlot, !slot.isEmpty {
                        LabeledContent("Khung giờ", value: slot)
                    }
                    LabeledContent("Thời gian") {
                        Text(formatDateTime(lead.createdAt))
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }

                if let note = lead.note, !note.isEmpty {
                    Section("Nội dung / Ghi chú") {
                        Text(note)
                            .font(.subheadline)
                    }
                }

                Section("Trạng thái") {
                    ForEach(statuses, id: \.id) { s in
                        Button {
                            lead.status = s.id
                            onUpdate(lead)
                            dismiss()
                        } label: {
                            HStack {
                                Text(s.label)
                                    .foregroundStyle(s.color)
                                Spacer()
                                if lead.status == s.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(s.color)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chi tiết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm  dd/MM/yyyy"
        return f.string(from: date)
    }
}
