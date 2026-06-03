import SwiftUI

struct ProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showMaterialExportReport = false
    @State private var showMaterialImportReport = false
    @State private var showFinishedImportReport = false
    @State private var showFinishedExportReport = false

    // MARK: - Material import stats
    @State private var materialImportTx: [ProductionTransaction] = []
    @State private var isLoadingStats = false
    
    // MARK: - Info popup for material import card
    @State private var showInfoPopup = false
    @State private var currentInfoTitle = ""
    @State private var currentInfoMessage = ""

    // MARK: - Material export stats
    @State private var materialExportTx: [ProductionTransaction] = []
    @State private var materialAutoExportLogs: [AutoMaterialExportLog] = []

    // MARK: - Finished import stats
    @State private var finishedImportTx: [ProductionTransaction] = []

    // MARK: - Finished export stats
    @State private var finishedExportTx: [ProductionTransaction] = []

    /// Tổng giá trị tồn kho nguyên liệu hiện tại (gram × giá/kg)
    private var totalMaterialStockValue: Double {
        viewModel.materials.reduce(0) { sum, m in
            let kg = Double(m.stockQuantity) / 1000.0
            return sum + kg * m.lastUnitPrice
        }
    }

    /// Tổng số nguyên liệu hiện tại (gram → kg)
    private var totalMaterialStockKg: Double {
        viewModel.materials.reduce(0) { $0 + Double($1.stockQuantity) } / 1000.0
    }

    /// Phiếu nhập NL trong kỳ đang chọn
    private var filteredImportTx: [ProductionTransaction] {
        let (start, end) = dateInterval(for: activeRange)
        return materialImportTx.filter { $0.createdAt >= start && $0.createdAt <= end }
    }

    private var importTxCount: Int { filteredImportTx.count }
    private var importTxTotal: Double { 
        filteredImportTx.reduce(0.0) { total, tx in
            let txCost = tx.items.reduce(0.0) { sum, item in
                let isCai = item.unit?.lowercased() == "cái"
                let itemCost = isCai
                    ? Double(item.quantity) * item.unitPrice
                    : Double(item.quantity) / 1000.0 * item.unitPrice
                return sum + itemCost
            }
            return total + txCost
        }
    }
    
    // Thống kê VAT cho nhập nguyên liệu
    private var importTxVatCount: Int { filteredImportTx.filter { ($0.vatAmount ?? 0) > 0 }.count }
    private var importTxTotalVAT: Double { filteredImportTx.reduce(0.0) { total, tx in total + (tx.vatAmount ?? 0) } }

    // MARK: - Export NL computed
    private var filteredExportTx: [ProductionTransaction] {
        let (start, end) = dateInterval(for: activeRange)
        return materialExportTx.filter { $0.createdAt >= start && $0.createdAt <= end }
    }

    private var autoExportIds: Set<UUID> {
        Set(materialAutoExportLogs.map { $0.productionTransactionId })
    }

    private var autoExportCount: Int {
        filteredExportTx.filter { autoExportIds.contains($0.id) }.count
    }

    private var manualExportCount: Int {
        filteredExportTx.filter { !autoExportIds.contains($0.id) }.count
    }

    private var totalExportValue: Double {
        filteredExportTx.reduce(0) { $0 + $1.totalCost }
    }

    // MARK: - Finished import computed
    private var filteredFinishedImportTx: [ProductionTransaction] {
        let (start, end) = dateInterval(for: activeRange)
        return finishedImportTx.filter { $0.createdAt >= start && $0.createdAt <= end }
    }

    private var finishedImportCount: Int { filteredFinishedImportTx.count }

    /// Tổng số thành phẩm (gram → kg) nhập trong kỳ
    private var finishedImportTotalKg: Double {
        filteredFinishedImportTx
            .flatMap { $0.items }
            .reduce(0) { $0 + Double($1.quantity) } / 1000.0
    }

    /// Tổng giá trị nhập thành phẩm trong kỳ
    private var finishedImportTotalValue: Double {
        filteredFinishedImportTx.reduce(0.0) { total, tx in
            let txCost = tx.items.reduce(0.0) { sum, item in
                let isCai = item.unit?.lowercased() == "cái"
                let itemCost = isCai
                    ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                    : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                return sum + itemCost
            }
            return total + txCost
        }
    }

    /// Số loại thành phẩm hiện có trong kho
    private var finishedGoodsCount: Int {
        viewModel.products.filter { $0.isFinishedGood }.count
    }

    // MARK: - Finished export computed
    private var filteredFinishedExportTx: [ProductionTransaction] {
        let (start, end) = dateInterval(for: activeRange)
        return finishedExportTx.filter { $0.createdAt >= start && $0.createdAt <= end }
    }

    private var finishedExportCount: Int { filteredFinishedExportTx.count }

    /// Thống kê VAT cho xuất thành phẩm
    private var finishedExportVatCount: Int { filteredFinishedExportTx.filter { ($0.vatAmount ?? 0) > 0 }.count }
    private var finishedExportTotalVAT: Double { filteredFinishedExportTx.reduce(0.0) { total, tx in total + (tx.vatAmount ?? 0) } }

    /// Doanh thu sỉ: tổng grandTotal của các phiếu xuất có grandTotal > 0
    private var finishedExportRevenue: Double {
        filteredFinishedExportTx.reduce(0) { $0 + ($1.grandTotal ?? 0) }
    }

    /// Tổng công nợ từ xuất thành phẩm
    private var finishedExportTotalDebt: Double {
        filteredFinishedExportTx.reduce(0) { $0 + ($1.debtAmount ?? 0) }
    }

    /// Tổng số thành phẩm hiện tại (tất cả loại)
    private var totalFinishedGoodStockCount: Int {
        viewModel.products.filter { $0.isFinishedGood }.reduce(0) { $0 + $1.stockQuantity }
    }

    /// Tổng giá trị tồn kho thành phẩm (stockQuantity(kg) × giá bán)
    private var totalFinishedGoodStockValue: Double {
        viewModel.products.filter { $0.isFinishedGood }.reduce(0) { $0 + Double($1.stockQuantity) / 1000.0 * $1.price }
    }

    private func dateInterval(for range: ReportDateRange) -> (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .today:
            return (cal.startOfDay(for: now),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .thisWeek:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? now)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now)
        case .custom(let s, let e):
            return (cal.startOfDay(for: s),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e)
        }
    }

    // MARK: - Date range
    enum QuickRange: String, CaseIterable {
        case today    = "Hôm nay"
        case thisWeek = "Tuần này"
        case thisMonth = "Tháng này"
        case custom   = "Tuỳ chọn"
    }

    @State private var quickRange: QuickRange = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    var activeRange: ReportDateRange {
        switch quickRange {
        case .today:     return .today
        case .thisWeek:  return .thisWeek
        case .thisMonth: return .thisMonth
        case .custom:    return .custom(start: customStart, end: customEnd)
        }
    }

    private var rangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM"
        switch quickRange {
        case .today:
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        case .thisWeek:
            let cal = Calendar.current
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            let start = cal.date(from: comps) ?? Date()
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? Date()
            return "\(df.string(from: start)) – \(df.string(from: end))"
        case .thisMonth:
            let f = DateFormatter()
            f.locale = Locale(identifier: "vi_VN")
            f.dateFormat = "MM/yyyy"
            return "Tháng \(f.string(from: Date()))"
        case .custom:
            return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
        }
    }

    // Cấu hình 4 card
    private struct CardConfig {
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let col2: String
        let col3: String
    }

    private let configs: [CardConfig] = [
        CardConfig(
            title: "Nhập nguyên liệu",
            subtitle: "Nguyên liệu đầu vào đã nhập kho",
            icon: "arrow.down.doc.fill",
            color: .green,
            col2: "Số phiếu nhập", col3: "Tổng chi phí"
        ),
        CardConfig(
            title: "Xuất nguyên liệu",
            subtitle: "Nguyên liệu đã dùng cho sản xuất",
            icon: "arrow.up.doc.fill",
            color: .purple,
            col2: "Số phiếu xuất", col3: "Tổng khối lượng"
        ),
        CardConfig(
            title: "Nhập thành phẩm",
            subtitle: "Thành phẩm nhập vào kho hàng hoá",
            icon: "tray.and.arrow.down.fill",
            color: .blue,
            col2: "Số phiếu nhập", col3: "Tổng sản phẩm"
        ),
        CardConfig(
            title: "Xuất thành phẩm",
            subtitle: "Xuất thành phẩm / bán sỉ",
            icon: "tray.and.arrow.up.fill",
            color: .orange,
            col2: "Số phiếu xuất", col3: "Doanh thu sỉ"
        ),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Chọn thời gian ───────────────────────────────────
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickRange.allCases, id: \.self) { r in
                                Button {
                                    quickRange = r
                                    if r == .custom { showCustomPicker = true }
                                } label: {
                                    Text(r.rawValue)
                                        .font(.caption)
                                        .fontWeight(quickRange == r ? .semibold : .regular)
                                        .foregroundStyle(quickRange == r ? .white : Color.themeTextDark)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(quickRange == r ? Color.themePrimary : Color.white)
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                quickRange == r ? Color.clear : Color.gray.opacity(0.2),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(Color.themePrimary)
                        Text(rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        if quickRange == .custom {
                            Button {
                                showCustomPicker = true
                            } label: {
                                Text("Đổi ngày")
                                    .font(.caption)
                                    .foregroundStyle(Color.themePrimary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(Color.white)

                Divider()

                // ── 4 Card ───────────────────────────────────────────
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(configs.indices, id: \.self) { i in
                            let cfg = configs[i]
                            Button {
                                switch i {
                                case 0: showMaterialImportReport = true
                                case 1: showMaterialExportReport = true
                                case 2: showFinishedImportReport = true
                                case 3: showFinishedExportReport = true
                                default: break
                                }
                            } label: {
                                if i == 0 {
                                    materialImportCard(cfg)
                                } else if i == 1 {
                                    materialExportCard(cfg)
                                } else if i == 2 {
                                    finishedImportCard(cfg)
                                } else {
                                    finishedExportCard(cfg)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .background(Color.themeBackgroundLight)
            }
            .navigationTitle("Báo cáo sản xuất")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                isLoadingStats = true
                async let txTask = viewModel.fetchProductionTransactions(mode: "Nhập Nguyên liệu")
                async let exportTask = viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
                async let logsTask = viewModel.fetchAutoMaterialExportLogs(limit: 2000)
                async let finishedImportTask = viewModel.fetchProductionTransactions(mode: "Nhập Thành Phẩm")
                async let finishedExportTask = viewModel.fetchProductionTransactions(mode: "Xuất Thành Phẩm")
                if viewModel.materials.isEmpty {
                    await viewModel.loadMaterials()
                }
                if viewModel.products.isEmpty {
                    await viewModel.loadProducts()
                }
                materialImportTx    = await txTask
                materialExportTx    = await exportTask
                materialAutoExportLogs = await logsTask
                finishedImportTx    = await finishedImportTask
                finishedExportTx    = await finishedExportTask
                isLoadingStats = false
            }
            .sheet(isPresented: $showCustomPicker) {
                NavigationStack {
                    Form {
                        Section(header: Text("Chọn khoảng thời gian")) {
                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Tuỳ chọn ngày")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") { showCustomPicker = false }
                                .fontWeight(.bold)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") {
                                quickRange = .thisMonth
                                showCustomPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showMaterialExportReport) {
            MaterialExportReportView(viewModel: viewModel)
        }
        .sheet(isPresented: $showMaterialImportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Nhập Nguyên liệu",
                title: "Nhập nguyên liệu",
                accentColor: .green,
                reportKind: .materialImport
            )
        }
        .sheet(isPresented: $showFinishedImportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Nhập Thành Phẩm",
                title: "Nhập thành phẩm",
                accentColor: .blue,
                reportKind: .finishedImport
            )
        }
        .sheet(isPresented: $showFinishedExportReport) {
            GenericProductionReportView(
                viewModel: viewModel,
                mode: "Xuất Thành Phẩm",
                title: "Xuất thành phẩm",
                accentColor: .orange,
                reportKind: .finishedExport
            )
        }
    }

    // MARK: - Card builder

    @ViewBuilder
    private func reportCard(_ cfg: CardConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cfg.color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: cfg.icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(cfg.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cfg.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text(cfg.subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Tóm tắt 3 cột — col1 hiển thị range đang chọn
            HStack(spacing: 0) {
                summaryCol(label: "Thời gian", value: rangeLabel)
                Divider().frame(height: 32)
                summaryCol(label: cfg.col2, value: "—")
                Divider().frame(height: 32)
                summaryCol(label: cfg.col3, value: "—")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cfg.color.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func summaryCol(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(value == "—" ? Color.gray.opacity(0.35) : Color.themeTextDark)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Material Export Card (số liệu thực)

    @ViewBuilder
    private func materialExportCard(_ cfg: CardConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cfg.color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: cfg.icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(cfg.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cfg.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text(cfg.subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                if isLoadingStats {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Hàng: 3 cột số liệu
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Xuất tự động")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : "\(autoExportCount) phiếu")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(autoExportCount > 0 ? cfg.color : Color.gray.opacity(0.35))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Xuất tay")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : "\(manualExportCount) phiếu")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(manualExportCount > 0 ? cfg.color : Color.gray.opacity(0.35))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Tổng giá trị")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : formatCurrency(totalExportValue))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(totalExportValue > 0 ? cfg.color : Color.gray.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cfg.color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Finished Import Card (số liệu thực)

    @ViewBuilder
    private func finishedImportCard(_ cfg: CardConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cfg.color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: cfg.icon)
                        .font(.title2).fontWeight(.semibold).foregroundStyle(cfg.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cfg.title)
                        .font(.headline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                    Text(cfg.subtitle)
                        .font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                if isLoadingStats {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline).foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Hàng 1: Tồn kho thành phẩm hiện tại
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Tồn kho hiện tại")
                        .font(.caption2).foregroundStyle(.gray)
                    Text("\(finishedGoodsCount) thành phẩm")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Giá trị tồn kho")
                        .font(.caption2).foregroundStyle(.gray)
                    let stockValue = viewModel.products
                        .filter { $0.isFinishedGood }
                        .reduce(0) { $0 + Double($1.stockQuantity) / 1000.0 * $1.price }
                    Text(formatCurrency(stockValue))
                        .font(.caption).fontWeight(.semibold).foregroundStyle(cfg.color)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 6)

            HStack { Spacer().frame(width: 16); Divider(); Spacer().frame(width: 16) }.frame(height: 1)

            // Hàng 2: Nhập trong kỳ
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Số phiếu nhập")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : "\(finishedImportCount) phiếu")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedImportCount > 0 ? cfg.color : Color.gray.opacity(0.35))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Tổng giá trị")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : formatCurrency(finishedImportTotalValue))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedImportTotalValue > 0 ? cfg.color : Color.gray.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cfg.color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Helper View for Stat Tile with Info Icon
    private struct StatTileWithInfo: View {
        let label: String
        let value: String
        let color: Color
        let infoTitle: String
        let infoMessage: String
        let onShowInfo: (String, String) -> Void
        
        var body: some View {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Button {
                        onShowInfo(infoTitle, infoMessage)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(value == "..." || value.contains("—") ? Color.gray.opacity(0.35) : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Material Import Card (số liệu thực)
    @ViewBuilder
    private func materialImportCard(_ cfg: CardConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cfg.color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: cfg.icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(cfg.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cfg.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.themeTextDark)
                    Text(cfg.subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                if isLoadingStats {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Hàng 1: Tồn kho hiện tại (không phụ thuộc range)
            HStack(spacing: 0) {
                StatTileWithInfo(
                    label: "Tồn kho hiện tại",
                    value: "\(viewModel.materials.count) nguyên liệu",
                    color: Color.themeTextDark,
                    infoTitle: "Tồn kho hiện tại",
                    infoMessage: "Số lượng loại nguyên liệu đang có trong kho của cửa hàng hiện tại.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
                
                Divider().frame(height: 32)
                
                StatTileWithInfo(
                    label: "Giá trị tồn kho",
                    value: formatCurrency(totalMaterialStockValue),
                    color: cfg.color,
                    infoTitle: "Giá trị tồn kho",
                    infoMessage: "Tổng giá trị của toàn bộ nguyên liệu trong kho, tính theo giá nhập cuối cùng của mỗi loại.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Divider mỏng giữa 2 hàng
            HStack {
                Spacer().frame(width: 16)
                Divider()
                Spacer().frame(width: 16)
            }
            .frame(height: 1)

            // Hàng 2: Nhập trong kỳ (theo range)
            HStack(spacing: 0) {
                StatTileWithInfo(
                    label: "Số phiếu nhập",
                    value: isLoadingStats ? "..." : "\(importTxCount) phiếu",
                    color: cfg.color,
                    infoTitle: "Số phiếu nhập",
                    infoMessage: "Tổng số phiếu nhập nguyên liệu trong khoảng thời gian đã chọn.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
                
                Divider().frame(height: 32)
                
                StatTileWithInfo(
                    label: "Tổng chi phí",
                    value: isLoadingStats ? "..." : formatCurrency(importTxTotal),
                    color: cfg.color,
                    infoTitle: "Tổng chi phí",
                    infoMessage: "Tổng số tiền đã chi để nhập nguyên liệu trong khoảng thời gian đã chọn.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 6)
            
            // Divider mỏng giữa hàng 2 và hàng 3
            HStack {
                Spacer().frame(width: 16)
                Divider()
                Spacer().frame(width: 16)
            }
            .frame(height: 1)

            // Hàng 3: Thống kê VAT
            HStack(spacing: 0) {
                StatTileWithInfo(
                    label: "Phiếu có VAT",
                    value: isLoadingStats ? "..." : "\(importTxVatCount) phiếu",
                    color: .blue,
                    infoTitle: "Phiếu có VAT",
                    infoMessage: "Số phiếu nhập nguyên liệu có tính thuế GTGT (VAT) trong khoảng thời gian đã chọn.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
                
                Divider().frame(height: 32)
                
                StatTileWithInfo(
                    label: "Giá trị VAT",
                    value: isLoadingStats ? "..." : formatCurrency(importTxTotalVAT),
                    color: .purple,
                    infoTitle: "Giá trị VAT",
                    infoMessage: "Tổng số tiền VAT trả thêm cho các phiếu nhập nguyên liệu có VAT trong khoảng thời gian đã chọn.",
                    onShowInfo: { title, message in
                        currentInfoTitle = title
                        currentInfoMessage = message
                        showInfoPopup = true
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cfg.color.opacity(0.15), lineWidth: 1)
        )
        .alert(currentInfoTitle, isPresented: $showInfoPopup) {
            Button("Đóng", role: .cancel) { }
        } message: {
            Text(currentInfoMessage)
        }
    }

    // MARK: - Finished Export Card (số liệu thực)

    @ViewBuilder
    private func finishedExportCard(_ cfg: CardConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cfg.color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: cfg.icon)
                        .font(.title2).fontWeight(.semibold).foregroundStyle(cfg.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cfg.title)
                        .font(.headline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                    Text(cfg.subtitle)
                        .font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                if isLoadingStats {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline).foregroundStyle(Color.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Hàng 1: Tồn kho thành phẩm hiện tại (không phụ thuộc range)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Số loại thành phẩm")
                        .font(.caption2).foregroundStyle(.gray)
                    Text("\(finishedGoodsCount) loại")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Công nợ")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(formatCurrency(finishedExportTotalDebt))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedExportTotalDebt > 0 ? .red : cfg.color)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 6)

            HStack { Spacer().frame(width: 16); Divider(); Spacer().frame(width: 16) }.frame(height: 1)

            // Hàng 2: Xuất trong kỳ
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Số phiếu xuất")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : "\(finishedExportCount) phiếu")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedExportCount > 0 ? cfg.color : Color.gray.opacity(0.35))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Doanh thu sỉ")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : formatCurrency(finishedExportRevenue))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedExportRevenue > 0 ? cfg.color : Color.gray.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 6)
            
            // Divider mỏng giữa hàng 2 và hàng 3
            HStack {
                Spacer().frame(width: 16)
                Divider()
                Spacer().frame(width: 16)
            }
            .frame(height: 1)

            // Hàng 3: Thống kê VAT
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Phiếu có VAT")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : "\(finishedExportVatCount) phiếu")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedExportVatCount > 0 ? .blue : Color.gray.opacity(0.35))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 4) {
                    Text("Giá trị VAT")
                        .font(.caption2).foregroundStyle(.gray)
                    Text(isLoadingStats ? "..." : formatCurrency(finishedExportTotalVAT))
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(finishedExportTotalVAT > 0 ? .purple : Color.gray.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cfg.color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Row Model

private struct ProductionReportRow {
    let log: AutoMaterialExportLog
    let freshTotalGrams: Int
    let afterBoilGrams: Int
    let yieldPercent: Double
    let finishedImportTx: ProductionTransaction?
    let materials: [MaterialItem]
    var transaction: ProductionTransaction? = nil  // transaction tương ứng để check isDeleted
    
    func finishedProductLossPercent(importGrams: Int) -> Double {
        guard freshTotalGrams > 0, importGrams > 0 else { return 0 }
        return (Double(importGrams) / Double(freshTotalGrams)) * 100
    }
    
    func getMaterialPrice(materialId: UUID?) -> Double {
        guard let id = materialId else { return 0 }
        return materials.first(where: { $0.id == id })?.lastUnitPrice ?? 0
    }
    
    var allMaterials: [AutoMaterialExportLogRow] {
        return log.data.fresh + log.data.autoMaterials
    }
    
    var totalMaterialCost: Double {
        allMaterials.reduce(0.0) { sum, material in
            let pricePerKg = getMaterialPrice(materialId: material.materialId)
            let weightKg = material.totalExportGrams / 1000.0
            return sum + (pricePerKg * weightKg)
        }
    }
}

// MARK: - Card View

private struct ProductionReportCard: View {
    let row: ProductionReportRow
    let selectedFinishedGoodName: String?
    let totalFinishedImportGramsInDay: Int
    let hasMultipleFinishedGoods: Bool
    let onSelectFinishedGood: () -> Void

    @State private var showMaterialDetails = false
    @State private var showDeleteInfo = false

    private var isDeleted: Bool { row.transaction?.isDeleted ?? false }

    private var lossPercent: Double {
        row.finishedProductLossPercent(importGrams: totalFinishedImportGramsInDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top) {
                Text(row.log.templateName)
                    .font(.headline)
                    .foregroundStyle(isDeleted ? Color.gray : Color.themeTextDark)
                Spacer()
                // Badge "Đã xoá"
                if isDeleted {
                    Button { showDeleteInfo = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill").font(.caption2)
                            Text("Đã xoá").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeleteInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thông tin xoá", systemImage: "trash.fill")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.red)
                            if let name = row.transaction?.deletedByName, !name.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Người xoá:").foregroundStyle(.gray)
                                    Text(name).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let at = row.transaction?.deletedAt {
                                HStack(spacing: 4) {
                                    Text("Thời gian:").foregroundStyle(.gray)
                                    Text(formatTime(at)).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let note = row.transaction?.deleteNote, !note.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Lý do:").foregroundStyle(.gray)
                                    Text(note).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(14).frame(width: 240)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }

            HStack(spacing: 6) {
                Text(formatTime(row.log.createdAt))
                    .font(.subheadline).foregroundStyle(.gray)
                if let name = row.log.creatorName, !name.isEmpty {
                    Text("•").font(.caption).foregroundStyle(.gray)
                    Text(name).font(.subheadline).foregroundStyle(.gray)
                }
            }

            Divider()

            // Stats grid
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Nguyên liệu tươi").foregroundStyle(.gray)
                    Spacer()
                    Text(FormatUtils.formatWeight(row.freshTotalGrams))
                        .fontWeight(.bold).foregroundStyle(isDeleted ? .gray : Color.themePrimary)
                }
                GridRow {
                    Text("Còn sau luộc").foregroundStyle(.gray)
                    Spacer()
                    Text(FormatUtils.formatWeight(row.afterBoilGrams))
                        .fontWeight(.bold).foregroundStyle(isDeleted ? .gray : Color.themePrimary)
                }
                GridRow {
                    Text("Tỉ lệ hao hụt").foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.2f%%", row.yieldPercent))
                        .fontWeight(.bold).foregroundStyle(isDeleted ? .gray : Color.themePrimary)
                }
                GridRow {
                    HStack(spacing: 6) {
                        Text("Nhập thành phẩm").foregroundStyle(.gray)
                        if hasMultipleFinishedGoods && !isDeleted {
                            Button { onSelectFinishedGood() } label: {
                                HStack(spacing: 2) {
                                    Text(selectedFinishedGoodName ?? "Tất cả")
                                        .font(.caption).foregroundStyle(Color.themePrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2).foregroundStyle(Color.themePrimary)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.themePrimary.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        } else if let name = selectedFinishedGoodName {
                            Text(name).font(.caption).foregroundStyle(.gray)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.gray.opacity(0.1)))
                        }
                    }
                    Spacer()
                    Text(totalFinishedImportGramsInDay > 0 ? FormatUtils.formatWeight(totalFinishedImportGramsInDay) : "—")
                        .fontWeight(.bold).foregroundStyle(isDeleted ? .gray : Color.themePrimary)
                }
                GridRow {
                    Text("Tỉ lệ hao hụt thành phẩm").foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.2f%%", lossPercent))
                        .fontWeight(.bold).foregroundStyle(isDeleted ? .gray : (lossPercent > 0 ? Color.green : Color.gray))
                }
            }
            .font(.subheadline)
            .opacity(isDeleted ? 0.5 : 1)

            if !isDeleted {
                Divider()
                Button { showMaterialDetails.toggle() } label: {
                    HStack {
                        Text("Chi tiết nguyên liệu xuất").font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Image(systemName: showMaterialDetails ? "chevron.up" : "chevron.down").font(.caption)
                    }
                    .foregroundStyle(Color.themePrimary)
                }
                .buttonStyle(.plain)
                if showMaterialDetails { materialDetailsSection }
            }
        }
        .padding(12)
        .background(isDeleted ? Color.gray.opacity(0.08) : Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isDeleted ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1))
        .shadow(color: isDeleted ? .clear : .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    // MARK: Material details

    private var materialDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !row.log.data.fresh.isEmpty {
                Text(row.log.data.freshTitle)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary).padding(.bottom, 4)
                ForEach(row.log.data.fresh) { material in materialRow(material) }
            }
            if !row.log.data.autoMaterials.isEmpty {
                if !row.log.data.fresh.isEmpty { Divider().padding(.vertical, 4) }
                Text(row.log.data.autoMaterialsTitle)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themePrimary).padding(.bottom, 4)
                ForEach(row.log.data.autoMaterials) { material in materialRow(material) }
            }
            Divider()
            HStack {
                Text("Tổng tiền nguyên liệu").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(row.totalMaterialCost)).font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themePrimary)
            }
        }
        .padding(.top, 4)
    }

    private func materialRow(_ material: AutoMaterialExportLogRow) -> some View {
        let pricePerKg = row.getMaterialPrice(materialId: material.materialId)
        let weightKg = material.totalExportGrams / 1000.0
        let totalCost = pricePerKg * weightKg
        return VStack(alignment: .leading, spacing: 4) {
            Text(material.name).font(.subheadline).fontWeight(.medium)
            HStack { Text("Khối lượng:").font(.caption).foregroundStyle(.gray); Text(FormatUtils.formatWeight(Int(material.totalExportGrams))).font(.caption).fontWeight(.semibold) }
            HStack { Text("Đơn giá:").font(.caption).foregroundStyle(.gray); Text(formatCurrency(pricePerKg) + "/kg").font(.caption).fontWeight(.semibold) }
            HStack { Text("Tổng tiền:").font(.caption).foregroundStyle(.gray); Text(formatCurrency(totalCost)).font(.caption).fontWeight(.semibold).foregroundStyle(Color.themePrimary) }
        }
        .padding(8).background(Color.gray.opacity(0.05)).cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Manual Export Card (same style as ProductionReportCard)

private struct ManualExportCard: View {
    let tx: ProductionTransaction
    let materials: [MaterialItem]

    @State private var showDetails = false
    @State private var showDeleteInfo = false

    private func getMaterialPrice(for name: String) -> Double {
        materials.first(where: { $0.name.lowercased() == name.lowercased() })?.lastUnitPrice ?? 0
    }

    private var totalCost: Double {
        tx.items.reduce(0.0) { sum, item in
            let pricePerKg = getMaterialPrice(for: item.name)
            let weightKg = Double(item.quantity) / 1000.0
            return sum + (pricePerKg * weightKg)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(alignment: .top) {
                Label("Xuất thủ công", systemImage: "hand.point.up.fill")
                    .font(.headline)
                    .foregroundStyle(tx.isDeleted ? Color.gray : Color.themeTextDark)
                Spacer()
                // Badge "Đã xoá"
                if tx.isDeleted {
                    Button {
                        showDeleteInfo = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill").font(.caption2)
                            Text("Đã xoá").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeleteInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thông tin xoá", systemImage: "trash.fill")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.red)
                            if let name = tx.deletedByName, !name.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Người xoá:").foregroundStyle(.gray)
                                    Text(name).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let at = tx.deletedAt {
                                HStack(spacing: 4) {
                                    Text("Thời gian:").foregroundStyle(.gray)
                                    Text(formatTime(at)).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let note = tx.deleteNote, !note.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Lý do:").foregroundStyle(.gray)
                                    Text(note).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(14).frame(width: 240)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }

            HStack(spacing: 6) {
                Text(formatTime(tx.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                if let name = tx.creatorName, !name.isEmpty {
                    Text("•").font(.caption).foregroundStyle(.gray)
                    Text(name).font(.subheadline).foregroundStyle(.gray)
                }
            }

            Divider()

            // Items summary
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(tx.items) { item in
                    GridRow {
                        Text(item.name)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(FormatUtils.formatWeight(item.quantity))
                            .fontWeight(.bold)
                            .foregroundStyle(tx.isDeleted ? Color.gray : Color.themePrimary)
                    }
                }
            }
            .font(.subheadline)
            .opacity(tx.isDeleted ? 0.5 : 1)

            if !tx.isDeleted {
                Divider()

                // Detail toggle
                Button {
                    showDetails.toggle()
                } label: {
                    HStack {
                        Text("Chi tiết nguyên liệu xuất")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.themePrimary)
                }
                .buttonStyle(.plain)

                if showDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tx.items) { item in
                            let pricePerKg = getMaterialPrice(for: item.name)
                            let weightKg = Double(item.quantity) / 1000.0
                            let itemCost = pricePerKg * weightKg

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack {
                                    Text("Khối lượng:").font(.caption).foregroundStyle(.gray)
                                    Text(FormatUtils.formatWeight(item.quantity)).font(.caption).fontWeight(.semibold)
                                }
                                HStack {
                                    Text("Đơn giá:").font(.caption).foregroundStyle(.gray)
                                    Text(formatCurrency(pricePerKg) + "/kg").font(.caption).fontWeight(.semibold)
                                }
                                HStack {
                                    Text("Tổng tiền:").font(.caption).foregroundStyle(.gray)
                                    Text(formatCurrency(itemCost)).font(.caption).fontWeight(.semibold).foregroundStyle(Color.themePrimary)
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }

                        Divider()

                        HStack {
                            Text("Tổng tiền nguyên liệu")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatCurrency(totalCost))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(tx.isDeleted ? Color.gray.opacity(0.08) : Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tx.isDeleted ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: tx.isDeleted ? .clear : .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Material Export Report View

struct MaterialExportReportView: View {
    @ObservedObject var viewModel: OrderViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - Quick range (giống GenericProductionReportView)
    enum QuickRange: String, CaseIterable {
        case today     = "Hôm nay"
        case thisWeek  = "Tuần này"
        case thisMonth = "Tháng này"
        case custom    = "Tuỳ chọn"
    }

    @State private var quickRange: QuickRange = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    // Giữ lại để tương thích với reload()
    @State private var selectedDate: Date = Date()
    @State private var isRangeMode: Bool = true
    @State private var rangeStart: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var rangeEnd: Date = Date()
    @State private var showDatePicker = false

    private var activeRangeInterval: (start: Date, end: Date) {
        let cal = Calendar.current; let now = Date()
        switch quickRange {
        case .today:
            return (cal.startOfDay(for: now), cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .thisWeek:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? now)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now)
        case .custom:
            return (cal.startOfDay(for: customStart), cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd)
        }
    }

    private var rangeLabel: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "vi_VN"); df.dateFormat = "dd/MM"
        switch quickRange {
        case .today:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        case .thisWeek:
            let (s, e) = activeRangeInterval
            return "\(df.string(from: s)) – \(df.string(from: e))"
        case .thisMonth:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "MM/yyyy"
            return "Tháng \(f.string(from: Date()))"
        case .custom:
            return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
        }
    }

    @State private var isLoading = false

    // Data (single day)
    @State private var autoLogs: [AutoMaterialExportLog] = []
    @State private var manualExports: [ProductionTransaction] = []
    @State private var materials: [MaterialItem] = []
    @State private var finishedImports: [ProductionTransaction] = []
    @State private var selectedFinishedGoodName: String? = nil
    @State private var showFinishedGoodPicker = false

    // Filters (like GenericProductionReportView)
    @State private var selectedVATFilter: VATFilter = .all
    @State private var selectedCreatorName: String? = nil
    @State private var showCreatorPicker = false

    // Print
    @State private var printImage: UIImage?
    @State private var showShareSheet = false

    // Data (range mode)
    @State private var rangeData: [String: DayReportData] = [:]
    @State private var expandedDays: Set<String> = []
    @State private var allExportTxs: [ProductionTransaction] = []

    struct DayReportData {
        let date: Date
        var autoLogs: [AutoMaterialExportLog]
        var manualExports: [ProductionTransaction]
        var finishedImports: [ProductionTransaction]
    }

    // MARK: - Computed

    private var allFinishedGoodNamesInDay: [String] {
        Array(Set(finishedImports.flatMap { $0.items.map { $0.name } })).sorted()
    }

    // Filter computed properties
    private var allCreatorNames: [String] {
        let allTxs = rangeData.values.flatMap { $0.manualExports }
        let names = allTxs.compactMap { $0.creatorName }
        return Array(Set(names)).sorted()
    }

    private var totalFinishedImportGramsInDay: Int {
        let allItems = finishedImports.flatMap { $0.items }
        if let name = selectedFinishedGoodName {
            return allItems.filter { $0.name == name }.reduce(0) { $0 + $1.quantity }
        }
        return allItems.reduce(0) { $0 + $1.quantity }
    }

    private var reportRows: [ProductionReportRow] {
        autoLogs.sorted { $0.createdAt > $1.createdAt }.map { log in
            let freshTotal = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
            let afterBoil = max(0, log.data.afterBoilGrams)
            let ratio: Double = freshTotal > 0 ? (Double(afterBoil) / Double(freshTotal) * 100) : 0
            let importTx = finishedImports.filter { $0.createdAt >= log.createdAt }.min(by: { $0.createdAt < $1.createdAt })
            let exportTx = allExportTxs.first(where: { $0.id == log.productionTransactionId })
            var row = ProductionReportRow(log: log, freshTotalGrams: freshTotal, afterBoilGrams: afterBoil,
                yieldPercent: ratio, finishedImportTx: importTx, materials: materials)
            row.transaction = exportTx
            return row
        }
    }

    private var sortedRangeDays: [DayReportData] {
        rangeData.values.sorted { $0.date > $1.date }
    }

    private var navTitle: String {
        isRangeMode ? "\(formatDateOnly(rangeStart)) – \(formatDateOnly(rangeEnd))" : "Xuất nguyên liệu \(formatDateOnly(selectedDate))"
    }

    private var dateButtonLabel: String {
        isRangeMode ? "\(formatDateOnly(rangeStart)) – \(formatDateOnly(rangeEnd))" : formatDateOnly(selectedDate)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Thanh chọn thời gian ─────────────────────────────
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickRange.allCases, id: \.self) { r in
                                Button {
                                    quickRange = r
                                    if r == .custom { showCustomPicker = true }
                                    else { Task { await reload() } }
                                } label: {
                                    Text(r.rawValue)
                                        .font(.caption)
                                        .fontWeight(quickRange == r ? .semibold : .regular)
                                        .foregroundStyle(quickRange == r ? .white : Color.themeTextDark)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(Capsule().fill(quickRange == r ? Color.purple : Color.white))
                                        .overlay(Capsule().stroke(quickRange == r ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.caption2).foregroundStyle(.purple)
                        Text(rangeLabel).font(.caption).foregroundStyle(.gray)
                        Spacer()
                        if quickRange == .custom {
                            Button { showCustomPicker = true } label: {
                                Text("Đổi ngày").font(.caption).foregroundStyle(.purple)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(Color.white)

                Divider()

                // ── Bộ lọc ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    // VAT Filter
                    HStack(spacing: 6) {
                        Text("VAT:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        ForEach(VATFilter.allCases, id: \.self) { option in
                            Button {
                                selectedVATFilter = option
                            } label: {
                                Text(option.rawValue)
                                    .font(.caption)
                                    .fontWeight(selectedVATFilter == option ? .semibold : .regular)
                                    .foregroundStyle(selectedVATFilter == option ? .white : Color.themeTextDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedVATFilter == option ? Color.purple : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Creator Filter
                    if !allCreatorNames.isEmpty {
                        HStack(spacing: 6) {
                            Text("Người tạo:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Button {
                                showCreatorPicker = true
                            } label: {
                                Text(selectedCreatorName ?? "Tất cả")
                                    .font(.caption)
                                    .fontWeight(selectedCreatorName != nil ? .semibold : .regular)
                                    .foregroundStyle(selectedCreatorName != nil ? .white : Color.themeTextDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedCreatorName != nil ? Color.purple : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            if selectedCreatorName != nil {
                                Button {
                                    selectedCreatorName = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                }
                .padding(12)
                .background(Color.white)

                Divider()

                // ── Nội dung ─────────────────────────────────────────
                Group {
                    if isLoading {
                        VStack { ProgressView(); Spacer() }.padding()
                    } else {
                        rangeContent
                    }
                }
                .background(Color.themeBackgroundLight)
            }
            .navigationTitle("Xuất nguyên liệu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        renderMaterialExportReport()
                    } label: {
                        Image(systemName: "printer")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = printImage {
                    ShareSheet(items: [image])
                }
            }
            .confirmationDialog("Chọn thành phẩm", isPresented: $showFinishedGoodPicker, titleVisibility: .visible) {
                if allFinishedGoodNamesInDay.isEmpty {
                    Button("Không có thành phẩm") { }
                } else {
                    ForEach(allFinishedGoodNamesInDay, id: \.self) { name in
                        Button(name) { selectedFinishedGoodName = name }
                    }
                }
                if selectedFinishedGoodName != nil {
                    Button("Tất cả thành phẩm", role: .destructive) { selectedFinishedGoodName = nil }
                }
                Button("Huỷ", role: .cancel) { }
            }
            .sheet(isPresented: $showCustomPicker) {
                NavigationStack {
                    Form {
                        Section(header: Text("Chọn khoảng thời gian")) {
                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Tuỳ chọn ngày")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") { showCustomPicker = false; Task { await reload() } }
                                .fontWeight(.bold)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") { quickRange = .thisMonth; showCustomPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("Chọn người tạo", isPresented: $showCreatorPicker, titleVisibility: .visible) {
                if allCreatorNames.isEmpty {
                    Button("Không có người tạo") { }
                } else {
                    ForEach(allCreatorNames, id: \.self) { name in
                        Button(name) { selectedCreatorName = name }
                    }
                }
                if selectedCreatorName != nil {
                    Button("Tất cả", role: .destructive) { selectedCreatorName = nil }
                }
                Button("Huỷ", role: .cancel) { }
            }
        }
        .task { await reload() }
    }

    // MARK: - Single day content

    private var singleDayContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                autoSection(logs: reportRows, finishedImports: finishedImports)
                Divider().padding(.horizontal)
                manualSection(exports: filteredExports(manualExports))
            }
        }
    }

    // MARK: - Range content

    private var rangeContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if sortedRangeDays.isEmpty {
                    Text("Không có dữ liệu trong khoảng ngày đã chọn")
                        .foregroundStyle(.gray).padding(40)
                } else {
                    ForEach(sortedRangeDays, id: \.date) { dayData in
                        let key = dayKey(dayData.date)
                        let isExpanded = expandedDays.contains(key)
                        let dayRows = makeRows(logs: dayData.autoLogs, finishedImports: dayData.finishedImports)

                        VStack(spacing: 0) {
                            Button {
                                if isExpanded { expandedDays.remove(key) }
                                else { expandedDays.insert(key) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption).foregroundStyle(.gray).frame(width: 16)
                                    Text(formatDateOnly(dayData.date))
                                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    if !dayData.autoLogs.isEmpty {
                                        Label("\(dayData.autoLogs.count)", systemImage: "wand.and.stars")
                                            .font(.caption).foregroundStyle(.purple)
                                    }
                                    if !dayData.manualExports.isEmpty {
                                        Label("\(dayData.manualExports.count)", systemImage: "hand.point.up.fill")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                    if dayData.autoLogs.isEmpty && dayData.manualExports.isEmpty {
                                        Text("Không có").font(.caption).foregroundStyle(.gray)
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 12).background(Color.white)
                            }
                            .buttonStyle(.plain)

                            if isExpanded {
                                VStack(spacing: 0) {
                                    autoSection(logs: dayRows, finishedImports: dayData.finishedImports)
                                    Divider().padding(.horizontal)
                                    manualSection(exports: filteredExports(dayData.manualExports))
                                }
                                .background(Color.themeBackgroundLight)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Reusable sections

    @ViewBuilder
    private func autoSection(logs: [ProductionReportRow], finishedImports: [ProductionTransaction]) -> some View {
        HStack {
            Label("Báo cáo xuất tự động", systemImage: "wand.and.stars")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.purple)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 6)

        if logs.isEmpty {
            Text("Không có dữ liệu xuất tự động")
                .font(.subheadline).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 10)
        } else {
            let allNames = Array(Set(finishedImports.flatMap { $0.items.map { $0.name } })).sorted()
            let totalGrams = finishedImports.flatMap { $0.items }.reduce(0) { $0 + $1.quantity }
            VStack(spacing: 12) {
                ForEach(logs, id: \.log.id) { row in
                    ProductionReportCard(
                        row: row,
                        selectedFinishedGoodName: selectedFinishedGoodName,
                        totalFinishedImportGramsInDay: totalGrams,
                        hasMultipleFinishedGoods: allNames.count > 1,
                        onSelectFinishedGood: { showFinishedGoodPicker = true }
                    )
                }
            }
            .padding(.horizontal).padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func manualSection(exports: [ProductionTransaction]) -> some View {
        HStack {
            Label("Báo cáo xuất thủ công", systemImage: "hand.point.up.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 6)

        if exports.isEmpty {
            Text("Không có")
                .font(.subheadline).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 12)
        } else {
            VStack(spacing: 12) {
                ForEach(exports.sorted { $0.createdAt > $1.createdAt }) { tx in
                    ManualExportCard(tx: tx, materials: materials)
                }
            }
            .padding(.horizontal).padding(.bottom, 12)
        }
    }

    // MARK: - Filter Logic

    private func filteredExports(_ exports: [ProductionTransaction]) -> [ProductionTransaction] {
        exports.filter { tx in
            // VAT filter
            let vatMatch: Bool
            switch selectedVATFilter {
            case .all:
                vatMatch = true
            case .withVAT:
                vatMatch = (tx.vatAmount ?? 0) > 0
            case .withoutVAT:
                vatMatch = (tx.vatAmount ?? 0) == 0
            }

            // Creator filter
            let creatorMatch: Bool
            if let selected = selectedCreatorName {
                creatorMatch = tx.creatorName == selected
            } else {
                creatorMatch = true
            }

            return vatMatch && creatorMatch && !tx.isDeleted
        }
    }

    // MARK: - Helpers

    private func makeRows(logs: [AutoMaterialExportLog], finishedImports: [ProductionTransaction]) -> [ProductionReportRow] {
        logs.sorted { $0.createdAt > $1.createdAt }.map { log in
            let freshTotal = log.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) }
            let afterBoil = max(0, log.data.afterBoilGrams)
            let ratio: Double = freshTotal > 0 ? (Double(afterBoil) / Double(freshTotal) * 100) : 0
            let importTx = finishedImports.filter { $0.createdAt >= log.createdAt }.min(by: { $0.createdAt < $1.createdAt })
            let exportTx = allExportTxs.first(where: { $0.id == log.productionTransactionId })
            var row = ProductionReportRow(log: log, freshTotalGrams: freshTotal, afterBoilGrams: afterBoil,
                yieldPercent: ratio, finishedImportTx: importTx, materials: materials)
            row.transaction = exportTx
            return row
        }
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        materials = await viewModel.fetchMaterials()
        await reloadRange()
    }

    private func reloadSingleDay() async {
        // Không dùng nữa — giữ lại để tránh lỗi compile
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let logs = await viewModel.fetchAutoMaterialExportLogs(limit: 500)
        autoLogs = logs.filter { $0.createdAt >= start && $0.createdAt < end }
        let imports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        finishedImports = imports.filter { $0.createdAt >= start && $0.createdAt < end }
        let allExports = await viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
        allExportTxs = allExports
        let autoIds = Set(autoLogs.map { $0.productionTransactionId })
        manualExports = allExports.filter { $0.createdAt >= start && $0.createdAt < end && !autoIds.contains($0.id) }
        selectedFinishedGoodName = nil
    }

    private func reloadRange() async {
        let (start, end) = activeRangeInterval
        let allLogs = await viewModel.fetchAutoMaterialExportLogs(limit: 2000)
        let allImports = await viewModel.fetchProductionTransactions(mode: "Nhập thành phẩm")
        let allExports = await viewModel.fetchProductionTransactions(mode: "Xuất nguyên liệu")
        allExportTxs = allExports  // lưu để makeRows dùng
        let allAutoIds = Set(allLogs.map { $0.productionTransactionId })
        var result: [String: DayReportData] = [:]
        var cursor = startOfDay(start)
        let endDay = startOfDay(end)
        while cursor <= endDay {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let key = dayKey(cursor)
            let dayLogs = allLogs.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd }
            let dayManual = allExports.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd && !allAutoIds.contains($0.id) }
            let dayImports = allImports.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd }
            if !dayLogs.isEmpty || !dayManual.isEmpty {
                result[key] = DayReportData(date: cursor, autoLogs: dayLogs, manualExports: dayManual, finishedImports: dayImports)
            }
            cursor = dayEnd
        }
        rangeData = result
        if let firstKey = result.keys.sorted().last { expandedDays = [firstKey] }
    }

    private func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    // MARK: - Print

    private func renderMaterialExportReport() {
        let allManualExports = rangeData.values.flatMap { filteredExports($0.manualExports) }
        let allAutoLogs = rangeData.values.flatMap { $0.autoLogs }
        let view = MaterialExportPrintView(
            rangeLabel: rangeLabel,
            vatFilter: selectedVATFilter.rawValue,
            creatorName: selectedCreatorName,
            autoLogs: allAutoLogs,
            manualExports: allManualExports,
            materials: materials
        )
        .frame(width: 400)
        .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Material Export Print View

private struct MaterialExportPrintView: View {
    let rangeLabel: String
    let vatFilter: String
    let creatorName: String?
    let autoLogs: [AutoMaterialExportLog]
    let manualExports: [ProductionTransaction]
    let materials: [MaterialItem]

    private var totalFreshGrams: Int {
        autoLogs.reduce(0) { $0 + $1.data.fresh.reduce(0) { $0 + Int(max(0, $1.totalExportGrams.rounded())) } }
    }

    private var totalAfterBoilGrams: Int {
        autoLogs.reduce(0) { $0 + max(0, $1.data.afterBoilGrams) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .center, spacing: 4) {
                Text("Báo cáo xuất nguyên liệu")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(rangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("In lúc: " + formatDateTime(Date()))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            // Filters
            VStack(alignment: .leading, spacing: 4) {
                Text("Bộ lọc:")
                    .font(.headline)
                    .fontWeight(.semibold)
                if vatFilter != "Tất cả" {
                    Text("• VAT: " + vatFilter)
                }
                if let name = creatorName {
                    Text("• Người tạo: " + name)
                }
            }
            .font(.caption)

            Divider()

            // Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Số phiếu tự động")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(String(autoLogs.count))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tổng tươi")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(FormatUtils.formatWeight(totalFreshGrams))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sau luộc")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(FormatUtils.formatWeight(totalAfterBoilGrams))
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }

            if !manualExports.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Xuất thủ công:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(String(manualExports.count) + " phiếu")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Binding var isRangeMode: Bool
    @Binding var selectedDate: Date
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Chọn khoảng ngày", isOn: $isRangeMode)
                        .tint(Color.themePrimary)
                }

                if isRangeMode {
                    Section(header: Text("Từ ngày")) {
                        DatePicker("", selection: $rangeStart, in: ...rangeEnd, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .onChange(of: rangeStart) { newVal in
                                if newVal > rangeEnd { rangeEnd = newVal }
                            }
                    }
                    Section(header: Text("Đến ngày")) {
                        DatePicker("", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    Section {
                        HStack {
                            Image(systemName: "info.circle").foregroundStyle(.gray)
                            Text("Khoảng \(daysBetween(rangeStart, rangeEnd) + 1) ngày")
                                .font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                } else {
                    Section(header: Text("Chọn ngày")) {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
            }
            .navigationTitle("Thời gian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { onDone() }.fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func daysBetween(_ from: Date, _ to: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}

// MARK: - Generic Production Report View
// Used for: Nhập nguyên liệu, Nhập thành phẩm, Xuất thành phẩm

enum ProductionReportKind {
    case materialImport   // Nhập nguyên liệu
    case finishedImport   // Nhập thành phẩm
    case finishedExport   // Xuất thành phẩm
}

private struct GenericTxCard: View {
    let tx: ProductionTransaction
    let reportKind: ProductionReportKind
    let accentColor: Color
    let isMaterial: Bool

    @State private var showDeleteInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(formatTime(tx.createdAt))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(tx.isDeleted ? .gray : Color.themeTextDark)
                        if let stt = tx.sequenceNumber {
                            Text("• \(stt)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        if let name = tx.creatorName, !name.isEmpty {
                            Text("•").font(.caption).foregroundStyle(.gray)
                            Text(name).font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                    if let note = tx.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.gray).lineLimit(1)
                    }
                }
                Spacer()
                // Badge "Đã xoá"
                if tx.isDeleted {
                    Button { showDeleteInfo = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill").font(.caption2)
                            Text("Đã xoá").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeleteInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thông tin xoá", systemImage: "trash.fill")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.red)
                            if let name = tx.deletedByName, !name.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Người xoá:").foregroundStyle(.gray)
                                    Text(name).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let at = tx.deletedAt {
                                HStack(spacing: 4) {
                                    Text("Thời gian:").foregroundStyle(.gray)
                                    Text(formatTime(at)).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                            if let note = tx.deleteNote, !note.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Lý do:").foregroundStyle(.gray)
                                    Text(note).fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(14).frame(width: 240)
                        .presentationCompactAdaptation(.popover)
                    }
                } else if reportKind == .finishedExport {
                    Text(tx.isPaid ? "Đã TT" : "Chưa TT")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(tx.isPaid ? .green : .orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(tx.isPaid ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)))
                }
            }

            Divider()

            // Items list
            VStack(spacing: 6) {
                ForEach(tx.items) { item in
                    HStack {
                        Text(item.name).font(.subheadline)
                            .foregroundStyle(tx.isDeleted ? .gray : Color.themeTextDark)
                        Spacer()
                        Text(FormatUtils.formatWeight(item.quantity, unit: item.unit))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(tx.isDeleted ? .gray : accentColor)
                        Text(formatCurrency(item.unitPrice) + (isMaterial ? (item.unit?.lowercased() == "cái" ? "/cái" : "/kg") : ""))
                            .font(.caption).foregroundStyle(.gray)
                    }
                }
            }
            .opacity(tx.isDeleted ? 0.5 : 1)

            if !tx.isDeleted {
                // Buyer info for finishedExport
                if reportKind == .finishedExport, let buyer = tx.buyerName, !buyer.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.fill").font(.caption).foregroundStyle(.gray)
                            Text(buyer).font(.subheadline).fontWeight(.semibold)
                            if let phone = tx.buyerPhone, !phone.isEmpty {
                                Text("•").font(.caption).foregroundStyle(.gray)
                                Text(phone).font(.caption).foregroundStyle(.gray)
                            }
                        }
                        if let addr = tx.buyerAddress, !addr.isEmpty {
                            Text(addr).font(.caption).foregroundStyle(.gray)
                        }
                    }
                }

                // Financial summary
                Divider()
                if reportKind == .finishedExport {
                    VStack(spacing: 4) {
                        if let vat = tx.vatAmount, vat > 0 {
                            HStack {
                                Text("VAT (\(Int(tx.vatRate ?? 0))%)").font(.caption).foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(vat)).font(.caption).fontWeight(.semibold)
                            }
                        }
                        HStack {
                            Text("Tổng cộng").font(.subheadline).fontWeight(.bold)
                            Spacer()
                            Text(formatCurrency(tx.grandTotal ?? tx.totalCost)).font(.subheadline).fontWeight(.bold).foregroundStyle(accentColor)
                        }
                        if let paid = tx.paidAmount {
                            HStack {
                                Text("Đã thanh toán").font(.caption).foregroundStyle(.gray)
                                Spacer()
                                Text(formatCurrency(paid)).font(.caption).fontWeight(.semibold).foregroundStyle(.green)
                            }
                        }
                        if let debt = tx.debtAmount, debt > 0 {
                            HStack {
                                Text("Còn nợ").font(.caption).foregroundStyle(.red)
                                Spacer()
                                Text(formatCurrency(debt)).font(.caption).fontWeight(.bold).foregroundStyle(.red)
                            }
                            if let payDate = tx.expectedPayDate {
                                HStack {
                                    Text("Dự kiến trả:").font(.caption).foregroundStyle(.gray)
                                    Spacer()
                                    Text(formatDateOnly(payDate)).font(.caption).fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } else {
                    finishedImportTotalCostRow(tx: tx)
                }
            }
        }
        .padding(12)
        .background(tx.isDeleted ? Color.gray.opacity(0.08) : Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tx.isDeleted ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1))
        .shadow(color: tx.isDeleted ? .clear : .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private func finishedImportTotalCostRow(tx: ProductionTransaction) -> some View {
        HStack {
            Text("Tổng chi phí").font(.subheadline).fontWeight(.bold)
            Spacer()
            let displayTotalCost = calculateFinishedImportTotalCost(tx: tx)
            Text(formatCurrency(displayTotalCost)).font(.subheadline).fontWeight(.bold).foregroundStyle(accentColor)
        }
    }

    private func calculateFinishedImportTotalCost(tx: ProductionTransaction) -> Double {
        guard reportKind == .finishedImport else { return tx.totalCost }
        return tx.items.reduce(0) { sum, item in
            let isCai = item.unit?.lowercased() == "cái"
            let itemCost = isCai
                ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
            return sum + itemCost
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Shared Enums

enum VATFilter: String, CaseIterable {
    case all = "Tất cả"
    case withVAT = "Có VAT"
    case withoutVAT = "Không VAT"
}

struct GenericProductionReportView: View {
    @ObservedObject var viewModel: OrderViewModel
    let mode: String
    let title: String
    let accentColor: Color
    let reportKind: ProductionReportKind

    @Environment(\.dismiss) private var dismiss

    // MARK: - Quick range (giống ProductionReportView)
    enum QuickRange: String, CaseIterable {
        case today     = "Hôm nay"
        case thisWeek  = "Tuần này"
        case thisMonth = "Tháng này"
        case custom    = "Tuỳ chọn"
    }

    @State private var quickRange: QuickRange = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    // Giữ lại để tương thích với reload()
    @State private var selectedDate: Date = Date()
    @State private var isRangeMode = true   // luôn range mode
    @State private var rangeStart: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var rangeEnd: Date = Date()

    @State private var isLoading = false
    @State private var transactions: [ProductionTransaction] = []
    @State private var materials: [MaterialItem] = []

    // Range mode
    @State private var rangeData: [String: [ProductionTransaction]] = [:]
    @State private var expandedDays: Set<String> = []

    // MARK: - Filters
    @State private var selectedVATFilter: VATFilter = .all
    @State private var selectedCreatorName: String? = nil
    @State private var selectedStoreName: String? = nil
    @State private var selectedFinishedGoodName: String? = nil
    @State private var selectedMaterialNames: Set<String> = []  // Changed to set for multi-selection
    @State private var showCreatorPicker = false
    @State private var showStorePicker = false
    @State private var showFinishedGoodPicker = false
    @State private var showMaterialPicker = false
    @State private var showTransactionDetail = false
    @State private var selectedTransaction: ProductionTransaction?
    @State private var printImage: UIImage?
    @State private var showShareSheet = false

    // MARK: - Active range

    private var activeRangeInterval: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch quickRange {
        case .today:
            return (cal.startOfDay(for: now),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .thisWeek:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? now)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now)
        case .custom:
            return (cal.startOfDay(for: customStart),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd)
        }
    }

    private var rangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM"
        switch quickRange {
        case .today:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        case .thisWeek:
            let (s, e) = activeRangeInterval
            return "\(df.string(from: s)) – \(df.string(from: e))"
        case .thisMonth:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "MM/yyyy"
            return "Tháng \(f.string(from: Date()))"
        case .custom:
            return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
        }
    }

    // MARK: - Computed

    private var navTitle: String { title }

    // Tất cả giao dịch đã load (tất cả ngày, chưa lọc)
    private var allLoadedTxs: [ProductionTransaction] {
        rangeData.values.flatMap { $0 }.filter { !$0.isDeleted }
    }

    // Danh sách tên người tạo (không trùng)
    private var allCreatorNames: [String] {
        Array(Set(allLoadedTxs.compactMap { $0.creatorName }.filter { !$0.isEmpty })).sorted()
    }

    // Danh sách tên cơ sở (nhập/xuất) - dùng supplierName cho nhập nguyên liệu
    private var allStoreNames: [String] {
        if reportKind == .materialImport {
            // For material import, use supplierName (nhà cung cấp/cơ sở nhập)
            return Array(Set(allLoadedTxs.compactMap { $0.supplierName }.filter { !$0.isEmpty })).sorted()
        } else {
            // For other reports, use creatorName (người tạo phiếu)
            return Array(Set(allLoadedTxs.compactMap { $0.creatorName }.filter { !$0.isEmpty })).sorted()
        }
    }
    
    // Danh sách tên thành phẩm (từ items của các transaction, lọc theo VAT)
    private var allFinishedGoodNames: [String] {
        let filteredTxsForNames: [ProductionTransaction]
        switch selectedVATFilter {
        case .all:
            filteredTxsForNames = allLoadedTxs
        case .withVAT:
            filteredTxsForNames = allLoadedTxs.filter { ($0.vatAmount ?? 0) > 0 }
        case .withoutVAT:
            filteredTxsForNames = allLoadedTxs.filter { ($0.vatAmount ?? 0) == 0 }
        }
        let names = filteredTxsForNames.flatMap { $0.items.map { $0.name } }
        return Array(Set(names)).sorted()
    }
    
    // Danh sách tên nguyên liệu (từ items của các transaction, lọc theo VAT)
    private var allMaterialNames: [String] {
        let filteredTxsForNames: [ProductionTransaction]
        switch selectedVATFilter {
        case .all:
            filteredTxsForNames = allLoadedTxs
        case .withVAT:
            filteredTxsForNames = allLoadedTxs.filter { ($0.vatAmount ?? 0) > 0 }
        case .withoutVAT:
            filteredTxsForNames = allLoadedTxs.filter { ($0.vatAmount ?? 0) == 0 }
        }
        let names = filteredTxsForNames.flatMap { $0.items.map { $0.name } }
        return Array(Set(names)).sorted()
    }

    // Lọc giao dịch theo các bộ lọc
    private func filteredTxs(_ txs: [ProductionTransaction]) -> [ProductionTransaction] {
        return txs.filter { tx in
            // Lọc VAT
            let vatMatch: Bool
            switch selectedVATFilter {
            case .all:
                vatMatch = true
            case .withVAT:
                vatMatch = (tx.vatAmount ?? 0) > 0
            case .withoutVAT:
                vatMatch = (tx.vatAmount ?? 0) == 0
            }

            // Lọc creator name
            let creatorMatch: Bool
            if let selected = selectedCreatorName {
                creatorMatch = tx.creatorName == selected
            } else {
                creatorMatch = true
            }

            // Lọc store name (cơ sở nhập/xuất)
            let storeMatch: Bool
            if let selected = selectedStoreName {
                if reportKind == .materialImport {
                    // For material import, match by supplierName only
                    storeMatch = tx.supplierName == selected
                } else {
                    // For other reports, match by creatorName
                    storeMatch = tx.creatorName == selected
                }
            } else {
                storeMatch = true
            }
            
            // Lọc thành phẩm
            let finishedGoodMatch: Bool
            if let selected = selectedFinishedGoodName {
                finishedGoodMatch = tx.items.contains(where: { $0.name == selected })
            } else {
                finishedGoodMatch = true
            }
            
            // Lọc nguyên liệu
            let materialMatch: Bool
            if !selectedMaterialNames.isEmpty {
                materialMatch = tx.items.contains(where: { selectedMaterialNames.contains($0.name) })
            } else {
                materialMatch = true
            }

            return vatMatch && creatorMatch && storeMatch && finishedGoodMatch && materialMatch && !tx.isDeleted
        }
    }

    private var sortedRangeDays: [(key: String, date: Date, txs: [ProductionTransaction])] {
        rangeData.map { key, txs in
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let date = f.date(from: key) ?? Date()
            let filtered = filteredTxs(txs)
            return (key, date, filtered)
        }.sorted { $0.date > $1.date }
    }

    private func stats(for txs: [ProductionTransaction]) -> (count: Int, totalCost: Double, totalQty: Int, totalRevenue: Double, totalDebt: Double, unpaidCount: Int) {
        let active = txs.filter { !$0.isDeleted }
        let count = active.count
        
        // Calculate totalCost: for materialImport with specific material selected,
        // only sum the cost of items matching that material
        // For finishedImport with specific finished good selected, only sum that finished good's cost
        let totalCost: Double
        if reportKind == .materialImport, !selectedMaterialNames.isEmpty {
            totalCost = active.reduce(0) { sum, tx in
                let matchingItemsCost = tx.items
                    .filter { selectedMaterialNames.contains($0.name) }
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                return sum + matchingItemsCost
            }
        } else if reportKind == .finishedImport, let selectedFG = selectedFinishedGoodName {
            totalCost = active.reduce(0) { sum, tx in
                let matchingItemsCost = tx.items
                    .filter { $0.name == selectedFG }
                    .reduce(0) { itemSum, item in
                        let isCai = item.unit?.lowercased() == "cái"
                        let itemCost = isCai 
                            ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                            : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                        return itemSum + itemCost
                    }
                return sum + matchingItemsCost
            }
        } else if reportKind == .finishedImport {
            // For finishedImport without filter, calculate correctly based on unit
            totalCost = active.reduce(0) { sum, tx in
                let txCost = tx.items.reduce(0) { itemSum, item in
                    let isCai = item.unit?.lowercased() == "cái"
                    let itemCost = isCai 
                        ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                        : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                    return itemSum + itemCost
                }
                return sum + txCost
            }
        } else {
            totalCost = active.reduce(0) { $0 + $1.totalCost }
        }
        
        // Calculate totalRevenue: for finishedExport with specific finished good selected,
        // calculate revenue proportionally based on matching items
        let totalRevenue: Double
        if reportKind == .finishedExport, let selectedFG = selectedFinishedGoodName {
            totalRevenue = active.reduce(0) { sum, tx in
                // Calculate proportion of selected finished good in this transaction
                let selectedTotal = tx.items
                    .filter { $0.name == selectedFG }
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                let allItemsTotal = tx.items
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                let proportion = allItemsTotal > 0 ? selectedTotal / allItemsTotal : 0
                return sum + (tx.grandTotal ?? 0) * proportion
            }
        } else {
            totalRevenue = active.compactMap { $0.grandTotal }.reduce(0, +)
        }
        
        let totalQty = active.flatMap { $0.items }.reduce(0) { $0 + $1.quantity }
        let totalDebt = active.compactMap { $0.debtAmount }.reduce(0, +)
        let unpaidCount = active.filter { !$0.isPaid }.count
        return (count, totalCost, totalQty, totalRevenue, totalDebt, unpaidCount)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Thanh chọn thời gian ─────────────────────────────
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickRange.allCases, id: \.self) { r in
                                Button {
                                    quickRange = r
                                    if r == .custom { showCustomPicker = true }
                                    else { Task { await reload() } }
                                } label: {
                                    Text(r.rawValue)
                                        .font(.caption)
                                        .fontWeight(quickRange == r ? .semibold : .regular)
                                        .foregroundStyle(quickRange == r ? .white : Color.themeTextDark)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(quickRange == r ? accentColor : Color.white)
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                quickRange == r ? Color.clear : Color.gray.opacity(0.2),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(accentColor)
                        Text(rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        if quickRange == .custom {
                            Button {
                                showCustomPicker = true
                            } label: {
                                Text("Đổi ngày")
                                    .font(.caption)
                                    .foregroundStyle(accentColor)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(Color.white)

                Divider()

                // ── Nội dung ─────────────────────────────────────────
                Group {
                    if isLoading {
                        VStack { ProgressView(); Spacer() }.padding()
                    } else {
                        rangeContent
                    }
                }
                .background(Color.themeBackgroundLight)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        renderFilteredReport()
                    } label: {
                        Image(systemName: "printer")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = printImage {
                    ShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showCustomPicker) {
                NavigationStack {
                    Form {
                        Section(header: Text("Chọn khoảng thời gian")) {
                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Tuỳ chọn ngày")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") {
                                showCustomPicker = false
                                Task { await reload() }
                            }
                            .fontWeight(.bold)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") {
                                quickRange = .thisMonth
                                showCustomPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .task { await reload() }
    }

    // MARK: - Single day

    private var singleDayContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if transactions.isEmpty {
                    emptyView
                } else {
                    summaryCard(txs: transactions)
                    ForEach(transactions.sorted { $0.createdAt > $1.createdAt }) { tx in
                        transactionCard(tx)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Range content

    private var rangeContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Filters section
                VStack(spacing: 8) {
                    Text("Bộ lọc")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // VAT Filter
                    HStack(spacing: 6) {
                        Text("VAT:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        ForEach(VATFilter.allCases, id: \.self) { option in
                            Button {
                                selectedVATFilter = option
                                if let selected = selectedFinishedGoodName {
                                    let newNames = allFinishedGoodNames
                                    if !newNames.contains(selected) {
                                        selectedFinishedGoodName = nil
                                    }
                                }
                                if !selectedMaterialNames.isEmpty {
                                    let newNames = Set(allMaterialNames)
                                    selectedMaterialNames.formIntersection(newNames)
                                }
                            } label: {
                                Text(option.rawValue)
                                    .font(.caption)
                                    .fontWeight(selectedVATFilter == option ? .semibold : .regular)
                                    .foregroundStyle(selectedVATFilter == option ? .white : Color.themeTextDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedVATFilter == option ? Color.themePrimary : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Creator Filter
                    HStack(spacing: 6) {
                        Text("Người tạo:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Button {
                            showCreatorPicker = true
                        } label: {
                            Text(selectedCreatorName ?? "Tất cả")
                                .font(.caption)
                                .fontWeight(selectedCreatorName != nil ? .semibold : .regular)
                                .foregroundStyle(selectedCreatorName != nil ? .white : Color.themeTextDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(selectedCreatorName != nil ? Color.themePrimary : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        if selectedCreatorName != nil {
                            Button {
                                selectedCreatorName = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .buttonStyle(.plain)
                        }

                        // Store Filter
                        Text(reportKind == .finishedExport ? "Cơ sở xuất:" : "Cơ sở nhập:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Button {
                            showStorePicker = true
                        } label: {
                            Text(selectedStoreName ?? "Tất cả")
                                .font(.caption)
                                .fontWeight(selectedStoreName != nil ? .semibold : .regular)
                                .foregroundStyle(selectedStoreName != nil ? .white : Color.themeTextDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(selectedStoreName != nil ? Color.themePrimary : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        if selectedStoreName != nil {
                            Button {
                                selectedStoreName = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    
                    // Material Filter (only for materialImport)
                    if reportKind == .materialImport {
                        HStack(spacing: 6) {
                            Text("Nguyên liệu:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Button {
                                showMaterialPicker = true
                            } label: {
                                Text(selectedMaterialNames.isEmpty ? "Tất cả" : "\(selectedMaterialNames.count) nguyên liệu")
                                    .font(.caption)
                                    .fontWeight(!selectedMaterialNames.isEmpty ? .semibold : .regular)
                                    .foregroundStyle(!selectedMaterialNames.isEmpty ? .white : Color.themeTextDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(!selectedMaterialNames.isEmpty ? accentColor : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            if !selectedMaterialNames.isEmpty {
                                Button {
                                    selectedMaterialNames.removeAll()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                    
                    // Finished Goods Filter (for finishedExport and finishedImport)
                    if reportKind == .finishedExport || reportKind == .finishedImport {
                        HStack(spacing: 6) {
                            Text("Thành phẩm:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Button {
                                showFinishedGoodPicker = true
                            } label: {
                                Text(selectedFinishedGoodName ?? "Tất cả")
                                    .font(.caption)
                                    .fontWeight(selectedFinishedGoodName != nil ? .semibold : .regular)
                                    .foregroundStyle(selectedFinishedGoodName != nil ? .white : Color.themeTextDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedFinishedGoodName != nil ? accentColor : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            if selectedFinishedGoodName != nil {
                                Button {
                                    selectedFinishedGoodName = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .padding(.horizontal)

                // Overall summary across all days
                if !rangeData.isEmpty {
                    let allTxs = filteredTxs(rangeData.values.flatMap { $0 })
                    if !allTxs.isEmpty {
                        summaryCard(txs: allTxs)
                            .padding(.horizontal)
                    }
                }

                if sortedRangeDays.allSatisfy({ $0.txs.isEmpty }) {
                    emptyView.padding(.horizontal)
                } else {
                    ForEach(sortedRangeDays, id: \.key) { item in
                        if !item.txs.isEmpty {
                            let isExpanded = expandedDays.contains(item.key)
                            VStack(spacing: 0) {
                                // Day header
                                Button {
                                    if isExpanded { expandedDays.remove(item.key) }
                                    else { expandedDays.insert(item.key) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption).foregroundStyle(.gray).frame(width: 16)
                                        Text(formatDateOnly(item.date))
                                            .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                                        Spacer()
                                        Text("\(item.txs.count) giao dịch")
                                            .font(.caption).foregroundStyle(accentColor)
                                        let s = stats(for: item.txs)
                                        let displayValue = reportKind == .finishedExport ? s.totalRevenue : s.totalCost
                                        Text("• \(formatCurrency(displayValue))")
                                            .font(.caption).foregroundStyle(.gray)
                                    }
                                    .padding(.horizontal).padding(.vertical, 12).background(Color.white)
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    VStack(spacing: 12) {
                                        ForEach(item.txs.sorted { $0.createdAt > $1.createdAt }) { tx in
                                            transactionCard(tx)
                                        }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Color.themeBackgroundLight)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .confirmationDialog("Chọn người tạo", isPresented: $showCreatorPicker, titleVisibility: .visible) {
            if allCreatorNames.isEmpty {
                Button("Không có người tạo") { }
            } else {
                ForEach(allCreatorNames, id: \.self) { name in
                    Button(name) { selectedCreatorName = name }
                }
            }
            if selectedCreatorName != nil {
                Button("Tất cả", role: .destructive) { selectedCreatorName = nil }
            }
            Button("Huỷ", role: .cancel) { }
        }
        .confirmationDialog(reportKind == .finishedExport ? "Chọn cơ sở xuất" : "Chọn cơ sở nhập", isPresented: $showStorePicker, titleVisibility: .visible) {
            if allStoreNames.isEmpty {
                Button("Không có dữ liệu") { }
            } else {
                ForEach(allStoreNames, id: \.self) { name in
                    Button(name) { selectedStoreName = name }
                }
            }
            if selectedStoreName != nil {
                Button("Tất cả", role: .destructive) { selectedStoreName = nil }
            }
            Button("Huỷ", role: .cancel) { }
        }
        .confirmationDialog("Chọn thành phẩm", isPresented: $showFinishedGoodPicker, titleVisibility: .visible) {
            if allFinishedGoodNames.isEmpty {
                Button("Không có thành phẩm") { }
            } else {
                ForEach(allFinishedGoodNames, id: \.self) { name in
                    Button(name) { selectedFinishedGoodName = name }
                }
            }
            if selectedFinishedGoodName != nil {
                Button("Tất cả", role: .destructive) { selectedFinishedGoodName = nil }
            }
            Button("Huỷ", role: .cancel) { }
        }
        .sheet(isPresented: $showMaterialPicker) {
            NavigationStack {
                List {
                    ForEach(allMaterialNames, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            if selectedMaterialNames.contains(name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMaterialNames.contains(name) {
                                selectedMaterialNames.remove(name)
                            } else {
                                selectedMaterialNames.insert(name)
                            }
                        }
                    }
                }
                .navigationTitle("Chọn nguyên liệu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") {
                            showMaterialPicker = false
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Xong") {
                            showMaterialPicker = false
                        }
                        .fontWeight(.bold)
                    }
                }
            }
        }
        .sheet(isPresented: $showTransactionDetail) {
            if let tx = selectedTransaction {
                NavigationStack {
                    ProductionBillDetailView(tx: tx, viewModel: viewModel)
                }
            }
        }
    }

    // MARK: - Summary card

    private func summaryCard(txs: [ProductionTransaction]) -> some View {
        let s = stats(for: txs)
        let currentStockValue = viewModel.products.filter { $0.isFinishedGood }.reduce(0.0) { $0 + Double($1.stockQuantity) / 1000.0 * $1.price }
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Tổng kết")
                .font(.headline).fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if isMaterial {
                    statTile(label: "Số phiếu nhập", value: "\(s.count)", icon: "doc.text.fill", color: accentColor)
                    statTile(label: "Tổng tiền nhập hàng", value: formatCurrency(s.totalCost), icon: "banknote.fill", color: .green)
                } else if reportKind == .finishedExport {
                    statTile(label: "Số phiếu xuất", value: "\(s.count)", icon: "doc.text.fill", color: accentColor)
                    statTile(label: "Giá trị xuất", value: formatCurrency(s.totalRevenue), icon: "arrow.up.circle.fill", color: accentColor)
                } else {
                    statTile(label: "Số phiếu nhập", value: "\(s.count)", icon: "doc.text.fill", color: accentColor)
                    statTile(label: "Tổng tiền nhập hàng", value: formatCurrency(s.totalCost), icon: "banknote.fill", color: .green)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    private func statTile(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.gray)
                Text(value).font(.subheadline).fontWeight(.bold)
            }
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Transaction card

    @State private var expandedTxIds: Set<UUID> = []
    @State private var deleteInfoTxId: UUID? = nil

    private func transactionCard(_ tx: ProductionTransaction) -> some View {
        Button {
            selectedTransaction = tx
            showTransactionDetail = true
        } label: {
            GenericTxCard(
                tx: tx,
                reportKind: reportKind,
                accentColor: accentColor,
                isMaterial: isMaterial
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
            Text("Không có dữ liệu").foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity).padding(40)
    }

    private var isMaterial: Bool { reportKind == .materialImport }

    // MARK: - Print

    private func renderFilteredReport() {
        let allTxs = filteredTxs(rangeData.values.flatMap { $0 })
        let view = FilteredTransactionsPrintView(
            title: title,
            rangeLabel: rangeLabel,
            vatFilter: selectedVATFilter.rawValue,
            creatorName: selectedCreatorName,
            storeName: selectedStoreName,
            materialNames: selectedMaterialNames,
            finishedGoodName: selectedFinishedGoodName,
            txs: allTxs,
            isMaterial: isMaterial,
            reportKind: reportKind
        )
        .frame(width: 400)
        .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            printImage = image
            showShareSheet = true
        }
    }

    // MARK: - Data loading

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        materials = await viewModel.fetchMaterials()
        if reportKind == .finishedExport && viewModel.products.isEmpty {
            await viewModel.loadProducts()
        }
        await reloadRange()
    }

    private func reloadSingleDay() async {
        // Không dùng nữa — giữ lại để tránh lỗi compile nếu có reference
        let start = startOfDay(selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let all = await viewModel.fetchProductionTransactions(mode: mode)
        transactions = all.filter { $0.createdAt >= start && $0.createdAt < end }
    }

    private func reloadRange() async {
        let (start, end) = activeRangeInterval
        let all = await viewModel.fetchProductionTransactions(mode: mode)
        let filtered = all.filter { $0.createdAt >= start && $0.createdAt <= end }
        var result: [String: [ProductionTransaction]] = [:]
        var cursor = startOfDay(start)
        let endDay = startOfDay(end)
        while cursor <= endDay {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            let key = dayKey(cursor)
            let dayTxs = filtered.filter { $0.createdAt >= cursor && $0.createdAt < dayEnd }
            if !dayTxs.isEmpty { result[key] = dayTxs }
            cursor = dayEnd
        }
        rangeData = result
        if let firstKey = result.keys.sorted().last { expandedDays = [firstKey] }
    }

    // MARK: - Helpers

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Filtered Report Print View

private struct FilteredTransactionsPrintView: View {
    let title: String
    let rangeLabel: String
    let vatFilter: String
    let creatorName: String?
    let storeName: String?
    let materialNames: Set<String>  // Changed to set for multi-selection
    let finishedGoodName: String?
    let txs: [ProductionTransaction]
    let isMaterial: Bool
    let reportKind: ProductionReportKind

    private var totalCost: Double {
        let active = txs.filter { !$0.isDeleted }
        // For materialImport with specific material selected, only sum matching items
        if reportKind == .materialImport, !materialNames.isEmpty {
            return active.reduce(0) { sum, tx in
                let matchingItemsCost = tx.items
                    .filter { materialNames.contains($0.name) }
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                return sum + matchingItemsCost
            }
        }
        // For finishedImport with specific finished good selected, only sum matching items
        if reportKind == .finishedImport, let selectedFG = finishedGoodName {
            return active.reduce(0) { sum, tx in
                let matchingItemsCost = tx.items
                    .filter { $0.name == selectedFG }
                    .reduce(0) { itemSum, item in
                        let isCai = item.unit?.lowercased() == "cái"
                        let itemCost = isCai 
                            ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                            : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                        return itemSum + itemCost
                    }
                return sum + matchingItemsCost
            }
        }
        // For finishedImport without filter, calculate correctly based on unit
        if reportKind == .finishedImport {
            return active.reduce(0) { sum, tx in
                let txCost = tx.items.reduce(0) { itemSum, item in
                    let isCai = item.unit?.lowercased() == "cái"
                    let itemCost = isCai 
                        ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                        : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                    return itemSum + itemCost
                }
                return sum + txCost
            }
        }
        return active.reduce(0) { $0 + $1.totalCost }
    }
    private var totalQty: Int {
        let active = txs.filter { !$0.isDeleted }
        // For materialImport with specific material selected, only count matching items
        if reportKind == .materialImport, !materialNames.isEmpty {
            return active.flatMap { $0.items }
                .filter { materialNames.contains($0.name) }
                .reduce(0) { $0 + $1.quantity }
        }
        // For finishedExport with specific finished good selected, only count matching items
        if reportKind == .finishedExport, let selectedFG = finishedGoodName {
            return active.flatMap { $0.items }
                .filter { $0.name == selectedFG }
                .reduce(0) { $0 + $1.quantity }
        }
        // For finishedImport with specific finished good selected, only count matching items
        if reportKind == .finishedImport, let selectedFG = finishedGoodName {
            return active.flatMap { $0.items }
                .filter { $0.name == selectedFG }
                .reduce(0) { $0 + $1.quantity }
        }
        return active.flatMap { $0.items }.reduce(0) { $0 + $1.quantity }
    }
    private var filteredTotalRevenue: Double {
        let active = txs.filter { !$0.isDeleted }
        // For finishedExport with specific finished good selected, calculate revenue proportionally
        if reportKind == .finishedExport, let selectedFG = finishedGoodName {
            return active.reduce(0) { sum, tx in
                let selectedTotal = tx.items
                    .filter { $0.name == selectedFG }
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                let allItemsTotal = tx.items
                    .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
                let proportion = allItemsTotal > 0 ? selectedTotal / allItemsTotal : 0
                return sum + (tx.grandTotal ?? 0) * proportion
            }
        }
        return active.compactMap { $0.grandTotal }.reduce(0, +)
    }
    private var totalRevenue: Double {
        txs.filter { !$0.isDeleted }.compactMap { $0.grandTotal }.reduce(0, +)
    }
    private var totalDebt: Double {
        txs.filter { !$0.isDeleted }.compactMap { $0.debtAmount }.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(rangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("In lúc: \(formatDateTime(Date()))")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            // Filters
            VStack(alignment: .leading, spacing: 4) {
                Text("Bộ lọc:")
                    .font(.headline)
                    .fontWeight(.semibold)
                if vatFilter != "Tất cả" {
                    Text("• VAT: \(vatFilter)")
                }
                if let name = creatorName {
                    Text("• Người tạo: \(name)")
                }
                if let name = storeName {
                    Text("• Cơ sở: \(name)")
                }
                if !materialNames.isEmpty {
                    let materialList = materialNames.sorted().joined(separator: ", ")
                    Text("• Nguyên liệu: \(materialList)")
                }
                if let name = finishedGoodName {
                    Text("• Thành phẩm: \(name)")
                }
            }
            .font(.caption)

            Divider()

            // Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Số phiếu")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text("\(txs.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                if reportKind == .finishedExport {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Tổng doanh thu")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(formatCurrency(filteredTotalRevenue))
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    if totalDebt > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Còn nợ")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text(formatCurrency(totalDebt))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(reportKind == .finishedExport ? "Giá trị xuất" : "Tổng tiền")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        let revenueToShow = reportKind == .finishedExport ? filteredTotalRevenue : totalCost
                        Text(formatCurrency(revenueToShow))
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
            }

            Divider()

            // Transactions
            VStack(alignment: .leading, spacing: 12) {
                ForEach(txs.sorted { $0.createdAt > $1.createdAt }) { tx in
                    FilteredTransactionPrintRow(tx: tx, materialNames: materialNames, finishedGoodName: finishedGoodName, reportKind: reportKind)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "VND"
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: NSNumber(value: value)) ?? "\(value) đ"
    }
}

private struct FilteredTransactionPrintRow: View {
    let tx: ProductionTransaction
    let materialNames: Set<String>
    let finishedGoodName: String?
    let reportKind: ProductionReportKind

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            buyerText
            itemsList
            totalRow
            vatRow
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private var header: some View {
        HStack {
            Text(formatDateTime(tx.createdAt))
                .font(.caption)
                .fontWeight(.semibold)
            if let stt = tx.sequenceNumber {
                Text("• \(stt)")
                    .font(.caption)
            }
            Spacer()
            if tx.isDeleted {
                Text("ĐÃ XOÁ")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var buyerText: some View {
        if let buyer = tx.buyerName, !buyer.isEmpty {
            Text("Khách: " + buyer)
                .font(.caption)
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(filteredItems) { item in
                FilteredTransactionItemPrintRow(item: item)
            }
        }
    }
    
    private var filteredItems: [RestockItem] {
        if reportKind == .materialImport, !materialNames.isEmpty {
            return tx.items.filter { materialNames.contains($0.name) }
        }
        if reportKind == .finishedExport, let selectedFG = finishedGoodName {
            return tx.items.filter { $0.name == selectedFG }
        }
        if reportKind == .finishedImport, let selectedFG = finishedGoodName {
            return tx.items.filter { $0.name == selectedFG }
        }
        return tx.items
    }

    private var totalRow: some View {
        HStack {
            Spacer()
            Text("Tổng: " + formatCurrency(rowTotal))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
    
    private var rowTotal: Double {
        if reportKind == .materialImport, !materialNames.isEmpty {
            return tx.items
                .filter { materialNames.contains($0.name) }
                .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
        }
        if reportKind == .finishedExport, let selectedFG = finishedGoodName {
            // Calculate proportion of selected finished good in this transaction
            let selectedTotal = tx.items
                .filter { $0.name == selectedFG }
                .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
            let allItemsTotal = tx.items
                .reduce(0) { $0 + (Double($1.quantity) / 1000.0 * $1.unitPrice) }
            let proportion = allItemsTotal > 0 ? selectedTotal / allItemsTotal : 0
            return (tx.grandTotal ?? 0) * proportion
        }
        if reportKind == .finishedImport, let selectedFG = finishedGoodName {
            // Only calculate cost of selected finished good
            return tx.items
                .filter { $0.name == selectedFG }
                .reduce(0) { sum, item in
                    let isCai = item.unit?.lowercased() == "cái"
                    let itemCost = isCai 
                        ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                        : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                    return sum + itemCost
                }
        }
        // For finishedImport without filter, calculate based on unit
        if reportKind == .finishedImport {
            return tx.items.reduce(0) { sum, item in
                let isCai = item.unit?.lowercased() == "cái"
                let itemCost = isCai 
                    ? Double(item.quantity) * (item.suggestedPrice ?? item.unitPrice)
                    : Double(item.quantity) / 1000.0 * (item.suggestedPrice ?? item.unitPrice)
                return sum + itemCost
            }
        }
        return tx.totalCost
    }

    @ViewBuilder
    private var vatRow: some View {
        if let vat = tx.vatAmount, vat > 0 {
            HStack {
                Spacer()
                Text("VAT: " + formatCurrency(vat))
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "VND"
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: NSNumber(value: value)) ?? "\(value) đ"
    }
}

private struct FilteredTransactionItemPrintRow: View {
    let item: RestockItem

    var body: some View {
        HStack {
            Text(item.name)
                .font(.caption)
            Spacer()
            Text(itemLine)
                .font(.caption)
        }
    }

    private var itemLine: String {
        let weightStr = FormatUtils.formatWeight(item.quantity, unit: item.unit)
        let priceStr = formatCurrency(item.unitPrice)
        return weightStr + " x " + priceStr
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "VND"
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: NSNumber(value: value)) ?? "\(value) đ"
    }
}
