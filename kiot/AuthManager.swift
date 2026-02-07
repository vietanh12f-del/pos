import Foundation
import Supabase
import Combine
import UIKit
import AuthenticationServices

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentUserProfile: UserProfile?
    @Published var needsProfileCreation: Bool = false
    @Published var selectedRole: String = "owner" // "owner" or "employee" - User preference
    
    private let client = SupabaseConfig.client
    
    init() {
        Task {
            await checkSession()
            for await _ in client.auth.authStateChanges {
                await checkSession()
            }
        }
    }
    
    @MainActor
    func checkSession() async {
        do {
            let session = try await client.auth.session
            if session.isExpired {
                self.isAuthenticated = false
                self.currentUserProfile = nil
                self.needsProfileCreation = false
                print("ℹ️ Stored session expired")
            } else {
                self.isAuthenticated = true
                print("✅ User is authenticated: \(session.user.id)")
                await checkProfile(userId: session.user.id)
            }
        } catch {
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.needsProfileCreation = false
            print("ℹ️ User is not authenticated")
        }
    }
    
    @MainActor
    func checkProfile(userId: UUID) async {
        do {
             let response: [UserProfile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
                self.currentUserProfile = profile
                self.needsProfileCreation = false
            } else {
                self.currentUserProfile = nil
                self.needsProfileCreation = true
            }
        } catch {
            print("❌ Error checking profile: \(error)")
            // If table doesn't exist or other error, we might not want to block the user.
            // But if we want to enforce profile, we should set true.
            // For now, let's assume if we can't fetch, we assume they need one if they are auth'd.
            // However, to be safe against network errors, maybe only set true if we are sure?
            // Let's stick to the happy path: empty list = needs profile.
        }
    }
    
    @MainActor
    func createProfile(name: String, email: String, address: String) async -> Bool {
        guard let user = client.auth.currentUser else { return false }
        self.isLoading = true
        
        let newProfile = UserProfile(
            id: user.id,
            fullName: name,
            email: email,
            phoneNumber: user.phone,
            address: address,
            avatarUrl: nil,
            createdAt: Date()
        )
        
        do {
            try await client.from("profiles").upsert(newProfile).execute()
            self.currentUserProfile = newProfile
            self.needsProfileCreation = false
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi tạo hồ sơ: \(error.localizedDescription)"
            print("❌ Error creating profile: \(error)")
            return false
        }
    }
    
    @MainActor
    func updateProfile(name: String, email: String, address: String) async -> Bool {
        guard let user = client.auth.currentUser else { return false }
        self.isLoading = true
        
        let updatedProfile = UserProfile(
            id: user.id,
            fullName: name,
            email: email,
            phoneNumber: user.phone,
            address: address,
            avatarUrl: self.currentUserProfile?.avatarUrl,
            createdAt: self.currentUserProfile?.createdAt ?? Date()
        )
        
        do {
            try await client.from("profiles").upsert(updatedProfile).execute()
            self.currentUserProfile = updatedProfile
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi cập nhật hồ sơ: \(error.localizedDescription)"
            print("❌ Error updating profile: \(error)")
            return false
        }
    }
    
    @MainActor
    func sendOTP(phone: String) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        // Format phone number to E.164 (Vietnamese)
        // e.g. 0912345678 -> +84912345678
        let formattedPhone = formatPhoneNumber(phone)
        
        do {
            try await client.auth.signInWithOTP(
                phone: formattedPhone,
                channel: .sms
            )
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            
            // Handle specific errors for better user feedback
            let errorString = String(describing: error)
            if errorString.contains("Invalid From Number") {
                self.errorMessage = "Lỗi cấu hình server: Sai số điện thoại gửi (Invalid From Number). Vui lòng kiểm tra cấu hình Twilio."
            } else if errorString.contains("sms_send_failed") {
                 self.errorMessage = "Gửi SMS thất bại. Vui lòng kiểm tra cấu hình Twilio hoặc giới hạn gửi tin."
            } else {
                self.errorMessage = error.localizedDescription
            }
            
            print("❌ Error sending OTP: \(error)")
            return false
        }
    }
    
    @MainActor
    func verifyOTP(phone: String, token: String) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        let formattedPhone = formatPhoneNumber(phone)
        
        do {
            let session = try await client.auth.verifyOTP(
                phone: formattedPhone,
                token: token,
                type: .sms
            )
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ OTP Verified. User ID: \(session.user.id)")
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Mã OTP không đúng hoặc đã hết hạn."
            print("❌ Error verifying OTP: \(error)")
            return false
        }
    }
    
    @MainActor
    func signOut() async {
        do {
            try await client.auth.signOut()
            self.isAuthenticated = false
        } catch {
            print("❌ Error signing out: \(error)")
        }
    }
    
    @MainActor
    func signInWithGoogle() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // Using generic OAuth flow
            // Note: You need to configure the redirect URL in Supabase Dashboard -> Auth -> URL Configuration
            // Redirect URL should be something like: kiot://login-callback
            // In newer Supabase versions, this method returns a Session and handles the flow internally (using ASWebAuthenticationSession)
            _ = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "kiot://login-callback")
            )
            
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Google: \(error.localizedDescription)"
            print("❌ Error signing in with Google: \(error)")
            return false
        }
    }
    
    @MainActor
    func signInWithApple(using idToken: String, fullName: String?) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            if let fullName {
                _ = try? await client.auth.update(
                    user: UserAttributes(data: ["full_name": .string(fullName)])
                )
            }
            
            self.isAuthenticated = true
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Apple: \(error.localizedDescription)"
            return false
        }
    }
    
    private final class AppleAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
        var completion: ((Result<ASAuthorization, Error>) -> Void)?
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            completion?(.success(authorization))
        }
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            completion?(.failure(error))
        }
    }
    
    @MainActor
    func loginWithApple() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleAuthDelegate()
        controller.delegate = delegate
        
        do {
            let authorization = try await withCheckedThrowingContinuation { continuation in
                delegate.completion = { result in
                    switch result {
                    case .success(let auth):
                        continuation.resume(returning: auth)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                controller.performRequests()
            }
            
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.isLoading = false
                self.errorMessage = "Lỗi đăng nhập Apple"
                return false
            }
            
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                self.isLoading = false
                self.errorMessage = "Token Apple không hợp lệ"
                return false
            }
            
            let fullName = credential.fullName?.formatted()
            return await signInWithApple(using: idToken, fullName: fullName)
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Apple: \(error.localizedDescription)"
            return false
        }
    }
    
    private func formatPhoneNumber(_ phone: String) -> String {
        var p = phone.replacingOccurrences(of: " ", with: "")
        p = p.replacingOccurrences(of: "-", with: "")
        
        if p.hasPrefix("0") {
            p = String(p.dropFirst())
            return "+84" + p
        } else if p.hasPrefix("84") {
            return "+" + p
        } else if p.hasPrefix("+84") {
            return p
        }
        
        // Fallback (might fail if invalid)
        return "+84" + p
    }
}
