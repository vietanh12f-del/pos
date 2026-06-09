import SwiftUI
import Combine

// MARK: - Notification Item Model

struct AppNotificationItem: Identifiable, Codable {
    var id: UUID = UUID()
    let type: NotifType
    let title: String
    let body: String
    let createdAt: Date
    let action: NotifAction
    var isRead: Bool = false

    enum NotifType: String, Codable {
        case websiteLead, attendance, leaveRequest, newOrder, wholesaleOrder, debt, lowStockMaterial, expiryMaterial
        var icon: String {
            switch self {
            case .websiteLead:    return "globe"
            case .attendance:     return "clock.badge.checkmark.fill"
            case .leaveRequest:   return "calendar.badge.minus"
            case .newOrder:       return "cart.fill"
            case .wholesaleOrder: return "shippingbox.fill"
            case .debt:           return "exclamationmark.triangle.fill"
            case .lowStockMaterial: return "exclamationmark.circle.fill"
            case .expiryMaterial: return "clock.badge.exclamationmark.fill"
            }
        }
        var color: Color {
            switch self {
            case .websiteLead:    return .teal
            case .attendance:     return .green
            case .leaveRequest:   return .orange
            case .newOrder:       return Color.themePrimary
            case .wholesaleOrder: return .purple
            case .debt:           return .red
            case .lowStockMaterial: return .orange
            case .expiryMaterial: return .red
            }
        }
    }

    enum NotifAction: Codable {
        case selectTab(Int)
        case openCustomerManagement
        case openProductionManagement
        case openLeaveApproval
        case openOrderHistory
    }
}

// MARK: - Notification Service

@MainActor
class AppNotificationService: ObservableObject {
    static let shared = AppNotificationService()

    @Published var items: [AppNotificationItem] = []
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private weak var currentViewModel: OrderViewModel?

