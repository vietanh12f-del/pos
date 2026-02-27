import SwiftUI

struct CreateStoreView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager.shared
    @State private var storeName = ""
    @State private var storeAddress = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Label("Thông tin cửa hàng", systemImage: "storefront")) {
                    TextField("Tên cửa hàng", text: $storeName)
                        .foregroundColor(.primary)
                    
                    TextField("Địa chỉ (Tùy chọn)", text: $storeAddress)
                        .foregroundColor(.primary)
                }
                
                Section {
                    Button(action: createStore) {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Tạo cửa hàng")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(storeName.isEmpty || isCreating)
                    .listRowBackground(storeName.isEmpty ? Color.gray.opacity(0.1) : Color.blue)
                    .foregroundColor(storeName.isEmpty ? .gray : .white)
                }
            }
            .navigationTitle("Tạo cửa hàng mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
            }
            .alert(item: Binding<AlertError?>(
                get: { storeManager.errorMessage.map { AlertError(message: $0) } },
                set: { _ in storeManager.errorMessage = nil }
            )) { alertError in
                Alert(title: Text("Lỗi"), message: Text(alertError.message), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func createStore() {
        guard !storeName.isEmpty else { return }
        
        isCreating = true
        Task {
            let success = await storeManager.createStore(name: storeName, address: storeAddress.isEmpty ? nil : storeAddress)
            isCreating = false
            if success {
                dismiss()
            }
        }
    }
}

struct AlertError: Identifiable {
    let id = UUID()
    let message: String
}
