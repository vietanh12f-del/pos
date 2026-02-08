import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var phoneNumber: String = ""
    @State private var otpCode: String = ""
    @State private var isOtpSent: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo or Title
            VStack(spacing: 8) {
                Image(systemName: "flower.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themePrimary)
                
                Text("SmartKiot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Text("Đăng nhập để tiếp tục")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 40)
            
            // Role Selection
            Picker("Vai trò", selection: $authManager.selectedRole) {
                Text("Chủ cửa hàng").tag("owner")
                Text("Nhân viên").tag("employee")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                if !isOtpSent {
                    // Phone Input View
                    VStack(alignment: .leading) {
                        Text("Số điện thoại")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        HStack {
                            Text("🇻🇳 +84")
                                .fontWeight(.medium)
                            
                            TextField("0912345678", text: $phoneNumber)
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: sendOTP) {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Đăng nhập bằng SĐT")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themePrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .disabled(phoneNumber.count < 9 || authManager.isLoading)
                    
                    // Divider
                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                        Text("Hoặc")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.vertical, 20)
                    
                    // Google Sign In
                    Button(action: signInWithGoogle) {
                        HStack(spacing: 12) {
                            // Since we don't have the Google logo asset, we'll use a text G or a system icon
                            // Ideally, use a proper asset: Image("GoogleLogo")
                            Text("G")
                                .font(.title2)
                                .fontWeight(.heavy)
                                .foregroundStyle(Color.blue) // Google Blue-ish
                            
                            Text("Tiếp tục với Google")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.black.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                } else {
                    // OTP Input View
                    VStack(alignment: .leading) {
                        Text("Nhập mã OTP")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        TextField("6 số", text: $otpCode)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .onChange(of: otpCode) { _, newValue in
                                if newValue.count == 6 {
                                    verifyOTP()
                                }
                            }
                    }
                    
                    Button(action: verifyOTP) {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Xác nhận")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themePrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .disabled(otpCode.count < 6 || authManager.isLoading)
                    
                    Button("Gửi lại mã") {
                        isOtpSent = false
                        otpCode = ""
                    }
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
                }
            }
            .padding(.horizontal)
            
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func sendOTP() {
        Task {
            let success = await authManager.sendOTP(phone: phoneNumber)
            if success {
                withAnimation {
                    isOtpSent = true
                }
            }
        }
    }
    
    func verifyOTP() {
        Task {
            _ = await authManager.verifyOTP(phone: phoneNumber, token: otpCode)
        }
    }
    
    func signInWithGoogle() {
        Task {
            _ = await authManager.signInWithGoogle()
        }
    }
}

#Preview {
    AuthenticationView()
}
