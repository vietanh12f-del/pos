import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var myStores: [Store] = []
    @Published var memberStores: [Store] = [] // Active stores
    @Published var invitedStores: [Store] = [] // Stores with pending invitations
    @Published var currentStore: Store?
    @Published var currentMember: StoreMember?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var priceStep: Int = 5000
    private var memberRealtimeChannel: RealtimeChannelV2?
    
    private let client = SupabaseConfig.client
    
    init() {
        let saved = UserDefaults.standard.integer(forKey: "priceStep")
        priceStep = saved >= 1000 ? saved : 5000
        Task {
            await fetchStores()
            await restoreLastStoreIfPossible()
        }
    }
    
    func setPriceStep(_ step: Int) {
        let s = max(1000, step)
        priceStep = s
        UserDefaults.standard.set(s, forKey: "priceStep")
    }

    func receiptHeaderLines(for storeId: UUID) -> [String] {
        let defaults = UserDefaults.standard
        let l1 = defaults.string(forKey: "receipt_header_\(storeId.uuidString)_line1") ?? ""
        let l2 = defaults.string(forKey: "receipt_header_\(storeId.uuidString)_line2") ?? ""
        let l3 = defaults.string(forKey: "receipt_header_\(storeId.uuidString)_line3") ?? ""
        let l4 = defaults.string(forKey: "receipt_header_\(storeId.uuidString)_line4") ?? ""
        return [l1, l2, l3, l4]
    }

    func setReceiptHeaderLines(storeId: UUID, line1: String, line2: String, line3: String, line4: String) {
        let defaults = UserDefaults.standard
        defaults.set(line1, forKey: "receipt_header_\(storeId.uuidString)_line1")
        defaults.set(line2, forKey: "receipt_header_\(storeId.uuidString)_line2")
        defaults.set(line3, forKey: "receipt_header_\(storeId.uuidString)_line3")
        defaults.set(line4, forKey: "receipt_header_\(storeId.uuidString)_line4")
    }

    func currentStoreReceiptHeaderLines() -> [String] {
        guard let storeId = currentStore?.id else { return [] }
        return receiptHeaderLines(for: storeId)
    }

    func vatEnabled(for storeId: UUID) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "vat_enabled_\(storeId.uuidString)")
    }

    func vatRate(for storeId: UUID) -> Double {
        let defaults = UserDefaults.standard
        let key = "vat_rate_\(storeId.uuidString)"
        // Chỉ dùng default 10 khi chưa từng set, không phải khi giá trị là 0
        if defaults.object(forKey: key) == nil { return 10 }
        return defaults.double(forKey: key)
    }

    func setVATSettings(storeId: UUID, enabled: Bool, rate: Double) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "vat_enabled_\(storeId.uuidString)")
        defaults.set(max(0, min(rate, 50)), forKey: "vat_rate_\(storeId.uuidString)")
    }

    func currentStoreVATEnabled() -> Bool {
        guard let storeId = currentStore?.id else {
            return UserDefaults.standard.bool(forKey: "vat_enabled_global")
        }
        return vatEnabled(for: storeId)
    }

    func currentStoreVATRate() -> Double {
        guard let storeId = currentStore?.id else {
            let key = "vat_rate_global"
            if UserDefaults.standard.object(forKey: key) == nil { return 10 }
            return UserDefaults.standard.double(forKey: key)
        }
        return vatRate(for: storeId)
    }

    // MARK: - Production Feature Toggle

    func currentStoreProductionEnabled() -> Bool {
        let key = "production_enabled_global"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setProductionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "production_enabled_global")
    }

    // MARK: - Multi-Batch Import Mark Toggle

    func currentStoreMultiBatchMarkEnabled() -> Bool {
        let key = "multi_batch_mark_global"
        if UserDefaults.standard.object(forKey: key) == nil { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setMultiBatchMarkEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "multi_batch_mark_global")
    }

    func resetSessionState() {
        self.currentStore = nil
        self.currentMember = nil
        self.myStores = []
        self.memberStores = []
        self.invitedStores = []
        self.errorMessage = nil
    }
    
    func fetchStores() async {
        guard let userId = SupabaseConfig.client.auth.currentUser?.id else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // Only link pending invitations on fresh login (when no stores are loaded yet)
            // This prevents re-linking when user is switching stores
            let shouldLinkInvitations = self.myStores.isEmpty && self.memberStores.isEmpty && self.invitedStores.isEmpty
            var linkedCount = 0
            if shouldLinkInvitations {
                linkedCount = await linkPendingInvitationsForCurrentUser(userId: userId)
                // If we linked any invitations, give Supabase a moment to propagate
                if linkedCount > 0 {
                    print("⏱️ Pausing briefly after linking \(linkedCount) invitations...")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
            }
            
            // Determine role to fetch relevant stores
            // If user explicitly chose "employee", we might NOT want to show owned stores
            // BUT, the user's data (myStores) should probably still be fetched for correctness,
            // and filtering should happen at UI level OR here if we want strict data separation.
            // Let's fetch everything but rely on UI to hide 'myStores' if needed.
            
            // Fetch stores I own
            let myStoresResponse: [Store] = try await client
                .from("stores")
                .select()
                .eq("owner_id", value: userId)
                .execute()
                .value
            
            self.myStores = myStoresResponse
            
            // Fetch stores I am a member of (by user_id OR by email as fallback)
            var allMemberships: [StoreMember] = []
            
            // First try by user_id
            let membershipsById: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            allMemberships.append(contentsOf: membershipsById)
            
            // Also try by email (RLS policy allows this)
            let email = AuthManager.shared.currentUserProfile?.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let email = email, !email.isEmpty {
                let membershipsByEmail: [StoreMember] = try await client
                    .from("store_members")
                    .select()
                    .eq("email", value: email)
                    .execute()
                    .value
                // Merge, avoiding duplicates by id
                let existingIds = Set(allMemberships.map { $0.id })
                let newByEmail = membershipsByEmail.filter { !existingIds.contains($0.id) }
                allMemberships.append(contentsOf: newByEmail)
            }
            
            let memberships = allMemberships
            print("📋 Found \(memberships.count) memberships for user \(userId) (by ID: \(membershipsById.count), by email: \(allMemberships.count - membershipsById.count))")
            for m in memberships {
                print("   - Store: \(m.storeId), Status: \(m.status?.rawValue ?? "nil"), Role: \(m.role)")
            }
            
            if !memberships.isEmpty {
                // Filter active vs invited
                let activeIds = memberships.filter { $0.status == .active || $0.status == nil }.map { $0.storeId }
                let invitedIds = memberships.filter { $0.status == .invited }.map { $0.storeId }
                
                print("🔍 Filtering memberships:")
                print("   - Active IDs: \(activeIds)")
                print("   - Invited IDs: \(invitedIds)")
                
                // Fetch all relevant stores in one go
                let allStoreIds = activeIds + invitedIds
                print("🔍 Querying stores with IDs: \(allStoreIds)")
                if !allStoreIds.isEmpty {
                    let allStores: [Store] = try await client
                        .from("stores")
                        .select()
                        .in("id", values: allStoreIds)
                        .execute()
                        .value
                    
                    print("📋 Fetched \(allStores.count) stores:")
                    for store in allStores {
                        print("   - Store: \(store.name) (\(store.id))")
                    }
                    
                    self.memberStores = allStores.filter { store in activeIds.contains(store.id) }
                    self.invitedStores = allStores.filter { store in invitedIds.contains(store.id) }
                    
                    print("📊 Final stores:")
                    print("   - Member stores: \(self.memberStores.count)")
                    print("   - Invited stores: \(self.invitedStores.count)")
                    for store in self.invitedStores {
                        print("     - \(store.name)")
                    }
                } else {
                     self.memberStores = []
                     self.invitedStores = []
                     print("📊 No store IDs found")
                }
            } else {
                self.memberStores = []
                self.invitedStores = []
            }
            
            // Auto-select store if previously selected or only one available
            // BUT only if we are not currently in a "switching" state (currentStore == nil)
            // If currentStore is nil, it means we are in StoreSelectionView, so DON'T auto-select.
            // Wait, if app just launched, currentStore is nil.
            // We need to distinguish "App Launch" vs "User clicked Switch".
            // For now, let's allow auto-select ONLY if we are NOT already on the selection screen?
            // Actually, the user complained "the tab is disappear shortly".
            // This implies auto-select is kicking in when they don't want it (e.g. after "Switch").
            
            // FIX: If we are calling fetchStores from StoreSelectionView (onAppear), we should NOT auto-select
            // unless it's the very first load.
            // However, fetchStores doesn't know context.
            // Let's remove auto-select logic here or make it smarter.
            // If AuthManager says we have a profile with currentStoreId, we usually want to go there.
            // But if the user explicitly logged out of the store (set currentStore = nil), we shouldn't force them back.
            
            // To fix "tab disappear shortly":
            // When user clicks "Switch", currentStore becomes nil. StoreSelectionView appears.
            // StoreSelectionView calls fetchStores().
            // fetchStores() completes, and THEN executes auto-select below.
            // Auto-select finds a match and calls selectStore().
            // selectStore() sets currentStore != nil.
            // ContentView sees currentStore != nil and switches back to Dashboard.
            
            // Solution: Remove auto-select from fetchStores().
            // Auto-select should only happen on App Launch (in ContentView or a dedicated startup manager).
            
            // Commenting out auto-select here to prevent unwanted navigation
            /*
            if let currentStoreId = AuthManager.shared.currentUserProfile?.currentStoreId {
                if let store = myStores.first(where: { $0.id == currentStoreId }) ?? 
                               memberStores.first(where: { $0.id == currentStoreId }) {
                    await selectStore(store)
                }
            }
            */
            
            self.isLoading = false
        } catch {
            self.errorMessage = "Lỗi tải cửa hàng: \(error.localizedDescription)"
            print("Error fetching stores: \(error)")
            self.isLoading = false
        }
    }

    private func linkPendingInvitationsForCurrentUser(userId: UUID) async -> Int {
        // Get email from profile or directly from Supabase Auth
        var email = AuthManager.shared.currentUserProfile?.email
        if email == nil {
            email = SupabaseConfig.client.auth.currentUser?.email
        }
        guard let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalizedEmail.isEmpty else {
            print("⚠️ linkPendingInvitations: No email available")
            return 0
        }

        do {
            print("🔗 Linking pending invitations for email: \(normalizedEmail)")
            // First, count how many will be linked
            // Only link invitations that are still invited AND don't have user_id yet
            let pendingMembers: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("email", value: normalizedEmail)
                .is("user_id", value: nil)
                .eq("status", value: "invited")
                .execute()
                .value
            
            guard !pendingMembers.isEmpty else {
                print("ℹ️ No pending invitations to link")
                return 0
            }
            
            // Update them
            try await client
                .from("store_members")
                .update(["user_id": userId])
                .eq("email", value: normalizedEmail)
                .is("user_id", value: nil)
                .eq("status", value: "invited")
                .execute()
            
            print("✅ Linked \(pendingMembers.count) invitations")
            return pendingMembers.count
        } catch {
            print("❌ Error linking pending invitations: \(error)")
            return 0
        }
    }
    
    func createStore(name: String, address: String?) async -> Bool {
        guard let userId = SupabaseConfig.client.auth.currentUser?.id else { return false }
        
        self.isLoading = true
        do {
            let newStore = Store(id: UUID(), name: name, address: address, ownerId: userId, createdAt: Date())
            try await client.from("stores").insert(newStore).execute()
            
            // Bootstrap per-store resources
            // 1) Create a dedicated storage bucket for this store
            let bucketId = "store-\(newStore.id.uuidString)"
            try? await client.storage.createBucket(bucketId, options: BucketOptions(public: false))
            
            // 2) Optionally call RPC to initialize per-store schema/data (if available)
            try? await client
                .rpc("bootstrap_store", params: ["store_id": newStore.id.uuidString, "store_name": name])
                .execute()
            
            // Refresh stores
            await fetchStores()
            
            // Auto-select the new store
            if let createdStore = myStores.first(where: { $0.name == name }) { // simplistic check
               await selectStore(createdStore)
            }
            
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = "Lỗi tạo cửa hàng: \(error.localizedDescription)"
            self.isLoading = false
            return false
        }
    }
    
    func selectStore(_ store: Store) async {
        self.currentStore = store
        
        // Find my membership for this store
        if store.ownerId == SupabaseConfig.client.auth.currentUser?.id {
            // Owner has full permissions implicitly
             self.currentMember = StoreMember(
                id: UUID(), 
                storeId: store.id, 
                userId: store.ownerId, 
                email: AuthManager.shared.currentUserProfile?.email,
                role: .owner, 
                permissions: StorePermission.allCases, 
                status: .active, 
                joinedAt: Date()
            )
            
            Task {
                do {
                    let exists: [StoreMember] = try await client
                        .from("store_members")
                        .select()
                        .match([
                            "store_id": store.id,
                            "user_id": store.ownerId
                        ])
                        .limit(1)
                        .execute()
                        .value
                    
                    if exists.isEmpty {
                        let member = StoreMember(
                            id: UUID(),
                            storeId: store.id,
                            userId: store.ownerId,
                            email: AuthManager.shared.currentUserProfile?.email,
                            role: .owner,
                            permissions: StorePermission.allCases,
                            status: .active,
                            joinedAt: Date()
                        )
                        try await client
                            .from("store_members")
                            .insert(member)
                            .execute()
                    }
                } catch {
                    print("Error ensuring owner membership: \(error)")
                }
            }
        } else {
            // Fetch membership
            do {
                let membership: StoreMember = try await client
                    .from("store_members")
                    .select()
                    .match(["store_id": store.id, "user_id": SupabaseConfig.client.auth.currentUser?.id])
                    .single()
                    .execute()
                    .value
                self.currentMember = membership
                if let membershipUserId = membership.userId {
                    await setupMemberRealtimeSubscription(storeId: store.id, userId: membershipUserId)
                }
            } catch {
                print("Error fetching membership: \(error)")
            }
        }
        
        // Update profile with current store
        if let userId = SupabaseConfig.client.auth.currentUser?.id {
            Task {
                try? await client.from("profiles").update(["current_store_id": store.id]).eq("id", value: userId).execute()
            }
            let key = "last_store_id_\(userId.uuidString)"
            UserDefaults.standard.set(store.id.uuidString, forKey: key)
        } else {
            UserDefaults.standard.set(store.id.uuidString, forKey: "last_store_id_default")
        }
    }
    
    func restoreLastStoreIfPossible() async {
        if currentStore != nil { return }
        let pid = AuthManager.shared.currentUserProfile?.currentStoreId
        let uid = AuthManager.shared.currentUserProfile?.id
        let key = uid != nil ? "last_store_id_\(uid!.uuidString)" : "last_store_id_default"
        let saved = UserDefaults.standard.string(forKey: key)
        let target = pid ?? (saved != nil ? UUID(uuidString: saved!) : nil)
        guard let target else { return }
        if let store = myStores.first(where: { $0.id == target }) ?? memberStores.first(where: { $0.id == target }) {
            await selectStore(store)
        }
    }
    func inviteEmployee(email: String, permissions: [StorePermission]) async -> Bool {
        guard let storeId = currentStore?.id else { return false }
        
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Use RPC to securely find user by email or phone
        struct UserLookupResult: Decodable {
            let id: UUID
            let fullName: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
            }
        }
        
        do {
            // Try to find existing user profile
            let user: UserLookupResult = try await client
                .rpc("find_user_by_email_or_phone", params: ["search_term": email])
                .single()
                .execute()
                .value
            
            print("🔍 Found user via RPC: \(user.id), email: \(normalizedEmail)")
            
            struct InviteeRole: Decodable {
                let accountRole: AccountRole?
                
                enum CodingKeys: String, CodingKey {
                    case accountRole = "account_role"
                }
            }
            
            let inviteeProfiles: [InviteeRole] = try await client
                .from("profiles")
                .select("account_role")
                .eq("id", value: user.id)
                .execute()
                .value
            
            print("📋 Profile query result: \(inviteeProfiles.count) profiles found")
            if let first = inviteeProfiles.first {
                print("   - accountRole: \(first.accountRole?.rawValue ?? "nil")")
            }
            
            // If user is already owner of THIS store, block invitation
            let hasOwnerRole = inviteeProfiles.first?.accountRole == .owner
            let isOwnerOfThisStore = hasOwnerRole && self.myStores.contains(where: { $0.id == storeId && $0.ownerId == user.id })
            print("🔍 isOwnerCheck - hasOwnerRole: \(hasOwnerRole), isOwnerOfThisStore: \(isOwnerOfThisStore)")
            print("   myStores.count: \(self.myStores.count), storeId: \(storeId)")
            if isOwnerOfThisStore {
                print("❌ Blocked: User is owner of this store")
                self.errorMessage = "Tài khoản này đã là Chủ của cửa hàng này."
                return false
            }
            print("✅ User can be invited - proceeding with invitation")
            
            // Check if invitation already exists
            let existingMembers: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("store_id", value: storeId)
                .eq("email", value: normalizedEmail)
                .execute()
                .value
            
            if let existing = existingMembers.first {
                // Update existing record (re-invite) - use StoreMember struct for proper encoding
                let updatedMember = StoreMember(
                    id: existing.id,
                    storeId: storeId,
                    userId: user.id,
                    email: normalizedEmail,
                    role: .employee,
                    permissions: permissions,
                    status: .invited,
                    joinedAt: Date()
                )
                do {
                    try await client.from("store_members")
                        .update(updatedMember)
                        .eq("id", value: existing.id)
                        .execute()
                    print("✅ Re-invited existing member")
                    return true
                } catch {
                    print("❌ Error updating invitation: \(error)")
                    self.errorMessage = "Lỗi cập nhật lời mời: \(error.localizedDescription)"
                    return false
                }
            } else {
                // Insert new invitation
                let member = StoreMember(
                    id: UUID(),
                    storeId: storeId,
                    userId: user.id,
                    email: normalizedEmail,
                    role: .employee,
                    permissions: permissions,
                    status: .invited,
                    joinedAt: Date()
                )
                do {
                    try await client.from("store_members")
                        .insert(member)
                        .execute()
                    print("✅ New invitation inserted")
                    return true
                } catch {
                    print("❌ Error inserting invitation: \(error)")
                    self.errorMessage = "Lỗi tạo lời mời: \(error.localizedDescription)"
                    return false
                }
            }
            
        } catch {
            // User not found — create a pending invitation
            // Check if pending invitation already exists
            do {
                let existingPending: [StoreMember] = try await client
                    .from("store_members")
                    .select()
                    .eq("store_id", value: storeId)
                    .eq("email", value: normalizedEmail)
                    .execute()
                    .value
                
                if let existing = existingPending.first {
                    // Update existing pending - use struct for proper encoding
                    let updatedMember = StoreMember(
                        id: existing.id,
                        storeId: storeId,
                        userId: nil,
                        email: normalizedEmail,
                        role: .employee,
                        permissions: permissions,
                        status: .invited,
                        joinedAt: Date()
                    )
                    try await client.from("store_members")
                        .update(updatedMember)
                        .eq("id", value: existing.id)
                        .execute()
                    print("✅ Updated pending invitation")
                } else {
                    // Insert new pending
                    let member = StoreMember(
                        id: UUID(),
                        storeId: storeId,
                        userId: nil,
                        email: normalizedEmail,
                        role: .employee,
                        permissions: permissions,
                        status: .invited,
                        joinedAt: Date()
                    )
                    try await client.from("store_members")
                        .insert(member)
                        .execute()
                    print("✅ New pending invitation inserted")
                }
                return true
            } catch {
                print("❌ Error with pending invitation: \(error)")
                self.errorMessage = "Lỗi tạo lời mời: \(error.localizedDescription)"
                return false
            }
        }
    }
    
    func getEmployees() async -> [(StoreMember, String)] {
        guard let storeId = currentStore?.id else { return [] }
        
        do {
            let members: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("store_id", value: storeId)
                .execute()
                .value
            
            var result: [(StoreMember, String)] = []
            
            if !members.isEmpty {
                let userIds = members.compactMap { $0.userId }
                var nameMap: [UUID: String] = [:]
                
                if !userIds.isEmpty {
                    struct ProfileName: Decodable {
                        let id: UUID
                        let fullName: String
                        
                        enum CodingKeys: String, CodingKey {
                            case id
                            case fullName = "full_name"
                        }
                    }
                    
                    let profiles: [ProfileName] = try await client
                        .from("profiles")
                        .select("id, full_name")
                        .in("id", values: userIds)
                        .execute()
                        .value
                    
                    nameMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.fullName) })
                }
                
                for member in members {
                    let name = member.userId.flatMap { nameMap[$0] } ?? member.email ?? "Nhân viên (Chưa cập nhật tên)"
                    result.append((member, name))
                }
            }
            
            return result
        } catch {
            print("Error fetching employees: \(error)")
            return []
        }
    }
    
    func deleteStore(_ store: Store) async -> Bool {
        do {
            try await client
                .from("stores")
                .delete()
                .eq("id", value: store.id)
                .execute()
            
            // If deleted store was current store, clear selection
            if currentStore?.id == store.id {
                await MainActor.run {
                    self.currentStore = nil
                    self.currentMember = nil
                }
            }
            
            // Refresh stores
            await fetchStores()
            return true
        } catch {
            self.errorMessage = "Lỗi xóa cửa hàng: \(error.localizedDescription)"
            return false
        }
    }
    
    func getEmployeeCount(storeId: UUID) async -> Int {
        struct Row: Decodable { let id: UUID }
        do {
            let rows: [Row] = try await client
                .from("store_members")
                .select("id")
                .eq("store_id", value: storeId)
                .eq("role", value: "employee")
                .eq("status", value: "active")
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }

    func updateEmployeePermissions(memberId: UUID, permissions: [StorePermission]) async -> Bool {
        do {
            try await client
                .from("store_members")
                .update(["permissions": permissions])
                .eq("id", value: memberId)
                .execute()
            return true
        } catch {
            self.errorMessage = "Lỗi cập nhật quyền: \(error.localizedDescription)"
            return false
        }
    }
    
    func updateEmployeePosition(memberId: UUID, positionTitle: String) async -> Bool {
        do {
            try await client
                .from("store_members")
                .update(["position_title": positionTitle])
                .eq("id", value: memberId)
                .execute()
            return true
        } catch {
            self.errorMessage = "Lỗi cập nhật chức vụ: \(error.localizedDescription)"
            return false
        }
    }
    
    @MainActor
    private func setupMemberRealtimeSubscription(storeId: UUID, userId: UUID) async {
        if let channel = memberRealtimeChannel {
            await channel.unsubscribe()
        }
        
        let channel = client.channel("member-changes-\(storeId)")
        let filter = "store_id=eq.\(storeId)&user_id=eq.\(userId)"
        let _ = channel.onPostgresChange(UpdateAction.self, schema: "public", table: "store_members", filter: filter) { [weak self] change in
            guard let self = self else { return }
            Task { @MainActor in
                do {
                    let updated = try change.decodeRecord(as: StoreMember.self, decoder: JSONDecoder())
                    if self.currentMember?.id == updated.id {
                        self.currentMember = updated
                    }
                } catch {
                    print("Error decoding membership update: \(error)")
                }
            }
        }
        let _ = channel.onPostgresChange(InsertAction.self, schema: "public", table: "store_members", filter: filter) { [weak self] change in
            guard let self = self else { return }
            Task { @MainActor in
                do {
                    let inserted = try change.decodeRecord(as: StoreMember.self, decoder: JSONDecoder())
                    self.currentMember = inserted
                } catch {
                    print("Error decoding membership insert: \(error)")
                }
            }
        }
        
        do {
            try await channel.subscribeWithError()
            self.memberRealtimeChannel = channel
        } catch {
            print("Realtime subscribe error: \(error)")
        }
    }
    
    func removeEmployee(memberId: UUID) async -> Bool {
        do {
            try await client
                .from("store_members")
                .delete()
                .eq("id", value: memberId)
                .execute()
            return true
        } catch {
            self.errorMessage = "Lỗi xóa nhân viên: \(error.localizedDescription)"
            return false
        }
    }
    
    // Check permission helper
    func hasPermission(_ permission: StorePermission) -> Bool {
        guard let member = currentMember else { return false }
        
        // If user explicitly logged in as "Employee", restrict privileges even for Owners
        if AuthManager.shared.selectedRole == "employee" {
            // If the user is actually an owner/manager, but selected "employee",
            // we simulate employee mode by denying implicit full access.
            // Since owners don't have explicit permissions stored, we might default to NO special permissions
            // or we could check if they have permissions set (unlikely for owners).
            // For now, let's treat it as: If you say you are employee, you only get what's in 'permissions' array.
            // If 'permissions' is nil (for owner), you get nothing.
            
            // However, we must ensure regular employees still work.
            if member.role == .owner || member.role == .manager {
                // Simulating employee for owner/manager:
                // They likely have no permissions array.
                // We should probably return false for high-level stuff.
                // Or better, return false to force them to use the restricted view.
                return false
            }
        }
        
        if member.role == .owner || member.role == .manager { return true }
        return member.permissions?.contains(permission) ?? false
    }
    
    func respondToInvitation(storeId: UUID, accept: Bool) async -> Bool {
        guard let userId = SupabaseConfig.client.auth.currentUser?.id,
              let email = SupabaseConfig.client.auth.currentUser?.email else { return false }
        
        do {
            print("🔄 Responding to invitation: storeId=\(storeId), accept=\(accept)")
            print("   userId=\(userId), email=\(email)")
            
            // Try to update by email first (for records linked via email with user_id = nil)
            print("🔍 Attempting update by email...")
            print("   Match conditions: store_id=\(storeId), email=\(email)")
            
            let updatedByEmail = try await client
                .from("store_members")
                .update([
                    "status": accept ? "active" : "declined",
                    "user_id": userId.uuidString  // Link the user_id now
                ])
                .match(["store_id": storeId, "email": email])
                .execute()
            
            print("📊 Update by email status: \(updatedByEmail.response.statusCode)")
            if let responseText = String(data: updatedByEmail.data, encoding: .utf8) {
                print("   Response body: \(responseText)")
            }
            
            // If no records updated by email, try by user_id (for already linked records)
            if updatedByEmail.response.statusCode == 204 {
                // 204 No Content means no rows were affected
                print("🔍 No records found by email, trying by user_id...")
                let updatedByUserId = try await client
                    .from("store_members")
                    .update(["status": accept ? "active" : "declined"])
                    .match(["store_id": storeId, "user_id": userId])
                    .execute()
                print("📊 Update by user_id status: \(updatedByUserId.response.statusCode)")
            }
            
            // Give database a moment to commit the update
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            await fetchStores() // Refresh list
            
            // If accepted, update role to employee and select the store
            if accept {
                AuthManager.shared.selectedRole = AccountRole.employee.rawValue
                print("✅ Updated selectedRole to employee after accepting invitation")
                
                // Find and select the store
                if let acceptedStore = self.memberStores.first(where: { $0.id == storeId }) {
                    await selectStore(acceptedStore)
                    print("✅ Auto-selected store after accepting invitation")
                } else if let invitedStore = self.invitedStores.first(where: { $0.id == storeId }) {
                    // Move from invited to member stores
                    await selectStore(invitedStore)
                    print("✅ Auto-selected store from invited list after accepting")
                }
            }
            
            return true
        } catch {
            self.errorMessage = "Lỗi phản hồi lời mời: \(error.localizedDescription)"
            return false
        }
    }

    func updateStoreBankInfo(storeId: UUID, bankName: String, accountNumber: String) async throws {
        try await client
            .from("stores")
            .update(["bank_name": bankName, "bank_account_number": accountNumber])
            .eq("id", value: storeId)
            .execute()
            
        // Update local store
        if let index = myStores.firstIndex(where: { $0.id == storeId }) {
            myStores[index].bankName = bankName
            myStores[index].bankAccountNumber = accountNumber
        }
        
        if currentStore?.id == storeId {
            currentStore?.bankName = bankName
            currentStore?.bankAccountNumber = accountNumber
        }
    }
    
    func updateStoreName(storeId: UUID, newName: String) async throws {
        try await client
            .from("stores")
            .update(["name": newName])
            .eq("id", value: storeId)
            .execute()
            
        // Update local store
        if let index = myStores.firstIndex(where: { $0.id == storeId }) {
            myStores[index].name = newName
        }
        
        if currentStore?.id == storeId {
            currentStore?.name = newName
        }
    }
}
