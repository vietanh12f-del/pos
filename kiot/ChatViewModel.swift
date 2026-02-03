import SwiftUI
import Combine
import Supabase

class ChatViewModel: ObservableObject {
    private let client = SupabaseConfig.client
    @Published var conversations: [ChatConversation] = []
    @Published var messages: [UUID: [ChatMessage]] = [:] // Key: Conversation ID (or Participant ID for simplicity)
    @Published var employees: [Employee] = []
    
    // Current User
    var currentUserId: UUID {
        return AuthManager.shared.currentUserProfile?.id ?? UUID()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // loadMockData() // Disabled for real implementation
        Task {
            await fetchConversations()
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
                if var msgs = messages[conversationId] {
                    msgs.append(msg)
                    messages[conversationId] = msgs
                } else {
                    messages[conversationId] = [msg]
                }
                
                // Update conversation last message
                if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                    conversations[index].lastMessage = text
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
                if convMap[otherId] == nil {
                    convMap[otherId] = []
                }
                convMap[otherId]?.append(msg)
            }
            
            // Build conversations
            var newConversations: [ChatConversation] = []
            var newMessages: [UUID: [ChatMessage]] = [:]
            
            for (otherId, msgs) in convMap {
                // Sort messages
                let sortedMsgs = msgs.sorted { $0.timestamp < $1.timestamp }
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
            
            self.conversations = newConversations
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
}
