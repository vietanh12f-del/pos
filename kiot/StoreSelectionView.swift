import SwiftUI

struct StoreSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showCreateStore = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Removed Tab Bar to enforce role selection from Login
                
                if storeManager.isLoading {
                    ProgressView()
                        .padding()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if authManager.selectedRole == "owner" {
                            // Owner View
                            Text("Cửa hàng hiện tại của bạn:")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ForEach(storeManager.myStores) { store in
                                StoreRow(store: store, isOwner: true) {
                                    Task {
                                        await storeManager.selectStore(store)
                                        dismiss()
                                    }
                                }
                            }
                            
                            Button(action: {
                                showCreateStore = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Thêm cửa hàng mới")
                                        .foregroundColor(.black)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .padding(.horizontal)
                            
                        } else {
                            // Employee View
                            Text("Đăng nhập Nhân viên của cửa hàng:")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            if storeManager.memberStores.isEmpty && storeManager.invitedStores.isEmpty && storeManager.myStores.isEmpty {
                                Text("Bạn chưa là nhân viên của cửa hàng nào.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                // Show Member Stores
                                ForEach(storeManager.memberStores) { store in
                                    StoreRow(store: store, isOwner: false) {
                                        Task {
                                            await storeManager.selectStore(store)
                                            dismiss()
                                        }
                                    }
                                }
                                
                                // Show Owned Stores (Simulation Mode)
                                if !storeManager.myStores.isEmpty {
                                    Text("Cửa hàng của bạn (Chế độ xem nhân viên):")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                        .padding(.top)
                                    
                                    ForEach(storeManager.myStores) { store in
                                        StoreRow(store: store, isOwner: false) {
                                            Task {
                                                await storeManager.selectStore(store)
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Invitations Section
                            if !storeManager.invitedStores.isEmpty {
                                Text("Lời mời làm nhân viên:")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                    .padding(.top)
                                
                                ForEach(storeManager.invitedStores) { store in
                                    InvitationRow(store: store)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle(authManager.selectedRole == "owner" ? "Chọn cửa hàng (Chủ)" : "Chọn cửa hàng (Nhân viên)")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreateStore) {
                CreateStoreView()
            }
        }
        .onAppear {
            Task {
                await storeManager.fetchStores()
            }
        }
    }
}

struct InvitationRow: View {
    let store: Store
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var isProcessing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(store.name)
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Đã mời bạn tham gia")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        processInvitation(accept: false)
                    }) {
                        Text("Từ chối")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        processInvitation(accept: true)
                    }) {
                        Text("Đồng ý")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func processInvitation(accept: Bool) {
        isProcessing = true
        Task {
            _ = await storeManager.respondToInvitation(storeId: store.id, accept: accept)
            isProcessing = false
        }
    }
}


struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : .green)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.green : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green, lineWidth: 1)
                )
        }
    }
}

struct StoreRow: View {
    let store: Store
    let isOwner: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundColor(.black)
                    if let address = store.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal)
    }
}
