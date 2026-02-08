import SwiftUI

struct ProfileCreationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    
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
            .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isLoading)
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
    }
    
    func saveProfile() {
        Task {
            _ = await authManager.createProfile(
                name: fullName,
                email: email,
                address: address
            )
        }
    }
}

#Preview {
    ProfileCreationView()
}
