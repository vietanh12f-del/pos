import Foundation
import Supabase
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentUserProfile: UserProfile?
    @Published var needsProfileCreation: Bool = false
    
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
            self.isAuthenticated = true
            print("✅ User is authenticated: \(session.user.id)")
            await checkProfile(userId: session.user.id)
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
             let response: [UserProfile] = try await client.database
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
            try await client.database.from("profiles").upsert(newProfile).execute()
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
            try await client.database.from("profiles").upsert(updatedProfile).execute()
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
