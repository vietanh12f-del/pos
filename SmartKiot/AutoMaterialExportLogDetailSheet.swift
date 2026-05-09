import SwiftUI

struct AutoMaterialExportLogDetailSheet: View {
    let log: AutoMaterialExportLog
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    sectionFresh
                    if log.data.subSheetLogs.isEmpty {
                        sectionPan
                        sectionAuto
                    } else {
                        ForEach(log.data.subSheetLogs) { slip in
                            subSheetBlock(slip)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("Chi tiết xuất tự động")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(log.data.headerName)
                .font(.headline)
            HStack(spacing: 6) {
                Text(log.templateName)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(formatDate(log.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                if let name = log.creatorName, !name.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var sectionFresh: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(log.data.freshTitle)
                .font(.headline)
            if log.data.fresh.isEmpty {
                Text("—").foregroundStyle(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(log.data.fresh) { r in
                        HStack {
                            Text(r.name)
                            Spacer()
                            Text(FormatUtils.formatWeight(Int(r.totalExportGrams.rounded())))
                                .fontWeight(.bold)
                                .foregroundStyle(Int(r.totalExportGrams.rounded()) > r.stockGrams ? .red : Color.themePrimary)
                        }
                        .font(.subheadline)
                    }
                }
            }
            HStack {
                Text(log.data.afterBoilTitle)
                Spacer()
                Text(FormatUtils.formatWeight(log.data.afterBoilGrams))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var sectionPan: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(log.data.panWeightTitle)
                .font(.headline)
            HStack {
                Text(log.data.panCountTitle)
                Spacer()
                Text("\(log.data.panCount)")
                    .fontWeight(.bold)
            }
            HStack {
                Text("Chuẩn")
                Spacer()
                Text(FormatUtils.formatWeight(log.data.standardPanWeightGrams))
                    .fontWeight(.bold)
            }
            HStack {
                Text("Thực tế")
                Spacer()
                Text(FormatUtils.formatWeight(Int(log.data.actualPanWeightGrams.rounded())))
                    .fontWeight(.bold)
            }
            HStack {
                Text("% thay đổi")
                Spacer()
                Text(String(format: "%.2f", log.data.percentChange))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var sectionAuto: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(log.data.autoMaterialsTitle)
                .font(.headline)
            if log.data.autoMaterials.isEmpty {
                Text("—").foregroundStyle(.gray)
            } else {
                autoRowsView(log.data.autoMaterials, extraRows: [])
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    @ViewBuilder
    private func subSheetBlock(_ slip: SubSheetLogData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header sub-sheet
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                Text(slip.name.isEmpty ? "Sub-sheet" : slip.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themePrimary)
            }
            Divider()
            // Thông số chảo
            HStack {
                Text("Sau luộc")
                    .foregroundStyle(.gray)
                Spacer()
                Text(FormatUtils.formatWeight(slip.afterBoilGrams))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            HStack {
                Text("Số chảo")
                    .foregroundStyle(.gray)
                Spacer()
                Text("\(slip.panCount) chảo")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            HStack {
                Text("KL thực tế/chảo")
                    .foregroundStyle(.gray)
                Spacer()
                Text(FormatUtils.formatWeight(Int(slip.actualPanWeightGrams.rounded())))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            if !slip.autoMaterials.isEmpty {
                Divider()
                Text(log.data.autoMaterialsTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                autoRowsView(slip.autoMaterials, extraRows: slip.extraPanRows)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }

    @ViewBuilder
    private func autoRowsView(_ rows: [AutoMaterialExportLogRow], extraRows: [AutoMaterialExportLogRow]) -> some View {
        VStack(spacing: 10) {
            ForEach(rows) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.name).fontWeight(.semibold)
                        Spacer()
                        Text("Kho: \(FormatUtils.formatWeight(r.stockGrams))")
                            .font(.caption).foregroundStyle(.gray)
                    }
                    HStack {
                        Text("Chuẩn/chảo").foregroundStyle(.gray)
                        Spacer()
                        Text(FormatUtils.formatWeight(Int((r.standardPerPanGrams ?? 0).rounded())))
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("/Chảo thực tế").foregroundStyle(.gray)
                        Spacer()
                        Text(FormatUtils.formatWeight(Int((r.actualPerPanGrams ?? 0).rounded())))
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Tổng xuất").foregroundStyle(.gray)
                        Spacer()
                        let total = Int(r.totalExportGrams.rounded())
                        Text(FormatUtils.formatWeight(total))
                            .fontWeight(.bold)
                            .foregroundStyle(total > r.stockGrams ? .red : Color.themePrimary)
                    }
                }
                .font(.subheadline)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
            }
            if !extraRows.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.orange).font(.caption)
                    Text("Xào thêm").font(.caption).fontWeight(.semibold).foregroundStyle(Color.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(extraRows) { r in
                    HStack {
                        Text(r.name).font(.subheadline).foregroundStyle(Color.orange)
                        Spacer()
                        Text(FormatUtils.formatWeight(Int(r.totalExportGrams.rounded())))
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}
