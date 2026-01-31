import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var messages: [UUID: [ChatMessage]] = [:] // Key: Conversation ID
    @Published var employees: [Employee] = []
    
    // Mock current user ID
    let currentUserId = UUID()
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        // Create some employees
        let emp1 = Employee(name: "Nguyễn Văn A", phoneNumber: "0901234567", avatar: "person.crop.circle.fill", isOnline: true, role: "Nhân viên")
        let emp2 = Employee(name: "Trần Thị B", phoneNumber: "0909876543", avatar: "person.crop.circle.fill", isOnline: false, role: "Quản lý")
        let emp3 = Employee(name: "Lê Văn C", phoneNumber: "0912345678", avatar: "person.crop.circle.fill", isOnline: true, role: "Giao hàng")
        
        employees = [emp1, emp2, emp3]
        
        // Create a conversation with Emp1
        let conv1 = ChatConversation(employeeId: emp1.id, lastMessage: "Chào bạn, hôm nay có đơn mới không?", lastMessageTime: Date().addingTimeInterval(-3600), unreadCount: 2)
        conversations.append(conv1)
        
        // Messages for Conv1
        messages[conv1.id] = [
            ChatMessage(senderId: emp1.id, text: "Chào bạn, hôm nay có đơn mới không?", timestamp: Date().addingTimeInterval(-3600), isRead: false)
        ]
    }
    
    func findEmployee(phoneNumber: String) -> Employee? {
        return employees.first { $0.phoneNumber == phoneNumber }
    }
    
    func startChat(with employee: Employee) -> ChatConversation {
        if let existing = conversations.first(where: { $0.employeeId == employee.id }) {
            return existing
        }
        
        let newConv = ChatConversation(employeeId: employee.id, lastMessage: "", lastMessageTime: Date(), unreadCount: 0)
        conversations.append(newConv)
        messages[newConv.id] = []
        return newConv
    }
    
    func sendMessage(conversationId: UUID, text: String) {
        let msg = ChatMessage(senderId: currentUserId, text: text, timestamp: Date(), isRead: true)
        
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
    
    func getEmployee(id: UUID) -> Employee? {
        return employees.first { $0.id == id }
    }
}
