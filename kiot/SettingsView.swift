import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Cửa hàng")) {
                    if let store = storeManager.currentStore {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.name)
                                    .font(.headline)
                                if let role = storeManager.currentMember?.role {
                                    Text(role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Button("Chuyển") {
                                storeManager.currentStore = nil // Triggers StoreSelectionView in ContentView
                            }
                        }
                        
                        if storeManager.hasPermission(.manageEmployees) {
                             NavigationLink(destination: EmployeeManagementView()) {
                                Text("Quản lý nhân viên")
                            }
                        }
                    } else {
                         Button("Chọn cửa hàng") {
                             // This case might be rare as ContentView handles it, but good fallback
                         }
                    }
                }

                Section(header: Text("Tài khoản")) {
                    if let profile = authManager.currentUserProfile {
                        HStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(Text(profile.fullName.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(.gray))
                            
                            VStack(alignment: .leading) {
                                Text(profile.fullName)
                                    .font(.headline)
                                Text(profile.phoneNumber ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                if let email = profile.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: { showEditProfile = true }) {
                            Text("Chỉnh sửa hồ sơ")
                        }
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await authManager.signOut()
                        }
                    } label: {
                        HStack {
                            Text("Đăng xuất")
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                Section(header: Text("Ứng dụng")) {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(authManager: authManager)
            }
        }
    }
}

struct EditProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var address: String
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        _name = State(initialValue: authManager.currentUserProfile?.fullName ?? "")
        _email = State(initialValue: authManager.currentUserProfile?.email ?? "")
        _address = State(initialValue: authManager.currentUserProfile?.address ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thông tin cá nhân")) {
                    TextField("Họ và tên", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Địa chỉ", text: $address)
                }
            }
            .navigationTitle("Chỉnh sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            let success = await authManager.updateProfile(name: name, email: email, address: address)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.isEmpty || authManager.isLoading)
                }
            }
            .overlay {
                if authManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
        }
    }
}
