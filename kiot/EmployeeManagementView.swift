import SwiftUI

struct EmployeeManagementView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var employees: [StoreMember] = []
    @State private var showAddEmployee = false
    @State private var newEmployeeEmail = ""
    @State private var selectedPermissions: Set<StorePermission> = [.viewHome, .viewOrders]
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Danh sách nhân viên")) {
                if employees.isEmpty {
                    Text("Chưa có nhân viên nào.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(employees) { member in
                        NavigationLink(destination: EmployeeDetailView(member: member)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    // ideally fetch name from profile
                                    Text("Nhân viên (ID: \(member.userId.uuidString.prefix(4)))") 
                                        .font(.headline)
                                    Text(member.role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if member.status == .invited {
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
            Button(action: { showAddEmployee = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddEmployee) {
            NavigationView {
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
                .navigationTitle("Thêm nhân viên")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { showAddEmployee = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Mời") {
                            Task {
                                let success = await storeManager.inviteEmployee(email: newEmployeeEmail, permissions: Array(selectedPermissions))
                                if success {
                                    showAddEmployee = false
                                    await loadEmployees()
                                } else {
                                    errorMessage = storeManager.errorMessage ?? "Lỗi không xác định"
                                    showErrorAlert = true
                                }
                            }
                        }
                        .disabled(newEmployeeEmail.isEmpty)
                    }
                }
                .alert("Lỗi", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            Task {
                await loadEmployees()
            }
        }
    }
    
    func loadEmployees() async {
        employees = await storeManager.getEmployees()
    }
    
    func deleteEmployee(at offsets: IndexSet) {
        offsets.forEach { index in
            let member = employees[index]
            Task {
                if await storeManager.removeEmployee(memberId: member.id) {
                    await loadEmployees()
                }
            }
        }
    }
}

struct EmployeeDetailView: View {
    let member: StoreMember
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var permissions: Set<StorePermission> = []
    
    var body: some View {
        Form {
            Section(header: Text("Thông tin")) {
                Text("User ID: \(member.userId)")
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
                    _ = await storeManager.updateEmployeePermissions(memberId: member.id, permissions: Array(permissions))
                }
            }
        }
        .navigationTitle("Chi tiết nhân viên")
        .onAppear {
            if let memberPermissions = member.permissions {
                permissions = Set(memberPermissions)
            }
        }
    }
}
