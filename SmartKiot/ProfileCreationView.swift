import SwiftUI
import Supabase

struct ProfileCreationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var selectedAccountRole: AccountRole?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themePrimary)
                
                Text("Tạo hồ sơ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Text("Vui lòng cập nhật thông tin để tiếp tục")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 60)
            
            VStack(spacing: 10) {
                Text("Chọn vai trò sử dụng")
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                
                HStack(spacing: 12) {
                    roleCard(
                        icon: AccountRole.owner.systemImageName,
                        title: AccountRole.owner.displayName,
                        subtitle: AccountRole.owner.subtitle,
                        isSelected: selectedAccountRole == .owner
                    ) {
                        selectedAccountRole = .owner
                    }
                    
                    roleCard(
                        icon: AccountRole.employee.systemImageName,
                        title: AccountRole.employee.displayName,
                        subtitle: AccountRole.employee.subtitle,
                        isSelected: selectedAccountRole == .employee
                    ) {
                        selectedAccountRole = .employee
                    }
                }
                .padding(.horizontal)
                
                Text("Lưu ý: 1 tài khoản chỉ được sử dụng với một vai trò (Chủ cửa hàng hoặc Nhân viên).")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Họ và tên")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    TextField("Nguyễn Văn A", text: $fullName)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading) {
                    Text("Email (Tùy chọn)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    TextField("email@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading) {
                    Text("Địa chỉ (Tùy chọn)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    TextField("123 Đường ABC...", text: $address)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Button(action: saveProfile) {
                if authManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Hoàn tất")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themePrimary)
            .foregroundStyle(.white)
            .cornerRadius(12)
            .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || selectedAccountRole == nil || authManager.isLoading)
            .padding(.horizontal)
            .padding(.top)
            
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if let profile = authManager.currentUserProfile {
                if fullName.isEmpty {
                    fullName = profile.fullName
                }
                if email.isEmpty {
                    email = profile.email ?? ""
                }
                if address.isEmpty {
                    address = profile.address ?? ""
                }
                if selectedAccountRole == nil {
                    selectedAccountRole = profile.accountRole
                }
            }
            
            if let user = SupabaseConfig.client.auth.currentUser {
                if fullName.isEmpty {
                    if case let .string(name)? = user.userMetadata["full_name"] {
                        fullName = name
                    }
                }
                if email.isEmpty {
                    email = user.email ?? ""
                }
            }
        }
    }
    
    func saveProfile() {
        Task {
            guard let role = selectedAccountRole else { return }
            _ = await authManager.createProfile(
                name: fullName,
                email: email,
                address: address,
                role: role
            )
        }
    }
}

#Preview {
    ProfileCreationView()
}

private func roleCard(icon: String, title: String, subtitle: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
    Button(action: onTap) {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : Color.themePrimary)
                .frame(width: 56, height: 56)
                .background(isSelected ? Color.themePrimary : Color.themePrimary.opacity(0.1))
                .clipShape(Circle())
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.themeTextDark)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.themePrimary : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 8 : 4, x: 0, y: 2)
    }
}
