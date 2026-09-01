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
    @Published var phoneLinkConflictPhone: String?
    @Published var currentUserProfile: UserProfile?
    @Published var selectedRole: String = AccountRole.owner.rawValue
    @Published var testOTP: String? // Mã OTP test để hiện lên màn hình
    @Published var loginMethod: LoginMethod = .phone // Chọn phương thức đăng nhập
    private var currentSessionUserId: UUID?

    /// Trả về true nếu user hiện tại là chủ cửa hàng (store-level)
    var isOwner: Bool {
        StoreManager.shared.currentMember?.role == .owner
    }

    /// Trả về true nếu được xem giá vốn:
    /// - Chủ cửa hàng hiện tại (store-level role = owner) luôn được xem
    /// - Nhân viên/manager chỉ được xem nếu có quyền viewCostPrice được cấp
    var canViewCostPrice: Bool {
        let storeRole = StoreManager.shared.currentMember?.role
        if storeRole == .owner { return true }
        return StoreManager.shared.hasPermission(.viewCostPrice)
    }
    
    enum LoginMethod {
        case phone
        case email
    }
    
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
                self.currentSessionUserId = nil
                StoreManager.shared.resetSessionState()
                print("ℹ️ Stored session expired")
            } else {
                if currentSessionUserId != session.user.id {
                    StoreManager.shared.resetSessionState()
                    currentSessionUserId = session.user.id
                }
                self.isAuthenticated = true
                print("✅ User is authenticated: \(session.user.id)")
                await checkProfile(userId: session.user.id)
            }
        } catch {
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.selectedRole = AccountRole.owner.rawValue
            self.currentSessionUserId = nil
            StoreManager.shared.resetSessionState()
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
                // Auto-create profile on first login — no manual profile creation step
                let user = client.auth.currentUser
                let name: String = {
                    if let user = user, case let .string(n)? = user.userMetadata["full_name"] {
                        return n
                    }
                    return user?.email ?? "Người dùng"
                }()
                let email = user?.email
                
                let newProfile = UserProfile(
                    id: userId,
                    fullName: name,
                    email: email,
                    phoneNumber: user?.phone,
                    address: nil,
                    avatarUrl: nil,
                    createdAt: Date(),
                    currentStoreId: nil,
                    accountRole: nil
                )
                
                do {
                    try await client.from("profiles").insert(newProfile).execute()
                    self.currentUserProfile = newProfile
                    print("✅ Auto-created profile for new user: \(userId)")
                    // Trigger store fetch to link any pending invitations
                    await StoreManager.shared.fetchStores()
                } catch {
                    print("❌ Error auto-creating profile: \(error)")
                }
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
    func sendOTP(phone: String) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

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

            let errorString = String(describing: error)
            if errorString.contains("Invalid From Number") {
                self.errorMessage = "Lỗi cấu hình server: Sai số điện thoại gửi. Vui lòng kiểm tra cấu hình SMS."
            } else if errorString.contains("sms_send_failed") {
                self.errorMessage = "Gửi SMS thất bại. Vui lòng kiểm tra cấu hình SMS hoặc giới hạn gửi tin."
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
            await checkProfile(userId: session.user.id)
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Mã OTP không đúng hoặc đã hết hạn."
            print("❌ Error verifying OTP: \(error)")
            return false
        }
    }

    @MainActor
    func requestPhoneLink(phone: String) async -> Bool {
        guard client.auth.currentUser != nil else { return false }
        self.isLoading = true
        self.errorMessage = nil
        self.phoneLinkConflictPhone = nil

        let formattedPhone = formatPhoneNumber(phone)

        do {
            _ = try await client.auth.update(
                user: UserAttributes(phone: formattedPhone)
            )
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            let errorString = String(describing: error)
            if errorString.lowercased().contains("already been registered") || errorString.lowercased().contains("phone_exists") {
                self.phoneLinkConflictPhone = formattedPhone
                self.errorMessage = "SĐT này đã được dùng cho một tài khoản khác. Nếu đó là tài khoản rỗng/tạo nhầm, bạn có thể giải phóng SĐT rồi thử lại."
            } else {
                self.errorMessage = "Không thể gửi OTP liên kết SĐT: \(error.localizedDescription)"
            }
            print("❌ Error requesting phone link: \(error)")
            return false
        }
    }

    @MainActor
    func verifyPhoneLinkOTP(phone: String, token: String) async -> Bool {
        guard let user = client.auth.currentUser else { return false }
        self.isLoading = true
        self.errorMessage = nil
        self.phoneLinkConflictPhone = nil

        let formattedPhone = formatPhoneNumber(phone)

        do {
            _ = try await client.auth.verifyOTP(
                phone: formattedPhone,
                token: token,
                type: .phoneChange
            )

            _ = try? await client
                .from("profiles")
                .update(["phone_number": formattedPhone])
                .eq("id", value: user.id)
                .execute()

            if var profile = self.currentUserProfile {
                profile.phoneNumber = formattedPhone
                self.currentUserProfile = profile
            } else {
                await checkProfile(userId: user.id)
            }

            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Mã OTP không đúng hoặc đã hết hạn."
            print("❌ Error verifying phone link OTP: \(error)")
            return false
        }
    }

    enum PhoneReleaseResult {
        case success
        case hasData
        case failure
    }

    @MainActor
    func releasePhoneNumberWithResult(phone: String) async -> PhoneReleaseResult {
        self.isLoading = true
        self.errorMessage = nil

        let formattedPhone = formatPhoneNumber(phone)

        do {
            guard let session = try? await client.auth.session,
                  let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/release-phone-number") else {
                throw NSError(domain: "ReleasePhone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request giải phóng SĐT"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody: [String: Any] = ["phone": formattedPhone]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            if let http = httpResponse as? HTTPURLResponse, http.statusCode >= 400 {
                let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                if err == "phone_in_use_has_data" || http.statusCode == 409 {
                    self.isLoading = false
                    return .hasData
                }
                throw NSError(domain: "ReleasePhone", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }

            let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let status = responseBody["status"] as? String
            if status == "released" || status == "not_found" || status == "already_me" {
                self.phoneLinkConflictPhone = nil
            }

            self.isLoading = false
            return .success
        } catch {
            self.isLoading = false
            self.errorMessage = "Không thể giải phóng SĐT: \(error.localizedDescription)"
            print("❌ Error releasing phone number: \(error)")
            return .failure
        }
    }

    // MARK: - Zalo OTP Flow

    @MainActor
    func sendZaloOTP(phone: String, purpose: String = "link_phone") async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedPhone = formatPhoneNumber(phone)

        do {
            guard let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/send-zalo-otp") else {
                throw NSError(domain: "ZaloOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request gửi OTP"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // For login purpose, use anon key with Bearer prefix. For link_phone, try to use session if available
            if purpose == "login" {
                request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
            } else if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
            }

            let requestBody: [String: Any] = ["phone": formattedPhone, "purpose": purpose]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            if let http = httpResponse as? HTTPURLResponse, http.statusCode >= 400 {
                let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "ZaloOTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }

            // Parse response để lấy mã OTP test
            let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if let otpCode = responseBody["code"] as? String {
                self.testOTP = otpCode
                print("✅ Test OTP received: \(otpCode)")
            }

            self.isLoading = false
            print("✅ Zalo OTP sent to \(formattedPhone)")
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Không thể gửi OTP: \(error.localizedDescription)"
            print("❌ Error sending Zalo OTP: \(error)")
            return false
        }
    }

    @MainActor
    func verifyZaloOTP(phone: String, code: String, purpose: String = "link_phone") async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedPhone = formatPhoneNumber(phone)
        print("[verifyZaloOTP] Sending: phone=\(formattedPhone), code=\(code), purpose=\(purpose)")

        do {
            guard let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/verify-zalo-otp") else {
                throw NSError(domain: "ZaloOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request xác thực OTP"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // For login purpose, use anon key with Bearer prefix. For link_phone, use session if available
            if purpose == "login" {
                request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
            } else if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
            }

            let requestBody: [String: Any] = ["phone": formattedPhone, "code": code, "purpose": purpose]
            print("[verifyZaloOTP] Request body: \(requestBody)")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            if let http = httpResponse as? HTTPURLResponse, http.statusCode >= 400 {
                let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "ZaloOTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }

            // OTP verified successfully
            // For login: use login-with-zalo-otp to create session
            if purpose == "login" {
                // Call login-with-zalo-otp to get user_id and create session
                //guard let loginUrl = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/login-with-zalo-otp") else {
                    // Thay đổi tạm dòng 509
                    guard let loginUrl = URL(string: "https://cgqxrsoaxgyvcskbixuu.supabase.co/functions/v1/login-with-zalo-otp") else {
                    throw NSError(domain: "ZaloOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request đăng nhập"])
                }
                
                var loginRequest = URLRequest(url: loginUrl)
                loginRequest.httpMethod = "POST"
                loginRequest.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
                loginRequest.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
                loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let loginBody: [String: Any] = ["phone": formattedPhone, "code": code]
                loginRequest.httpBody = try JSONSerialization.data(withJSONObject: loginBody)
                
                let (loginData, loginResponse) = try await URLSession.shared.data(for: loginRequest)
                
                if let http = loginResponse as? HTTPURLResponse, http.statusCode >= 400 {
                    let responseBody = (try? JSONSerialization.jsonObject(with: loginData) as? [String: Any]) ?? [:]
                    let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                    throw NSError(domain: "ZaloOTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
                }
                
                let responseBody = (try? JSONSerialization.jsonObject(with: loginData) as? [String: Any]) ?? [:]
                guard let userId = responseBody["user_id"] as? String else {
                    throw NSError(domain: "ZaloOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được thông tin người dùng"])
                }
                
                // Check if we got access token and refresh token
                if let accessToken = responseBody["access_token"] as? String,
                   let refreshToken = responseBody["refresh_token"] as? String {
                    // Use setSession to set the session manually
                    try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                    self.isAuthenticated = true
                    await checkProfile(userId: client.auth.currentUser?.id ?? UUID(uuidString: userId)!)
                    self.isLoading = false
                    print("✅ Zalo OTP login successful: \(formattedPhone)")
                    return true
                } else {
                    // Fallback in case tokens are not available
                    self.isLoading = false
                    self.errorMessage = "Không thể đăng nhập. Vui lòng thử lại."
                    return false
                }
            } else {
                // For link_phone: update current user
                if let user = client.auth.currentUser {
                    _ = try? await client.auth.update(user: UserAttributes(phone: formattedPhone))
                    _ = try? await client
                        .from("profiles")
                        .update(["phone_number": formattedPhone])
                        .eq("id", value: user.id)
                        .execute()
                    
                    if var profile = self.currentUserProfile {
                        profile.phoneNumber = formattedPhone
                        self.currentUserProfile = profile
                    } else {
                        await checkProfile(userId: user.id)
                    }
                }
            }

            self.isLoading = false
            print("✅ Zalo OTP verified: \(formattedPhone)")
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Mã OTP không đúng hoặc đã hết hạn."
            print("❌ Error verifying Zalo OTP: \(error)")
            return false
        }
    }
    
    // MARK: - Email OTP Flow
    
    @MainActor
    func sendEmailOTP(email: String, purpose: String = "login") async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            guard let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/send-email-otp") else {
                throw NSError(domain: "EmailOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request gửi OTP"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")

            let requestBody: [String: Any] = ["email": trimmedEmail, "purpose": purpose]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            if let http = httpResponse as? HTTPURLResponse, http.statusCode >= 400 {
                let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "EmailOTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }

            // Parse response for test OTP
            let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if let otpCode = responseBody["code"] as? String {
                self.testOTP = otpCode
                print("✅ Test Email OTP received: \(otpCode)")
            }

            self.isLoading = false
            print("✅ Email OTP sent to \(trimmedEmail)")
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = "Không thể gửi OTP qua email: \(error.localizedDescription)"
            print("❌ Error sending email OTP: \(error)")
            return false
        }
    }
    
    @MainActor
    func verifyEmailOTP(email: String, code: String, purpose: String = "login") async -> Bool {
        self.isLoading = true
        self.errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("[verifyEmailOTP] Sending: email=\(trimmedEmail), code=\(code), purpose=\(purpose)")

        do {
            guard let url = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/verify-email-otp") else {
                throw NSError(domain: "EmailOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo request xác thực OTP"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfig.key)", forHTTPHeaderField: "Authorization")

            let requestBody: [String: Any] = ["email": trimmedEmail, "code": code, "purpose": purpose]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            if let http = httpResponse as? HTTPURLResponse, http.statusCode >= 400 {
                let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let err = responseBody["error"] as? String ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "EmailOTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }

            let responseBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            guard let userId = responseBody["user_id"] as? String else {
                throw NSError(domain: "EmailOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được thông tin người dùng"])
            }

            // Check if we have access and refresh tokens
            if let accessToken = responseBody["access_token"] as? String,
               let refreshToken = responseBody["refresh_token"] as? String {
                try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                self.isAuthenticated = true
                await checkProfile(userId: client.auth.currentUser?.id ?? UUID(uuidString: userId)!)
                self.isLoading = false
                print("✅ Email OTP login successful: \(trimmedEmail)")
                return true
            } else {
                self.isLoading = false
                self.errorMessage = "Không thể đăng nhập. Vui lòng thử lại."
                return false
            }
        } catch {
            self.isLoading = false
            self.errorMessage = "Mã OTP không đúng hoặc đã hết hạn."
            print("❌ Error verifying email OTP: \(error)")
            return false
        }
    }

    @MainActor
    @discardableResult
    func signOut() async -> Bool {
        do {
            try await client.auth.signOut()
            self.isAuthenticated = false
            self.currentUserProfile = nil
            self.phoneLinkConflictPhone = nil
            self.selectedRole = AccountRole.owner.rawValue
            self.currentSessionUserId = nil
            StoreManager.shared.resetSessionState()
            return true
        } catch {
            print("❌ Error signing out: \(error)")
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

        return "+84" + p
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
