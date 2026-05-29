import SwiftUI

struct LinkPhoneView: View {
    @StateObject private var authManager = AuthManager.shared
    var onSkip: (() -> Void)? = nil
    
    @State private var phoneNumber: String = ""
    @State private var otpCode: String = ""
    @State private var isOtpSent: Bool = false
    @State private var showReleaseConfirm: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "phone.badge.checkmark")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.themePrimary)
                
                Text("Liên kết số điện thoại")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                
                Text("Mã OTP sẽ được gửi qua Zalo OA. Liên kết để đăng nhập bằng SĐT + OTP mà vẫn giữ nguyên dữ liệu.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
                    
                    Button(action: requestLinkOTP) {
                        if authManager.isLoading {
                            ProgressView().tint(.white)
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
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).count < 9 || authManager.isLoading)
                    
                    Button("Bỏ qua") {
                        onSkip?()
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(authManager.isLoading)
                } else {
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
                                    verifyLinkOTP()
                                }
                            }
                    }
                    
                    Button(action: verifyLinkOTP) {
                        if authManager.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Xác nhận liên kết")
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

            if authManager.phoneLinkConflictPhone != nil && !authManager.isLoading {
                Button("Giải phóng SĐT và thử lại") {
                    showReleaseConfirm = true
                }
                .font(.caption)
                .foregroundStyle(Color.themePrimary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: authManager.phoneLinkConflictPhone) { newValue in
            if newValue != nil {
                showReleaseConfirm = true
            }
        }
        .alert("Giải phóng số điện thoại?", isPresented: $showReleaseConfirm) {
            Button("Huỷ", role: .cancel) { }
            Button("Giải phóng", role: .destructive) {
                releaseAndRetry()
            }
        } message: {
            let phone = authManager.phoneLinkConflictPhone ?? ""
            Text("SĐT \(phone) đang thuộc về một tài khoản khác. Hệ thống sẽ xoá tài khoản đó và giải phóng SĐT để liên kết với tài khoản hiện tại của bạn.")
        }
    }
    
    private func requestLinkOTP() {
        Task {
            // Try Zalo OTP first
            let success = await authManager.sendZaloOTP(phone: phoneNumber, purpose: "link_phone")
            if success {
                withAnimation {
                    isOtpSent = true
                }
            }
        }
    }
    
    private func verifyLinkOTP() {
        Task {
            _ = await authManager.verifyZaloOTP(phone: phoneNumber, code: otpCode, purpose: "link_phone")
        }
    }

    private func releaseAndRetry() {
        Task {
            let result = await authManager.releasePhoneNumberWithResult(phone: phoneNumber)
            if result == .success {
                otpCode = ""
                isOtpSent = false
                // Retry with Zalo OTP
                let success = await authManager.sendZaloOTP(phone: phoneNumber, purpose: "link_phone")
                if success {
                    withAnimation {
                        isOtpSent = true
                    }
                }
            }
        }
    }
}

#Preview {
    LinkPhoneView()
}
