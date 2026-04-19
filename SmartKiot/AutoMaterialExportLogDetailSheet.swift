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
                    sectionPan
                    sectionAuto
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
            Text(log.templateName)
                .font(.subheadline)
                .foregroundStyle(.gray)
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
                VStack(spacing: 10) {
                    ForEach(log.data.autoMaterials) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(r.name)
                                Spacer()
                                Text("Kho: \(FormatUtils.formatWeight(r.stockGrams))")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            HStack {
                                Text("Chuẩn/chảo")
                                Spacer()
                                Text(FormatUtils.formatWeight(Int((r.standardPerPanGrams ?? 0).rounded())))
                                    .fontWeight(.bold)
                            }
                            HStack {
                                Text("/Chảo thực tế")
                                Spacer()
                                Text(FormatUtils.formatWeight(Int((r.actualPerPanGrams ?? 0).rounded())))
                                    .fontWeight(.bold)
                            }
                            HStack {
                                Text("Tổng xuất")
                                Spacer()
                                let total = Int(r.totalExportGrams.rounded())
                                Text(FormatUtils.formatWeight(total))
                                    .fontWeight(.bold)
                                    .foregroundStyle(total > r.stockGrams ? .red : Color.themePrimary)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.06)))
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
}
