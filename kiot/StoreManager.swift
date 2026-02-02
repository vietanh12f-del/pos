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
    
    private let client = SupabaseConfig.client
    
    init() {
        Task {
            await fetchStores()
        }
    }
    
    func fetchStores() async {
        guard let userId = SupabaseConfig.client.auth.currentUser?.id else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
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
            
            // Fetch stores I am a member of
            let memberships: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if !memberships.isEmpty {
                // Filter active vs invited
                let activeIds = memberships.filter { $0.status == .active || $0.status == nil }.map { $0.storeId }
                let invitedIds = memberships.filter { $0.status == .invited }.map { $0.storeId }
                
                // Fetch all relevant stores in one go
                let allStoreIds = activeIds + invitedIds
                if !allStoreIds.isEmpty {
                    let allStores: [Store] = try await client
                        .from("stores")
                        .select()
                        .in("id", values: allStoreIds)
                        .execute()
                        .value
                        
                    self.memberStores = allStores.filter { store in activeIds.contains(store.id) }
                    self.invitedStores = allStores.filter { store in invitedIds.contains(store.id) }
                } else {
                     self.memberStores = []
                     self.invitedStores = []
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
    
    func createStore(name: String, address: String?) async -> Bool {
        guard let userId = SupabaseConfig.client.auth.currentUser?.id else { return false }
        
        self.isLoading = true
        do {
            let newStore = Store(id: UUID(), name: name, address: address, ownerId: userId, createdAt: Date())
            try await client.from("stores").insert(newStore).execute()
            
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
                role: .owner, 
                permissions: StorePermission.allCases, 
                status: .active, 
                joinedAt: Date()
            )
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
            } catch {
                print("Error fetching membership: \(error)")
            }
        }
        
        // Update profile with current store
        if let userId = SupabaseConfig.client.auth.currentUser?.id {
            Task {
                try? await client.from("profiles").update(["current_store_id": store.id]).eq("id", value: userId).execute()
            }
        }
    }
    
    func inviteEmployee(email: String, permissions: [StorePermission]) async -> Bool {
        guard let storeId = currentStore?.id else { return false }
        
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
            // Try to find user profile via RPC
            let user: UserLookupResult = try await client
                .rpc("find_user_by_email_or_phone", params: ["search_term": email])
                .single()
                .execute()
                .value
            
            let member = StoreMember(
                id: UUID(),
                storeId: storeId,
                userId: user.id,
                role: .employee,
                permissions: permissions,
                status: .invited,
                joinedAt: Date()
            )
            
            try await client.from("store_members").insert(member).execute()
            return true
            
        } catch {
            self.errorMessage = "Không tìm thấy người dùng (Email/SĐT) hoặc lỗi mời: \(error.localizedDescription)"
            return false
        }
    }
    
    func getEmployees() async -> [StoreMember] {
        guard let storeId = currentStore?.id else { return [] }
        
        do {
            let members: [StoreMember] = try await client
                .from("store_members")
                .select()
                .eq("store_id", value: storeId)
                .execute()
                .value
            return members
        } catch {
            print("Error fetching employees: \(error)")
            return []
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
        guard let userId = SupabaseConfig.client.auth.currentUser?.id else { return false }
        do {
            if accept {
                try await client
                    .from("store_members")
                    .update(["status": "active"])
                    .match(["store_id": storeId, "user_id": userId])
                    .execute()
            } else {
                try await client
                    .from("store_members")
                    .update(["status": "declined"]) // Or delete?
                    .match(["store_id": storeId, "user_id": userId])
                    .execute()
            }
            
            await fetchStores() // Refresh list
            return true
        } catch {
            self.errorMessage = "Lỗi phản hồi lời mời: \(error.localizedDescription)"
            return false
        }
    }
}
