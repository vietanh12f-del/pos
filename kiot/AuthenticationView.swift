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
                
                Text("Kiot Hoa")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Text("Đăng nhập để tiếp tục")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 60)
            
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
                            Text("Gửi mã OTP")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themePrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .disabled(phoneNumber.count < 9 || authManager.isLoading)
                    
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
}

#Preview {
    AuthenticationView()
}