    // Key lưu UserDefaults theo ngày
    private var storageKey: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return "app_notifications_\(df.string(from: Date()))"
    }

    var unreadCount: Int { items.filter { !$0.isRead }.count }
    var hasUnread: Bool { unreadCount > 0 }
    var totalCount: Int { items.count }

    // MARK: - Setup realtime hooks

    /// Gọi 1 lần sau khi store được chọn
    func setup(viewModel: OrderViewModel) {
        currentViewModel = viewModel
        load()

        // Hook vào WebsiteLeadNotificationService — khi newLeadsCount thay đổi → refresh
        WebsiteLeadNotificationService.shared.$newLeadsCount
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let vm = self.currentViewModel else { return }
                Task { await self.refresh(viewModel: vm) }
            }
            .store(in: &cancellables)

        // Hook vào OrderViewModel.pastOrders — khi có đơn mới → refresh
        viewModel.$pastOrders
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let vm = self.currentViewModel else { return }
                Task { await self.refresh(viewModel: vm) }
            }
            .store(in: &cancellables)

        // Hook vào NotificationCenter cho các sự kiện nội bộ
        // (check-in, leave request mới, đơn sỉ mới)
        NotificationCenter.default.publisher(for: .appNotificationShouldRefresh)
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let vm = self.currentViewModel else { return }
                Task { await self.refresh(viewModel: vm) }
            }
            .store(in: &cancellables)
    }

    func teardown() {
        cancellables.removeAll()
        currentViewModel = nil
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        // Xóa key của 7 ngày trước
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for offset in 1...7 {
            if let old = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                UserDefaults.standard.removeObject(forKey: "app_notifications_\(df.string(from: old))")
            }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppNotificationItem].self, from: data)
        else { return }
        items = decoded
    }

    // MARK: - Mark all read

    func markAllRead() {
        for i in items.indices { items[i].isRead = true }
        save()
    }

    // MARK: - Refresh

    func refresh(viewModel: OrderViewModel) async {
        load() // giữ trạng thái isRead

        isLoading = true
        defer { isLoading = false }

        var fresh: [AppNotificationItem] = []
        let db = SupabaseDatabaseService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()

        // 1. Khách từ website (leads mới trong 24h)
        if let leads = try? await db.fetchWebsiteLeads() {
            let newLeads = leads.filter {
                $0.status == "new" && $0.createdAt >= Date().addingTimeInterval(-86400)
            }
            if !newLeads.isEmpty {
                fresh.append(AppNotificationItem(
                    type: .websiteLead,
                    title: "Khách từ website",
                    body: "\(newLeads.count) khách mới đăng ký trong 24h qua",
                    createdAt: newLeads.first?.createdAt ?? Date(),
                    action: .openCustomerManagement
                ))
            }
        }

        // 2. Điểm danh hôm nay
        if let userId = AuthManager.shared.currentUserProfile?.id,
           let att = try? await db.fetchTodayAttendance(userId: userId),
           att.checkInTime != nil {
            fresh.append(AppNotificationItem(
                type: .attendance,
                title: "Điểm danh hôm nay",
                body: att.checkOutTime != nil
                    ? "Check-in \(formatTime(att.checkInTime!)) – check-out \(formatTime(att.checkOutTime!))"
                    : "Đã check-in lúc \(formatTime(att.checkInTime!)), chưa check-out",
                createdAt: att.checkInTime ?? Date(),
                action: .selectTab(8)
            ))
        }

        // 3. Đơn xin nghỉ chờ duyệt
        if let leaves = try? await db.fetchAllLeaveRequests() {
            let pending = leaves.filter { $0.status == "pending" }
            if !pending.isEmpty {
                fresh.append(AppNotificationItem(
                    type: .leaveRequest,
                    title: "Đơn xin nghỉ chờ duyệt",
                    body: "\(pending.count) đơn cần duyệt",
                    createdAt: pending.first?.createdAt ?? Date(),
                    action: .openLeaveApproval
                ))
            }
        }

        // 4. Đơn bán lẻ hôm nay
        let todayOrders = viewModel.pastOrders.filter {
            $0.createdAt >= today && $0.createdAt <= todayEnd
        }
        if !todayOrders.isEmpty {
            let total = todayOrders.reduce(0) { $0 + $1.total }
            fresh.append(AppNotificationItem(
                type: .newOrder,
                title: "Đơn bán lẻ hôm nay",
                body: "\(todayOrders.count) đơn · \(formatCurrency(total))",
                createdAt: todayOrders.first?.createdAt ?? Date(),
                action: .selectTab(1)
            ))
        }

        // 5. Đơn bán sỉ + công nợ
        if let exportTx = try? await db.fetchProductionTransactions(mode: "Xuất Thành Phẩm") {
            let todayExport = exportTx.filter {
                $0.createdAt >= today && $0.createdAt <= todayEnd && ($0.grandTotal ?? 0) > 0
            }
            if !todayExport.isEmpty {
                let total = todayExport.reduce(0) { $0 + ($1.grandTotal ?? 0) }
                fresh.append(AppNotificationItem(
                    type: .wholesaleOrder,
                    title: "Đơn bán sỉ hôm nay",
                    body: "\(todayExport.count) phiếu · \(formatCurrency(total))",
                    createdAt: todayExport.first?.createdAt ?? Date(),
                    action: .openProductionManagement
                ))
            }

            let soon = Date().addingTimeInterval(3 * 86400)
            let overdue = exportTx.filter { tx in
                guard let debt = tx.debtAmount, debt > 0, let payDate = tx.expectedPayDate
                else { return false }
                return payDate < Date()
            }
            let dueSoon = exportTx.filter { tx in
                guard let debt = tx.debtAmount, debt > 0, let payDate = tx.expectedPayDate
                else { return false }
                return payDate >= Date() && payDate <= soon
            }
            if !overdue.isEmpty {
                let total = overdue.reduce(0) { $0 + ($1.debtAmount ?? 0) }
                fresh.append(AppNotificationItem(
                    type: .debt,
                    title: "Công nợ quá hạn",
                    body: "\(overdue.count) đơn · \(formatCurrency(total)) chưa thu",
                    createdAt: Date(),
                    action: .openProductionManagement
                ))
            } else if !dueSoon.isEmpty {
                let total = dueSoon.reduce(0) { $0 + ($1.debtAmount ?? 0) }
                fresh.append(AppNotificationItem(
                    type: .debt,
                    title: "Công nợ sắp hết hạn",
                    body: "\(dueSoon.count) đơn · \(formatCurrency(total)) trong 3 ngày tới",
                    createdAt: Date(),
                    action: .openProductionManagement
                ))
            }
        }
        
        // 6. Nguyên liệu sắp hết hoặc đã hết
        let lowStockMaterials = viewModel.materials.filter { mat in
            mat.stockQuantity == 0 || (mat.minStockAlertThreshold != nil && mat.stockQuantity <= mat.minStockAlertThreshold!)
        }
        if !lowStockMaterials.isEmpty {
            let names = lowStockMaterials.map { $0.name }.joined(separator: ", ")
            fresh.append(AppNotificationItem(
                type: .lowStockMaterial,
                title: "Nguyên liệu sắp hết",
                body: "\(lowStockMaterials.count) nguyên liệu cần nhập thêm: \(names)",
                createdAt: Date(),
                action: .openProductionManagement
            ))
        }
        
        // 7. Nguyên liệu sắp hết hạn hoặc đã hết hạn
        let now = Date()
        let calendar = Calendar.current
        let expiringMaterials = viewModel.materials.filter { mat in
            guard let expiryDate = mat.expiryDate, let alertDays = mat.expiryAlertDays else { return false }
            if let alertDate = calendar.date(byAdding: .day, value: -alertDays, to: expiryDate) {
                return now >= alertDate
            }
            return false
        }
        let expiredMaterials = viewModel.materials.filter { mat in
            guard let expiryDate = mat.expiryDate else { return false }
            return now >= expiryDate
        }
        
        if !expiredMaterials.isEmpty {
            let names = expiredMaterials.map { $0.name }.joined(separator: ", ")
            fresh.append(AppNotificationItem(
                type: .expiryMaterial,
                title: "Nguyên liệu đã hết hạn!",
                body: "\(expiredMaterials.count) nguyên liệu đã hết hạn: \(names)",
                createdAt: Date(),
                action: .openProductionManagement
            ))
        }
        
        if !expiringMaterials.isEmpty {
            let expiringSoon = expiringMaterials.filter { mat in
                guard let expiryDate = mat.expiryDate else { return false }
                return now < expiryDate
            }
            if !expiringSoon.isEmpty {
                let names = expiringSoon.map { $0.name }.joined(separator: ", ")
                fresh.append(AppNotificationItem(
                    type: .expiryMaterial,
                    title: "Nguyên liệu sắp hết hạn",
                    body: "\(expiringSoon.count) nguyên liệu sắp hết hạn: \(names)",
                    createdAt: Date(),
                    action: .openProductionManagement
                ))
            }
        }

        // Merge: giữ isRead của item cũ nếu cùng type+title
        let oldReadMap: [String: Bool] = Dictionary(
            uniqueKeysWithValues: items.map { ("\($0.type.rawValue)|\($0.title)", $0.isRead) }
        )
        items = fresh.sorted { $0.createdAt > $1.createdAt }.map { item in
            var m = item
            m.isRead = oldReadMap["\(item.type.rawValue)|\(item.title)"] ?? false
            return m
        }
        save()
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Notification Tile

struct NotificationTile: View {
    @ObservedObject var service: AppNotificationService
    let onTap: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(service.hasUnread ? Color.red.opacity(0.12) : Color.gray.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: service.hasUnread ? "bell.badge.fill" : "bell.fill")
                        .font(.title3)
                        .foregroundStyle(service.hasUnread ? .red : .gray)
                        .scaleEffect(service.hasUnread && pulse ? 1.15 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Thông báo quan trọng")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    if service.isLoading {
                        Text("Đang tải...")
                            .font(.caption).foregroundStyle(.gray)
                    } else if service.hasUnread {
                        Text("\(service.unreadCount) thông báo mới")
                            .font(.caption).foregroundStyle(.red).fontWeight(.semibold)
                    } else if service.totalCount > 0 {
                        Text("\(service.totalCount) thông báo hôm nay")
                            .font(.caption).foregroundStyle(.gray)
                    } else {
                        Text("Không có thông báo mới")
                            .font(.caption).foregroundStyle(.gray)
                    }
                }

                Spacer()

                if service.hasUnread {
                    Text("\(service.unreadCount)")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                } else if service.totalCount > 0 {
                    Text("\(service.totalCount)")
                        .font(.caption2).fontWeight(.bold).foregroundStyle(.gray)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                }

                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.gray.opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                service.hasUnread
                    ? Color.red.opacity(pulse ? 0.07 : 0.03)
                    : Color.white
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        service.hasUnread ? Color.red.opacity(0.25) : Color.gray.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear { startPulse() }
        .onChange(of: service.hasUnread) { has in
            if has { startPulse() } else { pulse = false }
        }
    }

    private func startPulse() {
        guard service.hasUnread else { return }
        pulse = false
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Notification Center Sheet

struct NotificationCenterSheet: View {
    @ObservedObject var service: AppNotificationService
    @Environment(\.dismiss) private var dismiss

    var onSelectTab: (Int) -> Void
    var onOpenCustomerManagement: () -> Void
    var onOpenProductionManagement: () -> Void
    var onOpenLeaveApproval: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    VStack { ProgressView(); Spacer() }.padding()
                } else if service.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 52)).foregroundStyle(.gray.opacity(0.3))
                        Text("Không có thông báo hôm nay")
                            .font(.headline).foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBackgroundLight)
                } else {
                    List {
                        ForEach(service.items) { item in
                            Button {
                                handleAction(item.action)
                                dismiss()
                            } label: {
                                NotificationRow(item: item)
                            }
                            .listRowBackground(item.isRead ? Color.white : Color.themePrimary.opacity(0.04))
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.themeBackgroundLight)
                }
            }
            .navigationTitle("Thông báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if service.totalCount > 0 {
                        Text("\(service.totalCount) mục")
                            .font(.caption).foregroundStyle(.gray)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Mark all read khi sheet mở
        .onAppear { service.markAllRead() }
    }

    private func handleAction(_ action: AppNotificationItem.NotifAction) {
        switch action {
        case .selectTab(let tag):       onSelectTab(tag)
        case .openCustomerManagement:   onOpenCustomerManagement()
        case .openProductionManagement: onOpenProductionManagement()
        case .openLeaveApproval:        onOpenLeaveApproval()
        case .openOrderHistory:         onSelectTab(1)
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let item: AppNotificationItem

    private func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "dd/MM"
        return f.string(from: date)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.type.color.opacity(item.isRead ? 0.08 : 0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(item.type.color.opacity(item.isRead ? 0.6 : 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(item.isRead ? .regular : .semibold)
                        .foregroundStyle(item.isRead ? .gray : Color.themeTextDark)
                    if !item.isRead {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                    }
                }
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(item.createdAt))
                    .font(.caption2).foregroundStyle(.gray)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notification.Name extension

extension Notification.Name {
    /// Post khi có sự kiện nội bộ cần refresh thông báo
    /// (check-in, leave request mới, đơn sỉ mới...)
    static let appNotificationShouldRefresh = Notification.Name("appNotificationShouldRefresh")
}
