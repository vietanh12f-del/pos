import SwiftUI
import Combine
import Supabase

class ChatViewModel: ObservableObject {
    private let client = SupabaseConfig.client
    private var autoRefreshCancellable: AnyCancellable?
    private struct GroupNameUpdate: Encodable { let name: String? }
    @Published var conversations: [ChatConversation] = []
    @Published var messages: [UUID: [ChatMessage]] = [:] // Key: Conversation ID (or Participant ID for simplicity)
    @Published var employees: [Employee] = []
    @Published var groups: [ChatGroup] = []
    @Published var groupMessages: [UUID: [GroupMessage]] = [:]
    @Published private(set) var hiddenConversations: Set<UUID> = []
    private let hiddenKey = "hidden_conversations_v1"
    @Published private(set) var deleteCutoff: [UUID: Date] = [:] // otherId -> hide messages older than this time
    private let cutoffKey = "delete_cutoff_v1"
    
   
    // Current User
    var currentUserId: UUID {
        return AuthManager.shared.currentUserProfile?.id ?? UUID()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadHiddenConversations()
        loadDeleteCutoff()
        // loadMockData() // Disabled for real implementation
        Task {
            await fetchConversations()
            await fetchGroups()
        }
        
        // Wait for User Profile to be ready before subscribing to Realtime
        AuthManager.shared.$currentUserProfile
            .compactMap { $0 } // Only proceed if profile is not nil
            .first() // Only need to setup once when profile loads
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.subscribeToRealtime()
                }
            }
            .store(in: &cancellables)
    }
    
    func startAutoRefresh() {
        autoRefreshCancellable?.cancel()
        autoRefreshCancellable = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchConversations()
                }
            }
    }
    
    func stopAutoRefresh() {
        autoRefreshCancellable?.cancel()
        autoRefreshCancellable = nil
    }
    
    // MARK: - Realtime Subscription
    
    func subscribeToRealtime() async {
        guard let myId = AuthManager.shared.currentUserProfile?.id else {
            print("⚠️ Cannot subscribe to realtime: User ID not found")
            return 
        }
        
        print("🔌 Subscribing to realtime messages for user: \(myId)")
        let channel = client.channel("public:messages")
        
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "receiver_id=eq.\(myId)"
        )
        
        await channel.subscribe()
        
        let groupChannel = client.channel("public:chat_group_messages")
        let groupChanges = groupChannel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_group_messages"
        )
        await groupChannel.subscribe()
        Task {
            for await change in groupChanges {
                do {
                    let gm = try change.record.decode(as: GroupMessage.self)
                    await handleIncomingGroupMessage(gm)
                } catch {
                    print("Error decoding realtime group message: \(error)")
                }
            }
        }
        
        for await change in changes {
            do {
                let message = try change.record.decode(as: ChatMessage.self)
                await handleIncomingMessage(message)
            } catch {
                print("Error decoding realtime message: \(error)")
            }
        }
    }
    
    @MainActor
    private func handleIncomingMessage(_ message: ChatMessage) async {
        let senderId = message.senderId
        
        if hiddenConversations.contains(senderId) {
            hiddenConversations.remove(senderId)
            saveHiddenConversations()
        }
        
        // Ignore messages older than local delete cutoff for this peer
        if let cutoff = deleteCutoff[senderId], message.timestamp < cutoff {
            return
        }
        
        // 1. Check if conversation exists
        if let index = conversations.firstIndex(where: { $0.participantId == senderId }) {
            var conversation = conversations[index]
            
            // Update conversation details
            conversation.lastMessage = message.text
            conversation.lastMessageTime = message.timestamp
            conversation.unreadCount += 1
            
            // Move to top
            conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
            
            // Append message
            if var msgs = messages[conversation.id] {
                msgs.append(message)
                messages[conversation.id] = msgs
            } else {
                messages[conversation.id] = [message]
            }
            
        } else {
            // 2. New conversation - Fetch Sender Profile
            if let employee = await fetchEmployeeProfile(id: senderId) {
                let newConv = ChatConversation(
                    participantId: senderId,
                    lastMessage: message.text,
                    lastMessageTime: message.timestamp,
                    unreadCount: 1
                )
                
                conversations.insert(newConv, at: 0)
                messages[newConv.id] = [message]
            }
        }
    }
    
    @MainActor
    private func handleIncomingGroupMessage(_ message: GroupMessage) async {
        var arr = groupMessages[message.groupId] ?? []
        arr.append(message)
        groupMessages[message.groupId] = arr
    }
    
    // MARK: - Supabase Integration
    
    @MainActor
    func findUser(phoneNumber: String) async -> Employee? {
        do {
            let profiles: [UserProfile] = try await client
                .from("profiles")
                .select()
                .eq("phone_number", value: phoneNumber)
                .execute()
                .value
            
            if let profile = profiles.first {
                // Map UserProfile to Employee
                let employee = Employee(
                    id: profile.id,
                    name: profile.fullName,
                    phoneNumber: profile.phoneNumber ?? "",
                    avatar: profile.avatarUrl ?? "person.circle.fill",
                    isOnline: true, // TODO: Implement online status
                    role: "User"
                )
                
                // Add to local cache if not exists
                if !employees.contains(where: { $0.id == employee.id }) {
                    employees.append(employee)
                }
                return employee
            }
        } catch {
            print("Error finding user: \(error)")
        }
        return nil
    }
    
    // Backward compatibility for View
    func findEmployee(phoneNumber: String) -> Employee? {
        // This is synchronous, so it can only return cached employees. 
        // Use findUser(phoneNumber:) async for real search.
        return employees.first { $0.phoneNumber == phoneNumber }
    }
    
    func startChat(with employee: Employee) -> ChatConversation {
        if let existing = conversations.first(where: { $0.participantId == employee.id }) {
            return existing
        }
        
        let newConv = ChatConversation(
            participantId: employee.id,
            lastMessage: "",
            lastMessageTime: Date(),
            unreadCount: 0
        )
        conversations.append(newConv)
        messages[newConv.id] = []
        return newConv
    }
    
    func sendMessage(conversationId: UUID, text: String) {
        // Find conversation to get receiverId
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else { return }
        let receiverId = conversation.participantId
        
        Task {
            let msg = ChatMessage(
                senderId: currentUserId,
                receiverId: receiverId,
                text: text,
                timestamp: Date(),
                isRead: false
            )
            
            // Optimistic UI Update
            await MainActor.run {
                // Unhide conversation if previously hidden locally
                if hiddenConversations.contains(receiverId) {
                    hiddenConversations.remove(receiverId)
                    saveHiddenConversations()
                }
                if var msgs = messages[conversationId] {
                    msgs.append(msg)
                    messages[conversationId] = msgs
                } else {
                    messages[conversationId] = [msg]
                }
                
                // Update conversation last message
                if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                    var conv = conversations.remove(at: index)
                    conv.lastMessage = text
                    conv.lastMessageTime = Date()
                    conversations.insert(conv, at: 0)
                }
            }
            
            // Send to Database
            do {
                try await client
                    .from("messages")
                    .insert(msg)
                    .execute()
            } catch {
                print("Error sending message: \(error)")
                // TODO: Handle error (retry, show alert)
            }
        }
    }
    
    func sendOrderMessage(conversationId: UUID, bill: Bill) {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else { return }
        let receiverId = conversation.participantId
        
        // Format order summary text
        let summary = "Đơn hàng: \(formatCurrency(bill.total)) (\(bill.items.count) món)"
        
        Task {
            let msg = ChatMessage(
                senderId: currentUserId,
                receiverId: receiverId,
                text: summary,
                timestamp: Date(),
                isRead: false,
                messageType: "order",
                orderId: bill.id
            )
            
            // Optimistic UI Update
            await MainActor.run {
                // Unhide conversation if previously hidden locally
                if hiddenConversations.contains(receiverId) {
                    hiddenConversations.remove(receiverId)
                    saveHiddenConversations()
                }
                if var msgs = messages[conversationId] {
                    msgs.append(msg)
                    messages[conversationId] = msgs
                } else {
                    messages[conversationId] = [msg]
                }
                
                // Update conversation last message
                if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                    conversations[index].lastMessage = "📦 Đơn hàng mới"
                    conversations[index].lastMessageTime = Date()
                }
            }
            
            // Send to Database
            do {
                try await client
                    .from("messages")
                    .insert(msg)
                    .execute()
            } catch {
                print("Error sending order message: \(error)")
            }
        }
    }
    
    func sendBroadcast(to receiverIds: [UUID], text: String) {
        Task {
            for rid in receiverIds {
                let msg = ChatMessage(
                    senderId: currentUserId,
                    receiverId: rid,
                    text: text,
                    timestamp: Date(),
                    isRead: false
                )
                
                // Ensure local conversation exists
                var localConvId: UUID?
                await MainActor.run {
                    if conversations.first(where: { $0.participantId == rid }) == nil {
                        let conv = ChatConversation(
                            participantId: rid,
                            lastMessage: "",
                            lastMessageTime: Date(),
                            unreadCount: 0
                        )
                        conversations.insert(conv, at: 0)
                        messages[conv.id] = []
                        localConvId = conv.id
                    } else if let idx = conversations.firstIndex(where: { $0.participantId == rid }) {
                        localConvId = conversations[idx].id
                    }
                }
                
                // Optimistic update
                await MainActor.run {
                    let key = localConvId ?? rid
                    if var msgs = messages[key] {
                        msgs.append(msg)
                        messages[key] = msgs
                    } else {
                        messages[key] = [msg]
                    }
                    if let index = conversations.firstIndex(where: { $0.participantId == rid }) {
                        var conv = conversations.remove(at: index)
                        conv.lastMessage = text
                        conv.lastMessageTime = msg.timestamp
                        conversations.insert(conv, at: 0)
                    }
                }
                
                // Persist to DB
                do {
                    try await client
                        .from("messages")
                        .insert(msg)
                        .execute()
                } catch {
                    print("Error broadcasting to \(rid): \(error)")
                }
            }
        }
    }
    
    @MainActor
    func removeLocalConversation(with otherId: UUID) {
        conversations.removeAll { $0.participantId == otherId }
        messages.removeValue(forKey: otherId)
    }
    
    func deleteConversation(with otherId: UUID) async -> Bool {
        // Local-only delete: apply cutoff so this user doesn't see history; peer still sees
        await MainActor.run {
            deleteCutoff[otherId] = Date()
            saveDeleteCutoff()
            removeLocalConversation(with: otherId)
            hideConversation(with: otherId)
        }
        return true
    }
    
    @MainActor
    private func hideConversation(with otherId: UUID) {
        hiddenConversations.insert(otherId)
        saveHiddenConversations()
    }
    
    private func loadHiddenConversations() {
        if let arr = UserDefaults.standard.array(forKey: hiddenKey) as? [String] {
            let ids = arr.compactMap { UUID(uuidString: $0) }
            hiddenConversations = Set(ids)
        }
    }
    
    private func saveHiddenConversations() {
        let arr = hiddenConversations.map { $0.uuidString }
        UserDefaults.standard.set(arr, forKey: hiddenKey)
    }
    
    private func loadDeleteCutoff() {
        if let dict = UserDefaults.standard.dictionary(forKey: cutoffKey) as? [String: Double] {
            var result: [UUID: Date] = [:]
            for (k, v) in dict {
                if let id = UUID(uuidString: k) {
                    result[id] = Date(timeIntervalSince1970: v)
                }
            }
            deleteCutoff = result
        }
    }
    
    private func saveDeleteCutoff() {
        var dict: [String: Double] = [:]
        for (id, date) in deleteCutoff {
            dict[id.uuidString] = date.timeIntervalSince1970
        }
        UserDefaults.standard.set(dict, forKey: cutoffKey)
    }
    
    func createGroupChat(memberIds: [UUID], name: String? = nil) async -> UUID? {
        let myId = currentUserId
        let uniqueMembers = Array(Set(memberIds + [myId]))
        let group = ChatGroup(id: UUID(), name: name, ownerId: myId, createdAt: Date())
        do {
            try await client
                .from("chat_groups")
                .insert(group)
                .execute()
            
            var members: [ChatGroupMember] = []
            for uid in uniqueMembers {
                members.append(ChatGroupMember(id: UUID(), groupId: group.id, userId: uid, addedAt: Date()))
            }
            try await client
                .from("chat_group_members")
                .insert(members)
                .execute()
            return group.id
        } catch {
            print("Error creating group: \(error)")
            return nil
        }
    }
    
    @MainActor
    func fetchConversations() async {
        // In a real app, we would query a 'conversations' table or distinct messages
        // For now, let's just ensure we have the 'messages' table or create it if needed (not possible here easily)
        // We'll assume messages exist.
        // Simplified: Fetch recent messages involving current user
        
        guard let myId = AuthManager.shared.currentUserProfile?.id else { return }
        
        do {
            // Fetch messages where I am sender or receiver
            let response: [ChatMessage] = try await client
                .from("messages")
                .select()
                .or("sender_id.eq.\(myId),receiver_id.eq.\(myId)")
                .order("created_at", ascending: false)
                .limit(50) // Limit for performance
                .execute()
                .value
            
            // Group by other participant
            var convMap: [UUID: [ChatMessage]] = [:]
            for msg in response {
                let otherId = (msg.senderId == myId) ? msg.receiverId : msg.senderId
                // Always allow self-conversation to appear, even if previously hidden
                if hiddenConversations.contains(otherId), otherId != myId { continue }
                if let cutoff = deleteCutoff[otherId], msg.timestamp < cutoff { continue }
                if convMap[otherId] == nil {
                    convMap[otherId] = []
                }
                convMap[otherId]?.append(msg)
            }
            
            // Build conversations
            var newConversations: [ChatConversation] = []
            var newMessages: [UUID: [ChatMessage]] = [:]
            
            for (otherId, msgs) in convMap {
                // Sort and apply cutoff
                let cutoff = deleteCutoff[otherId]
                let sortedMsgs = msgs
                    .filter { cutoff == nil || $0.timestamp >= cutoff! }
                    .sorted { $0.timestamp < $1.timestamp }
                
                if sortedMsgs.isEmpty { continue }
                let lastMsg = sortedMsgs.last
                
                // We need to fetch the profile for 'otherId' to display name/avatar
                if let employee = await fetchEmployeeProfile(id: otherId) {
                    let conv = ChatConversation(
                        participantId: otherId,
                        lastMessage: lastMsg?.text ?? "",
                        lastMessageTime: lastMsg?.timestamp ?? Date(),
                        unreadCount: 0 // TODO: Calculate unread
                    )
                    newConversations.append(conv)
                    newMessages[conv.id] = sortedMsgs
                }
            }
            
            // Ensure self-conversation always exists in the list
            if newConversations.first(where: { $0.participantId == myId }) == nil {
                _ = await fetchEmployeeProfile(id: myId) // cache self profile if not exists
                let selfConv = ChatConversation(
                    participantId: myId,
                    lastMessage: "",
                    lastMessageTime: Date(),
                    unreadCount: 0
                )
                newConversations.insert(selfConv, at: 0)
                newMessages[selfConv.id] = newMessages[selfConv.id] ?? []
                // Unhide self conversation if it was hidden
                if hiddenConversations.contains(myId) {
                    hiddenConversations.remove(myId)
                    saveHiddenConversations()
                }
            }
            
            self.conversations = newConversations.sorted { $0.lastMessageTime > $1.lastMessageTime }
            self.messages = newMessages
            
        } catch {
            print("Error fetching conversations: \(error)")
        }
    }
    
    @MainActor
    private func fetchEmployeeProfile(id: UUID) async -> Employee? {
        // Check cache first
        if let existing = employees.first(where: { $0.id == id }) {
            return existing
        }
        
        do {
            let profiles: [UserProfile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: id)
                .execute()
                .value
            
            if let profile = profiles.first {
                let employee = Employee(
                    id: profile.id,
                    name: profile.fullName,
                    phoneNumber: profile.phoneNumber ?? "",
                    avatar: profile.avatarUrl ?? "person.circle.fill",
                    isOnline: true,
                    role: "User"
                )
                self.employees.append(employee)
                return employee
            }
        } catch {
            print("Error fetching profile \(id): \(error)")
        }
        return nil
    }
    
    func getEmployee(id: UUID) -> Employee? {
        return employees.first { $0.id == id }
    }
    
    @MainActor
    func fetchGroups() async {
        guard let myId = AuthManager.shared.currentUserProfile?.id else { return }
        do {
            let memberships: [ChatGroupMember] = try await client
                .from("chat_group_members")
                .select()
                .eq("user_id", value: myId)
                .execute()
                .value
            
            let groupIds = memberships.map { $0.groupId }
            if groupIds.isEmpty {
                self.groups = []
                return
            }
            let gs: [ChatGroup] = try await client
                .from("chat_groups")
                .select()
                .in("id", values: groupIds)
                .order("created_at", ascending: false)
                .execute()
                .value
            self.groups = gs
        } catch {
            print("Error fetching groups: \(error)")
        }
    }
    
    @MainActor
    func getGroupMembers(groupId: UUID) async -> [Employee] {
        // Prefer RPC to avoid RLS recursion limits; fallback to direct select for owners
        do {
            let profiles: [UserProfile] = try await client
                .rpc("get_group_members", params: ["g_id": groupId])
                .execute()
                .value
            let emps: [Employee] = profiles.map {
                Employee(
                    id: $0.id,
                    name: $0.fullName,
                    phoneNumber: $0.phoneNumber ?? "",
                    avatar: $0.avatarUrl ?? "person.circle.fill",
                    isOnline: true,
                    role: "User"
                )
            }
            return emps
        } catch {
            print("RPC get_group_members not available or failed: \(error)")
            do {
                let rows: [ChatGroupMember] = try await client
                    .from("chat_group_members")
                    .select()
                    .eq("group_id", value: groupId)
                    .execute()
                    .value
                var result: [Employee] = []
                for r in rows {
                    if let emp = await fetchEmployeeProfile(id: r.userId) {
                        result.append(emp)
                    }
                }
                return result
            } catch {
                print("Error fetching group members: \(error)")
                return []
            }
        }
    }
    
    @MainActor
    func fetchGroupMessages(groupId: UUID) async {
        do {
            let rows: [GroupMessage] = try await client
                .from("chat_group_messages")
                .select()
                .eq("group_id", value: groupId)
                .order("created_at", ascending: true)
                .execute()
                .value
            groupMessages[groupId] = rows
        } catch {
            print("Error fetching group messages: \(error)")
        }
    }
    
    func sendGroupMessage(groupId: UUID, text: String) {
        Task {
            let msg = GroupMessage(
                groupId: groupId,
                senderId: currentUserId,
                text: text,
                timestamp: Date(),
                messageType: nil,
                orderId: nil
            )
            await MainActor.run {
                var arr = groupMessages[groupId] ?? []
                arr.append(msg)
                groupMessages[groupId] = arr
            }
            do {
                try await client
                    .from("chat_group_messages")
                    .insert(msg)
                    .execute()
            } catch {
                print("Error sending group message: \(error)")
            }
        }
    }
    
    func deleteGroup(groupId: UUID) async -> Bool {
        do {
            try await client
                .from("chat_groups")
                .delete()
                .eq("id", value: groupId)
                .execute()
            await MainActor.run {
                self.groups.removeAll { $0.id == groupId }
                self.groupMessages.removeValue(forKey: groupId)
            }
            return true
        } catch {
            print("Error deleting group: \(error)")
            return false
        }
    }
    
    func leaveGroup(groupId: UUID) async -> Bool {
        let myId = currentUserId
        do {
            try await client
                .from("chat_group_members")
                .delete()
                .eq("group_id", value: groupId)
                .eq("user_id", value: myId)
                .execute()
            await MainActor.run {
                self.groups.removeAll { $0.id == groupId }
                self.groupMessages.removeValue(forKey: groupId)
            }
            return true
        } catch {
            print("Error leaving group: \(error)")
            return false
        }
    }
    
    func updateGroupName(groupId: UUID, newName: String?) async -> Bool {
        do {
            try await client
                .from("chat_groups")
                .update(GroupNameUpdate(name: newName))
                .eq("id", value: groupId)
                .execute()
            await MainActor.run {
                if let index = self.groups.firstIndex(where: { $0.id == groupId }) {
                    var g = self.groups[index]
                    g.name = newName
                    self.groups[index] = g
                }
            }
            return true
        } catch {
            print("Error updating group name: \(error)")
            return false
        }
    }
}
