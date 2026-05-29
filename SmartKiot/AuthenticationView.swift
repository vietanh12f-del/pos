import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var phoneNumber: String = ""
    @State private var otpCode: String = ""
    @State private var isOtpSent: Bool = false
    @State private var showLegacyLogin: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo or Title
            VStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.themePrimary)
                    .accessibilityHidden(true)
                
                Text("SmartKiot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Text("Đăng nhập để tiếp tục")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
            }
            .padding(.top, 40)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                if !isOtpSent {
                    VStack(alignment: .leading) {
                        Text("Số điện thoại")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        HStack(spacing: 10) {
                            Text("+84")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
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
                            Text("Đăng nhập bằng Zalo")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themePrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).count < 9 || authManager.isLoading)
                    
                    Button(showLegacyLogin ? "Ẩn đăng nhập tài khoản cũ" : "Đăng nhập tài khoản cũ (Google/Apple)") {
                        withAnimation {
                            showLegacyLogin.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(authManager.isLoading)
                    
                    if showLegacyLogin {
                        HStack {
                            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                            Text("Hoặc")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 8)
                            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: signInWithGoogle) {
                            HStack(spacing: 12) {
                                Text("G")
                                    .font(.title2)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Color.blue)
                                
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
                        .disabled(authManager.isLoading)
                        
                        Button {
                            Task { _ = await authManager.loginWithApple() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "applelogo")
                                Text("Tiếp tục với Apple")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
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
                            .onChange(of: otpCode) { newValue in
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
                    
                    Button("Đổi số / Gửi lại mã") {
                        withAnimation {
                            isOtpSent = false
                            otpCode = ""
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.themePrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(authManager.isLoading)
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
            // Use Zalo OTP instead of SMS
            let success = await authManager.sendZaloOTP(phone: phoneNumber, purpose: "login")
            if success {
                withAnimation {
                    isOtpSent = true
                }
            }
        }
    }

    func verifyOTP() {
        Task {
            // Use Zalo OTP verification
            let success = await authManager.verifyZaloOTP(phone: phoneNumber, code: otpCode, purpose: "login")
            if success {
                // Login successful via Zalo OTP
                print("✅ Login successful via Zalo OTP")
            }
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
