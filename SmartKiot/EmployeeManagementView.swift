import SwiftUI
import Combine

struct EmployeeViewModel: Identifiable {
    let id: UUID
    let member: StoreMember
    let name: String
}

struct EmployeeManagementView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var employees: [EmployeeViewModel] = []
    @State private var showAddEmployee = false
    
    var body: some View {
        List {
            Section(header: Text("Danh sách nhân viên")) {
                if employees.isEmpty {
                    Text("Chưa có nhân viên nào.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(employees) { employee in
                        NavigationLink(destination: EmployeeDetailView(member: employee.member, name: employee.name)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(employee.name) 
                                        .font(.headline)
                                    Text(employee.member.role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    if AuthManager.shared.selectedRole == "owner" {
                                        Text("Chức vụ: \((employee.member.positionTitle?.isEmpty == false) ? (employee.member.positionTitle ?? "") : "—")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                if employee.member.status == .invited {
                                    Text("Đang mời")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteEmployee)
                }
            }
        }
        .refreshable {
            await loadEmployees()
        }
        .navigationTitle("Quản lý nhân viên")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddEmployee = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEmployee) {
            AddEmployeeView(isPresented: $showAddEmployee, onAddSuccess: {
                await loadEmployees()
            })
        }
        .onAppear {
            tabBarManager.customFabAction = { showAddEmployee = true }
            if employees.isEmpty {
                Task {
                    await loadEmployees()
                }
            }
        }
        .onDisappear {
            tabBarManager.customFabAction = nil
        }
        .onChange(of: showAddEmployee) { showing in
            if showing == false {
                Task { await loadEmployees() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshEmployees"))) { _ in
            Task { await loadEmployees() }
        }
    }

    func loadEmployees() async {
        let rawEmployees = await storeManager.getEmployees()
        let filtered = rawEmployees.filter { $0.0.role != .owner }
        employees = filtered.map { EmployeeViewModel(id: $0.0.id, member: $0.0, name: $0.1) }
    }
    
    func deleteEmployee(at offsets: IndexSet) {
        offsets.forEach { index in
            let employee = employees[index]
            Task {
                if await storeManager.removeEmployee(memberId: employee.member.id) {
                    await loadEmployees()
                }
            }
        }
    }
}

struct AddEmployeeView: View {
    @Binding var isPresented: Bool
    var onAddSuccess: () async -> Void
    
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var newEmployeeEmail = ""
    @State private var selectedPermissions: Set<StorePermission> = [.viewHome, .viewOrders]
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button("Hủy") {
                    isPresented = false
                }
                .foregroundStyle(Color.themeTextDark)
                
                Spacer()
                
                Text("Thêm nhân viên")
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                
                Spacer()
                
                Button("Mời") {
                    Task {
                        let success = await storeManager.inviteEmployee(email: newEmployeeEmail, permissions: Array(selectedPermissions))
                        if success {
                            isPresented = false
                            await onAddSuccess()
                        } else {
                            errorMessage = storeManager.errorMessage ?? "Lỗi không xác định"
                            showErrorAlert = true
                        }
                    }
                }
                .disabled(newEmployeeEmail.isEmpty)
                .foregroundStyle(newEmployeeEmail.isEmpty ? Color.gray : Color.themePrimary)
            }
            .padding()
            .background(Color.themeBackgroundLight)
            
            Form {
                Section(header: Text("Thông tin nhân viên")) {
                    TextField("Email / Số điện thoại", text: $newEmployeeEmail)
                    Text("Lưu ý khi nhập số điện thoại: thay 0 bằng 84: ví dụ 09xx --> 849xx")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Quyền truy cập")) {
                    ForEach(StorePermission.allCases, id: \.self) { permission in
                        Toggle(permission.displayName, isOn: Binding(
                            get: { selectedPermissions.contains(permission) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPermissions.insert(permission)
                                } else {
                                    selectedPermissions.remove(permission)
                                }
                            }
                        ))
                    }
                }
            }
            .alert("Lỗi", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct EmployeeDetailView: View {
    let member: StoreMember
    let name: String
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var permissions: Set<StorePermission> = []
    @State private var showSuccessAlert = false
    @State private var positionTitle: String = ""
    @State private var showEditPosition = false
    @StateObject private var speech = SpeechRecognizer()
    @State private var isSavingPosition = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(Color.themeTextDark)
                }
                
                Spacer()
                
                Text("Chi tiết nhân viên")
                    .font(.headline)
                    .foregroundStyle(Color.themeTextDark)
                
                Spacer()
                
                // Invisible button for balance
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(Color.clear)
            }
            .padding()
            .background(Color.white)
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)
                        
                        PlainInfoRow(
                            icon: "person.badge.key",
                            title: "Chức vụ",
                            value: positionTitle.isEmpty ? "—" : positionTitle,
                            actionTitle: "Sửa",
                            action: { showEditPosition = true }
                        )
                        
                        PlainInfoRow(
                            icon: statusIcon(member.status),
                            title: "Trạng thái",
                            value: statusText(member.status),
                            valueColor: statusColor(member.status)
                        )
                    }
                }
                
                Section(header: Text("Quyền hạn")) {
                    ForEach(StorePermission.allCases, id: \.self) { permission in
                        Toggle(permission.displayName, isOn: Binding(
                            get: { permissions.contains(permission) },
                            set: { isSelected in
                                if isSelected {
                                    permissions.insert(permission)
                                } else {
                                    permissions.remove(permission)
                                }
                            }
                        ))
                    }
                }
                
                Button("Lưu thay đổi") {
                    Task {
                        let success = await storeManager.updateEmployeePermissions(memberId: member.id, permissions: Array(permissions))
                        if success {
                            showSuccessAlert = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Chi tiết nhân viên")
        .navigationBarHidden(true)
        .alert("Thành công", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Đã cập nhật quyền hạn thành công.")
        }
        .sheet(isPresented: $showEditPosition) {
            NavigationStack {
                Form {
                    Section(header: Text("Chức vụ")) {
                        HStack {
                            Image(systemName: "person.badge.key")
                                .foregroundStyle(.gray)
                            TextField("Nhập chức vụ", text: $positionTitle)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                        HStack(spacing: 12) {
                            Button {
                                if speech.isRecording {
                                    speech.stopRecording()
                                } else {
                                    try? speech.startRecording()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                                    Text(speech.isRecording ? "Đang ghi" : "Nhập bằng giọng nói")
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Menu {
                                Button("Chủ") { positionTitle = "Chủ" }
                                Button("Kế toán") { positionTitle = "Kế toán" }
                                Button("Quản lý sản xuất") { positionTitle = "Quản lý sản xuất" }
                                Button("Nhân viên sản xuất") { positionTitle = "Nhân viên sản xuất" }
                                Button("Nhân viên bán hàng") { positionTitle = "Nhân viên bán hàng" }
                            } label: {
                                HStack {
                                    Image(systemName: "list.bullet")
                                    Text("Tham khảo")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .navigationTitle("Sửa chức vụ")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { showEditPosition = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            isSavingPosition = true
                            Task {
                                let success = await storeManager.updateEmployeePosition(memberId: member.id, positionTitle: positionTitle)
                                await MainActor.run {
                                    isSavingPosition = false
                                    if success {
                                        showEditPosition = false
                                    }
                                }
                            }
                        }
                        .disabled(positionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingPosition)
                    }
                }
                .onChange(of: speech.transcript) { _, newText in
                    positionTitle = newText
                }
            }
        }
        .onAppear {
            if let memberPermissions = member.permissions {
                permissions = Set(memberPermissions)
            }
            positionTitle = member.positionTitle ?? ""
        }
    }
}

struct PlainInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(valueColor ?? Color.themeTextDark)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }
}

private func statusText(_ status: MemberStatus?) -> String {
    switch status {
    case .active: return "Đang làm"
    case .invited: return "Đã mời"
    case .declined: return "Từ chối"
    default: return "Không rõ"
    }
}

private func statusColor(_ status: MemberStatus?) -> Color {
    switch status {
    case .active: return .green
    case .invited: return .orange
    case .declined: return .red
    default: return .gray
    }
}

private func statusIcon(_ status: MemberStatus?) -> String {
    switch status {
    case .active: return "checkmark.seal.fill"
    case .invited: return "envelope.open.fill"
    case .declined: return "xmark.seal.fill"
    default: return "questionmark.circle.fill"
    }
}
