import SwiftUI

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
            Task {
                await loadEmployees()
            }
        }
        .onDisappear {
            tabBarManager.customFabAction = nil
        }
    }

    func loadEmployees() async {
        let rawEmployees = await storeManager.getEmployees()
        employees = rawEmployees.map { EmployeeViewModel(id: $0.0.id, member: $0.0, name: $0.1) }
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
                    Text("Nhập chính xác Email hoặc SĐT đã đăng ký")
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
        .presentationDetentsIfAvailable()
    }
}

extension View {
    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }
}

struct EmployeeDetailView: View {
    let member: StoreMember
    let name: String
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var permissions: Set<StorePermission> = []
    @State private var showSuccessAlert = false
    
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
                Section(header: Text("Thông tin")) {
                    Text("Tên: \(name)")
                    Text("Vai trò: \(member.role.displayName)")
                    Text("Trạng thái: \(member.status?.rawValue ?? "Unknown")")
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
        .onAppear {
            if let memberPermissions = member.permissions {
                permissions = Set(memberPermissions)
            }
        }
    }
}
