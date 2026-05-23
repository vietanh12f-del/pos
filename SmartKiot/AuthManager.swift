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
    @Published var selectedRole: String = AccountRole.owner.rawValue
    
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
                self.selectedRole = AccountRole.owner.rawValue
                print("ℹ️ Stored session expired")
            } else {
                self.isAuthenticated = true
                print("✅ User is authenticated: \(session.user.id)")
                await checkProfile(userId: session.user.id)
            }
        } catch {
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.selectedRole = AccountRole.owner.rawValue
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
                var p = profile
                
                if let role = p.accountRole {
                    self.selectedRole = role.rawValue
                    self.currentUserProfile = p
                    return
                }
                
                let inferred = await inferAccountRole(userId: userId)
                p.accountRole = inferred
                self.selectedRole = inferred.rawValue
                self.currentUserProfile = p
                
                _ = try? await client
                    .from("profiles")
                    .update(["account_role": inferred.rawValue])
                    .eq("id", value: userId)
                    .execute()
            } else {
                // No profile found — this account was not registered via the web.
                // App does not support in-app registration per App Store Guideline 3.1.1.
                print("❌ No profile found. User must register at SmartKiot.com first.")
                self.errorMessage = "Tài khoản chưa đăng ký. Vui lòng đăng ký miễn phí tại SmartKiot.com trước khi đăng nhập."
                self.isAuthenticated = false
                try? await client.auth.signOut()
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
    private func inferAccountRole(userId: UUID) async -> AccountRole {
        do {
            struct OwnedStoreId: Decodable {
                let id: UUID
            }
            
            let owned: [OwnedStoreId] = try await client
                .from("stores")
                .select("id")
                .eq("owner_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if !owned.isEmpty { return .owner }
        } catch {
        }
        
        do {
            struct MembershipId: Decodable {
                let id: UUID
            }
            
            let memberships: [MembershipId] = try await client
                .from("store_members")
                .select("id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if !memberships.isEmpty { return .employee }
        } catch {
        }
        
        return .owner
    }
    
    @MainActor
    func createProfile(name: String, email: String, address: String, role: AccountRole) async -> Bool {
        guard let user = client.auth.currentUser else { return false }
        self.isLoading = true
        
        let existing = self.currentUserProfile
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newProfile = UserProfile(
            id: user.id,
            fullName: trimmedName.isEmpty ? (existing?.fullName ?? "Người dùng") : trimmedName,
            email: trimmedEmail.isEmpty ? existing?.email : trimmedEmail,
            phoneNumber: existing?.phoneNumber ?? user.phone,
            address: trimmedAddress.isEmpty ? existing?.address : trimmedAddress,
            avatarUrl: existing?.avatarUrl,
            createdAt: existing?.createdAt ?? Date(),
            currentStoreId: existing?.currentStoreId,
            accountRole: role
        )
        
        do {
            try await client.from("profiles").upsert(newProfile).execute()
            self.currentUserProfile = newProfile
            self.selectedRole = role.rawValue
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
            createdAt: self.currentUserProfile?.createdAt ?? Date(),
            currentStoreId: self.currentUserProfile?.currentStoreId,
            accountRole: self.currentUserProfile?.accountRole
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
    func signOut() async {
        do {
            try await client.auth.signOut()
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.selectedRole = AccountRole.owner.rawValue
        } catch {
            print("❌ Error signing out: \(error)")
        }
    }
    
    @MainActor
    func deleteAccount() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            guard let userId = client.auth.currentUser?.id else {
                self.isLoading = false
                self.errorMessage = "Không tìm thấy người dùng hiện tại"
                return false
            }
            
            // 1) Call Edge Function to permanently delete auth user + all related data
            print("🗑️ Calling delete-account Edge Function...")
            
            guard let session = try? await client.auth.session,
                  let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/delete-account") else {
                throw NSError(domain: "DeleteAccount", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request xóa tài khoản"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            
            if let http = httpResponse as? HTTPURLResponse {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("📡 Edge Function status: \(http.statusCode), body: \(bodyString)")
                if http.statusCode >= 400 {
                    let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                    let err = body["error"] as? String ?? "HTTP \(http.statusCode)"
                    print("❌ Edge Function returned error: \(err)")
                    throw NSError(domain: "DeleteAccount", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
                }
            }
            
            print("✅ Auth user and all data deleted via Edge Function")
            
            // 2) Clear all local data (session, keychain, preferences)
            try await client.auth.signOut()
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            UserDefaults.standard.synchronize()
            clearAllKeychainData()
            
            // 3) Reset local state
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.selectedRole = AccountRole.owner.rawValue
            self.isLoading = false
            print("✅ Account fully deleted and local data cleared")
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi xóa tài khoản: \(error.localizedDescription)"
            print("❌ Error deleting account: \(error)")
            return false
        }
    }
    
    private func clearAllKeychainData() {
        let secClasses = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            SecItemDelete(query as CFDictionary)
        }
        print("🧹 Keychain cleared")
    }
    
    @MainActor
    func signInWithGoogle() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            _ = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "kiot://login-callback"),
                queryParams: [("prompt", "select_account")]
            ) { (session: ASWebAuthenticationSession) in
                session.prefersEphemeralWebBrowserSession = true
            }
            
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
    func signInWithEmail(email: String, password: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            try await client.auth.signIn(
                email: trimmedEmail,
                password: password
            )
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Email: \(error.localizedDescription)"
            return false
        }
    }
    
    @MainActor
    func signInWithAppleOAuth() async -> Bool {
        print("🍎 [Apple OAuth] Starting web-based sign in...")
        self.isLoading = true
        self.errorMessage = nil
        let callback = URL(string: "https://cgqxrsoaxgyvcskbixuu.supabase.co/auth/v1/callback")
        do {
            _ = try await client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: callback
            ) { (session: ASWebAuthenticationSession) in
                session.prefersEphemeralWebBrowserSession = true
            }
            print("🍎 [Apple OAuth] Sign in initiated successfully")
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Apple: \(error.localizedDescription)"
            print("❌ [Apple OAuth] Error signing in with Apple OAuth: \(error)")
            return false
        }
    }
    
    @MainActor
    func signInWithApple(using idToken: String, fullName: String?) async -> Bool {
        print("🍎 [Supabase] Signing in with Apple ID Token (length: \(idToken.count))...")
        if let name = fullName {
            print("🍎 [Supabase] Full name provided: \(name)")
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            print("🍎 [Supabase] Sign in successful. User ID: \(session.user.id)")
            
            if let fullName {
                print("🍎 [Supabase] Updating user metadata with full name...")
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
            print("❌ [Supabase] Error signing in with Apple token: \(error)")
            return false
        }
    }
    
    private final class AppleAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
        var completion: ((Result<ASAuthorization, Error>) -> Void)?
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            print("🍎 [Native] Delegate received authorization success")
            completion?(.success(authorization))
        }
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("🍎 [Native] Delegate received error: \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }
    
    @MainActor
    func loginWithApple() async -> Bool {
        print("🍎 [Native] Starting native Apple Sign In flow...")
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
                print("🍎 [Native] Performing authorization requests...")
                controller.performRequests()
            }
            
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ [Native] Error: Credential is not ASAuthorizationAppleIDCredential")
                self.isLoading = false
                self.errorMessage = "Lỗi đăng nhập Apple"
                return false
            }
            
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                print("❌ [Native] Error: Could not extract identity token")
                self.isLoading = false
                self.errorMessage = "Token Apple không hợp lệ"
                return false
            }
            
            print("🍎 [Native] Successfully extracted ID Token")
            let fullName = credential.fullName?.formatted()
            if let fullName = fullName {
                 print("🍎 [Native] Captured full name: \(fullName)")
            }
            
            return await signInWithApple(using: idToken, fullName: fullName)
        } catch {
            print("❌ [Native] Sign in failed: \(error)")
            self.isLoading = false
            self.errorMessage = "Lỗi đăng nhập Apple: \(error.localizedDescription)"
            return false
        }
    }
    
}
