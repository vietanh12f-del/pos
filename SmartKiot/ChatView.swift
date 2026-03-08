import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject var orderViewModel: OrderViewModel
    @Binding var showNewChatSheet: Bool
    @State private var searchText = ""
    @Binding var isTabBarVisible: Bool
    @State private var navPath: [ChatRoute] = []
    
    var body: some View {
        NavigationStack(path: $navPath) {
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
                        
                        Button(action: {
                            Task { await viewModel.fetchConversations() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundStyle(Color.themePrimary)
                        }
                        
                        Button(action: { showNewChatSheet = true }) {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                                .foregroundStyle(Color.themePrimary)
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
                                if let employee = viewModel.getEmployee(id: conversation.participantId) {
                                    NavigationLink(destination: ChatDetailView(viewModel: viewModel, orderViewModel: orderViewModel, conversation: conversation, employee: employee, isTabBarVisible: $isTabBarVisible)) {
                                        ConversationRow(employee: employee, conversation: conversation)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    Task { _ = await viewModel.deleteConversation(with: employee.id) }
                                                } label: {
                                                    Text("Xoá chat")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Space for TabBar
                    }
                    .refreshable {
                        await viewModel.fetchConversations()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Tin nhắn")
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewChatSheet) {
                EmployeePickerChatView(viewModel: viewModel, orderViewModel: orderViewModel, isPresented: $showNewChatSheet)
            }
            .navigationDestination(for: ChatRoute.self) { route in
                ChatDetailView(viewModel: viewModel, orderViewModel: orderViewModel, conversation: route.conversation, employee: route.employee, isTabBarVisible: $isTabBarVisible)
            }
        }
        .onAppear {
            isTabBarVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notif in
            if let payload = notif.object as? [String: Any],
               let conv = payload["conversation"] as? ChatConversation,
               let emp = payload["employee"] as? Employee {
                navPath.append(ChatRoute(conversation: conv, employee: emp))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshConversations"))) { _ in
            Task { await viewModel.fetchConversations() }
        }
    }
}

struct ChatRoute: Hashable, Identifiable {
    let id: UUID
    let conversation: ChatConversation
    let employee: Employee
    init(conversation: ChatConversation, employee: Employee) {
        self.id = conversation.id
        self.conversation = conversation
        self.employee = employee
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

struct EmployeePickerChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var orderViewModel: OrderViewModel
    @Binding var isPresented: Bool
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var employees: [(StoreMember, String)] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var navigateToChat = false
    @State private var navConversation: ChatConversation?
    @State private var navEmployee: Employee?
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section {
                        ForEach(employees, id: \.0.id) { item in
                            HStack {
                                Button(action: {
                                    if selectedIds.contains(item.0.userId) {
                                        selectedIds.remove(item.0.userId)
                                    } else {
                                        selectedIds.insert(item.0.userId)
                                    }
                                }) {
                                    Image(systemName: selectedIds.contains(item.0.userId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIds.contains(item.0.userId) ? Color.themePrimary : Color.gray)
                                }
                                Text(item.1)
                                Spacer()
                                Text(item.0.role.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                
                Button(action: createChats) {
                    Text("Chat")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedIds.isEmpty ? Color.gray.opacity(0.4) : Color.themePrimary)
                        .cornerRadius(12)
                }
                .disabled(selectedIds.isEmpty)
                .padding()
            }
            .navigationTitle("Chọn nhân viên")
            .navigationBarItems(trailing: Button("Đóng") { isPresented = false })
            .background(
                NavigationLink(
                    destination: destinationView(),
                    isActive: $navigateToChat
                ) { EmptyView() }
            )
            .onAppear {
                Task {
                    let raw = await storeManager.getEmployees()
                    let filtered = raw.filter { $0.0.status == .active || $0.0.status == nil }
                    employees = filtered
                }
            }
        }
    }
    
    private func createChats() {
        var firstEmployee: Employee?
        var firstConversation: ChatConversation?
        for item in employees where selectedIds.contains(item.0.userId) {
            let emp = Employee(id: item.0.userId, name: item.1, phoneNumber: "", avatar: "", isOnline: false, role: "employee")
            let conv = viewModel.startChat(with: emp)
            if firstEmployee == nil {
                firstEmployee = emp
                firstConversation = conv
            }
        }
        if let emp = firstEmployee, let conv = firstConversation {
            NotificationCenter.default.post(name: NSNotification.Name("OpenConversation"), object: ["conversation": conv, "employee": emp])
        }
        isPresented = false
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        if let emp = navEmployee, let conv = navConversation {
            ChatDetailView(viewModel: viewModel, orderViewModel: orderViewModel, conversation: conv, employee: emp, isTabBarVisible: .constant(false))
        } else {
            EmptyView()
        }
    }
}

struct NewChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var orderViewModel: OrderViewModel
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
                    NavigationLink(destination: ChatDetailView(viewModel: viewModel, orderViewModel: orderViewModel, conversation: viewModel.startChat(with: employee), employee: employee, isTabBarVisible: .constant(false)), isActive: $navigateToChat) {
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
        Task {
            if let employee = await viewModel.findUser(phoneNumber: phoneNumber) {
                await MainActor.run {
                    foundEmployee = employee
                    navigateToChat = true
                }
            } else {
                await MainActor.run {
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
    }
}

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var orderViewModel: OrderViewModel
    let conversation: ChatConversation
    let employee: Employee
    @Binding var isTabBarVisible: Bool
    @State private var messageText = ""
    @Environment(\.presentationMode) var presentationMode
    
    // Order Integration
    @State private var selectedBill: Bill?
    @State private var showDeleteAlert = false
    @State private var inputBarHeight: CGFloat = 0
    @State private var isAtBottom: Bool = true
    
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
                
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Messages List
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    messageList(proxy: proxy)
                        .onAppear {
                            if let last = viewModel.messages[conversation.id]?.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    if !isAtBottom {
                        Button {
                            if let last = viewModel.messages[conversation.id]?.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.themePrimary)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                        .accessibilityLabel("Cuộn tới tin nhắn mới nhất")
                    }
                }
            }
            
            // Input Area
            inputArea
        }
        .navigationTitle(employee.name)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .background(Color.themeBackgroundLight.ignoresSafeArea())
        .onAppear {
            isTabBarVisible = false
        }
        .onDisappear {
            isTabBarVisible = true
            NotificationCenter.default.post(name: NSNotification.Name("RefreshConversations"), object: nil)
        }
        .sheet(item: $selectedBill) { bill in
            BillDetailView(bill: bill, viewModel: orderViewModel)
        }
        .alert("Xoá cuộc chat này?", isPresented: $showDeleteAlert) {
            Button("Xoá", role: .destructive) {
                Task {
                    let ok = await viewModel.deleteConversation(with: employee.id)
                    if ok {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshConversations"), object: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            Button("Huỷ", role: .cancel) { }
        }
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
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
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.sendMessage(conversationId: conversation.id, text: messageText)
        messageText = ""
    }
    
    @ViewBuilder
    private func messageList(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let msgs = viewModel.messages[conversation.id] ?? []
                let lastId = msgs.last?.id
                ForEach(Array(msgs.enumerated()), id: \.1.id) { index, msg in
                    MessageBubble(
                        message: msg,
                        isCurrentUser: msg.senderId == viewModel.currentUserId,
                        onViewOrder: { orderId in
                            if let bill = orderViewModel.pastOrders.first(where: { $0.id == orderId }) {
                                selectedBill = bill
                            }
                        }
                    )
                    .padding(.top, index == 0 ? 0 : ((msgs[index - 1].senderId == msg.senderId) ? 0 : 2))
                    .id(msg.id)
                    .onAppear {
                        if msg.id == lastId {
                            isAtBottom = true
                        }
                    }
                    .onDisappear {
                        if msg.id == lastId {
                            isAtBottom = false
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 0)
        }
        .onChange(of: viewModel.messages[conversation.id]?.count) { _, _ in
            if let lastMsg = viewModel.messages[conversation.id]?.last {
                withAnimation {
                    proxy.scrollTo(lastMsg.id, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    var onViewOrder: ((UUID) -> Void)? = nil
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            if (message.messageType ?? "text") == "order" {
                // Order Card
                Button(action: {
                    if let orderId = message.orderId {
                        onViewOrder?(orderId)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(Color.themePrimary)
                            Text("Đơn hàng")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        
                        Text(message.text)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.themeTextDark)
                            .multilineTextAlignment(.leading)
                        
                        Divider()
                        
                        HStack {
                            Text("Xem chi tiết")
                                .font(.caption)
                                .foregroundStyle(Color.themePrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .frame(width: 250)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Text Message
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 0) {
                    Text(message.text)
                        .padding()
                        .background(isCurrentUser ? Color.themePrimary : Color.white)
                        .foregroundStyle(isCurrentUser ? Color.white : Color.themeTextDark)
                        .cornerRadius(16)
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
