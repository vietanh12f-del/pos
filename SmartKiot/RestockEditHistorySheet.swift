import SwiftUI

struct RestockEditHistorySheet: View {
    @ObservedObject var viewModel: OrderViewModel
    let restockBillId: UUID
    @Environment(\.dismiss) private var dismiss
    
    @State private var edits: [RestockEdit] = []
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                } else if edits.isEmpty {
                    Text("Chưa có lịch sử chỉnh sửa")
                        .foregroundStyle(.gray)
                } else {
                    ForEach(edits) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(format(e.createdAt))
                                    .font(.subheadline)
                                Spacer()
                            }
                            Text("\(formatCurrency(e.oldTotal)) → \(formatCurrency(e.newTotal))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let name = e.editorName, !name.isEmpty {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            if let note = e.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.themeTextDark)
                            }
                            
                            if let details = e.details, !details.isEmpty {
                                ForEach(details, id: \.self) { line in
                                    Text("• \(line)")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Lịch sử chỉnh sửa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                isLoading = true
                do {
                    edits = try await viewModel.fetchRestockEdits(restockBillId: restockBillId)
                } catch {
                    edits = []
                }
                isLoading = false
            }
        }
    }
    
    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}
