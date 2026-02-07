import SwiftUI

struct StoreSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showCreateStore = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if storeManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text(authManager.selectedRole == "owner" ? "Quản lý Cửa hàng" : "Cửa hàng làm việc")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(authManager.selectedRole == "owner" ? "Chọn cửa hàng để quản lý hoặc tạo mới" : "Chọn cửa hàng để bắt đầu ca làm việc")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            if authManager.selectedRole == "owner" {
                                // Owner View
                                if storeManager.myStores.isEmpty {
                                    VStack(spacing: 24) {
                                        EmptyStoreStateView(message: "Bạn chưa có cửa hàng nào.\nHãy tạo cửa hàng đầu tiên ngay!")
                                        
                                        Button(action: {
                                            showCreateStore = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Tạo cửa hàng mới")
                                            }
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.green)
                                            .cornerRadius(12)
                                            .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                                        }
                                        .padding(.horizontal, 40)
                                    }
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                                        ForEach(storeManager.myStores) { store in
                                            StoreCardView(store: store, isOwner: true) {
                                                Task {
                                                    await storeManager.selectStore(store)
                                                    dismiss()
                                                }
                                            } onDelete: {
                                                Task {
                                                    _ = await storeManager.deleteStore(store)
                                                }
                                            }
                                        }
                                        
                                        // Add Store Button as a Card
                                        Button(action: {
                                            showCreateStore = true
                                        }) {
                                            VStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color.green.opacity(0.1))
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Image(systemName: "plus")
                                                            .font(.title2)
                                                            .foregroundColor(.green)
                                                    )
                                                
                                                Text("Thêm mới")
                                                    .font(.headline)
                                                    .foregroundColor(.green)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                            .background(Color.white)
                                            .cornerRadius(16)
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                                    .foregroundColor(Color.green.opacity(0.5))
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                            } else {
                                // Employee View
                                VStack(spacing: 20) {
                                    if storeManager.memberStores.isEmpty && storeManager.invitedStores.isEmpty && storeManager.myStores.isEmpty {
                                        EmptyStoreStateView(message: "Bạn chưa là nhân viên của cửa hàng nào.")
                                    } else {
                                        // Member Stores
                                        ForEach(storeManager.memberStores) { store in
                                            StoreRowCard(store: store) {
                                                Task {
                                                    await storeManager.selectStore(store)
                                                    dismiss()
                                                }
                                            }
                                        }
                                        
                                        // Owned Stores (Simulation Mode)
                                        if !storeManager.myStores.isEmpty {
                                            SectionHeader(title: "Cửa hàng của bạn (Chế độ nhân viên)")
                                            ForEach(storeManager.myStores) { store in
                                                StoreRowCard(store: store) {
                                                    Task {
                                                        await storeManager.selectStore(store)
                                                        dismiss()
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Invitations
                                        if !storeManager.invitedStores.isEmpty {
                                            SectionHeader(title: "Lời mời tham gia")
                                            ForEach(storeManager.invitedStores) { store in
                                                InvitationRow(store: store)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Chọn cửa hàng")
            .navigationBarHidden(true)
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

// MARK: - Subviews

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

struct EmptyStoreStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

struct StoreCardView: View {
    let store: Store
    let isOwner: Bool
    let action: () -> Void
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(store.name.prefix(1)).uppercased())
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    if isOwner {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let address = store.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Chưa cập nhật địa chỉ")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                
                Spacer()
                
                HStack {
                    Text("Truy cập")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .frame(height: 180)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .contextMenu {
            if isOwner {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Xóa cửa hàng", systemImage: "trash")
                }
            }
        }
    }
}

struct StoreRowCard: View {
    let store: Store
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(store.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let address = store.address, !address.isEmpty {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct InvitationRow: View {
    let store: Store
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Đã mời bạn tham gia")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        processInvitation(accept: false)
                    }) {
                        Text("Từ chối")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        processInvitation(accept: true)
                    }) {
                        Text("Đồng ý")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func processInvitation(accept: Bool) {
        isProcessing = true
        Task {
            _ = await storeManager.respondToInvitation(storeId: store.id, accept: accept)
            isProcessing = false
        }
    }
}

