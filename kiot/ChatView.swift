import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showNewChatSheet = false
    @State private var searchText = ""
    @Binding var isTabBarVisible: Bool
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.themeBackgroundLight.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Chat")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        
                        Spacer()
                        
                        Button(action: { showNewChatSheet = true }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.themePrimary)
                                .padding(10)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(Color.themeBackgroundLight)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        TextField("Tìm kiếm...", text: $searchText)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Conversation List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.conversations) { conversation in
                                if let employee = viewModel.getEmployee(id: conversation.employeeId) {
                                    NavigationLink(destination: ChatDetailView(viewModel: viewModel, conversation: conversation, employee: employee, isTabBarVisible: $isTabBarVisible)) {
                                        ConversationRow(employee: employee, conversation: conversation)
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Space for TabBar
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewChatSheet) {
                NewChatView(viewModel: viewModel, isPresented: $showNewChatSheet)
            }
        }
        .onAppear {
            isTabBarVisible = true
        }
    }
}

struct ConversationRow: View {
    let employee: Employee
    let conversation: ChatConversation
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: employee.avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.gray.opacity(0.5))
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                if employee.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(employee.name)
                        .font(.headline)
                        .foregroundStyle(Color.themeTextDark)
                    Spacer()
                    Text(conversation.lastMessageTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                HStack {
                    Text(conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

struct NewChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var phoneNumber = ""
    @State private var showToast = false
    @State private var navigateToChat = false
    @State private var foundEmployee: Employee?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Nhập số điện thoại nhân viên")
                    .font(.headline)
                    .padding(.top)
                
                TextField("Số điện thoại (VD: 0901234567)", text: $phoneNumber)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Button(action: checkPhoneNumber) {
                    Text("Tìm & Chat")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Navigation Link (Hidden)
                if let employee = foundEmployee {
                    NavigationLink(destination: ChatDetailView(viewModel: viewModel, conversation: viewModel.startChat(with: employee), employee: employee, isTabBarVisible: .constant(false)), isActive: $navigateToChat) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Tạo hội thoại mới")
            .navigationBarItems(trailing: Button("Đóng") { isPresented = false })
            .overlay(
                Group {
                    if showToast {
                        VStack {
                            Spacer()
                            Text("User not found in the organization.")
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .padding(.bottom, 40)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            )
        }
    }
    
    func checkPhoneNumber() {
        if let employee = viewModel.findEmployee(phoneNumber: phoneNumber) {
            foundEmployee = employee
            navigateToChat = true
        } else {
            withAnimation {
                showToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    let conversation: ChatConversation
    let employee: Employee
    @Binding var isTabBarVisible: Bool
    @State private var messageText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.themeTextDark)
                        .padding()
                }
                
                VStack(alignment: .leading) {
                    Text(employee.name)
                        .font(.headline)
                        .foregroundStyle(Color.themeTextDark)
                    Text(employee.isOnline ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(employee.isOnline ? .green : .gray)
                }
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.themePrimary)
                    .padding()
            }
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let msgs = viewModel.messages[conversation.id] ?? []
                        ForEach(msgs) { msg in
                            MessageBubble(message: msg, isCurrentUser: msg.senderId == viewModel.currentUserId)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages[conversation.id]?.count) { _ in
                    if let lastMsg = viewModel.messages[conversation.id]?.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            HStack {
                TextField("Nhập tin nhắn...", text: $messageText)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.themePrimary)
                        .padding(10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
        }
        .navigationBarHidden(true)
        .background(Color.themeBackgroundLight.ignoresSafeArea())
        .onAppear {
            isTabBarVisible = false
        }
        .onDisappear {
            isTabBarVisible = true
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.sendMessage(conversationId: conversation.id, text: messageText)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            Text(message.text)
                .padding()
                .background(isCurrentUser ? Color.themePrimary : Color.white)
                .foregroundStyle(isCurrentUser ? Color.white : Color.themeTextDark)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            if !isCurrentUser { Spacer() }
        }
    }
}
