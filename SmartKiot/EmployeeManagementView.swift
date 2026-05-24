import SwiftUI
import Combine
import Supabase

struct EmployeeViewModel: Identifiable {
    let id: UUID
    let member: StoreMember
    let name: String
}

struct EmployeeManagementView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var employees: [EmployeeViewModel] = []
    @State private var showAddEmployee = false
    @State private var pendingLeaveCount = 0
    @State private var showLeaveApproval = false
    @State private var showWorkHoursSettings = false
    @State private var reinvitingEmployeeId: UUID? = nil
    @State private var showReinviteSuccess = false

    // Tổng lương: tổng tất cả mức lương nhân viên từ UserDefaults
    private var totalSalary: Double {
        employees.reduce(0) { sum, emp in
            sum + UserDefaults.standard.double(forKey: "employee_salary_\(emp.member.id.uuidString)")
        }
    }

    var body: some View {
        List {
            // ── Tổng quan ──────────────────────────────────────
            Section {
                // Hàng 1: Tổng nhân viên + Tổng lương
                HStack(spacing: 10) {
                    overviewTile(
                        icon: "person.2.fill",
                        label: "Nhân viên",
                        value: "\(employees.count)",
                        color: Color.themePrimary
                    )
                    overviewTile(
                        icon: "banknote.fill",
                        label: "Tổng lương/tháng",
                        value: totalSalary > 0 ? formatCurrency(totalSalary) : "—",
                        color: .green
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // Hàng 2: Duyệt nghỉ + Cài đặt giờ làm
                HStack(spacing: 10) {
                    Button { showLeaveApproval = true } label: {
                        overviewActionTile(
                            icon: "calendar.badge.checkmark",
                            label: "Duyệt nghỉ",
                            badge: pendingLeaveCount > 0 ? "\(pendingLeaveCount)" : nil,
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    Button { showWorkHoursSettings = true } label: {
                        overviewActionTile(
                            icon: "clock.badge.gear",
                            label: "Giờ làm việc",
                            badge: nil,
                            color: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Tổng quan")
            }

            // ── Danh sách nhân viên ────────────────────────────
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
                                    HStack(spacing: 8) {
                                        Text("Đang mời")
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                        
                                        // Re-invite button for invited employees too
                                        Button {
                                            Task {
                                                reinvitingEmployeeId = employee.id
                                                let success = await reinviteEmployee(employee.member)
                                                reinvitingEmployeeId = nil
                                                if success {
                                                    showReinviteSuccess = true
                                                    await loadEmployees()
                                                }
                                            }
                                        } label: {
                                            if reinvitingEmployeeId == employee.id {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                            } else {
                                                Text("Mời lại")
                                                    .font(.caption)
                                                    .padding(4)
                                                    .background(Color.themePrimary.opacity(0.2))
                                                    .foregroundColor(Color.themePrimary)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .disabled(reinvitingEmployeeId != nil)
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                } else if employee.member.status == .declined {
                                    // Show re-invite button for declined employees
                                    Button {
                                        Task {
                                            reinvitingEmployeeId = employee.id
                                            let success = await reinviteEmployee(employee.member)
                                            reinvitingEmployeeId = nil
                                            if success {
                                                showReinviteSuccess = true
                                                await loadEmployees()
                                            }
                                        }
                                    } label: {
                                        if reinvitingEmployeeId == employee.id {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        } else {
                                            Text("Mời lại")
                                                .font(.caption)
                                                .padding(4)
                                                .background(Color.themePrimary.opacity(0.2))
                                                .foregroundColor(Color.themePrimary)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .disabled(reinvitingEmployeeId != nil)
                                    .buttonStyle(BorderlessButtonStyle())
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
            await loadPendingLeave()
        }
        .navigationTitle("Quản lý nhân viên")
        .alert("Thành công", isPresented: $showReinviteSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Đã mời lại nhân viên thành công.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Đóng") {
                    dismiss()
                }
            }
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
        .sheet(isPresented: $showLeaveApproval) {
            LeaveApprovalView()
                .onDisappear { Task { await loadPendingLeave() } }
        }
        .sheet(isPresented: $showWorkHoursSettings) {
            WorkHoursSettingsView()
        }
        .onAppear {
            tabBarManager.customFabAction = { showAddEmployee = true }
            if employees.isEmpty {
                Task {
                    await loadEmployees()
                    await loadPendingLeave()
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

    // MARK: - Tile builders

    @ViewBuilder
    private func overviewTile(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.gray)
                Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(Color.themeTextDark)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func overviewActionTile(icon: String, label: String, badge: String?, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.subheadline).foregroundStyle(color)
                }
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 6, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.gray)
                Text(badge != nil ? "\(badge!) chờ duyệt" : "Cài đặt")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(badge != nil ? color : Color.themeTextDark)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.gray.opacity(0.5))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Data

    func loadEmployees() async {
        let rawEmployees = await storeManager.getEmployees()
        let filtered = rawEmployees.filter { $0.0.role != .owner }
        employees = filtered.map { EmployeeViewModel(id: $0.0.id, member: $0.0, name: $0.1) }
    }

    func loadPendingLeave() async {
        let all = (try? await SupabaseDatabaseService().fetchAllLeaveRequests()) ?? []
        pendingLeaveCount = all.filter { $0.status == "pending" }.count
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

    func reinviteEmployee(_ member: StoreMember) async -> Bool {
        // Re-invite by updating status back to invited
        let dateFormatter = ISO8601DateFormatter()
        let joinedAtString = dateFormatter.string(from: Date())
        
        do {
            try await SupabaseConfig.client
                .from("store_members")
                .update(["status": "invited", "joined_at": joinedAtString])
                .eq("id", value: member.id)
                .execute()
            print("✅ Re-invited employee: \(member.email ?? "unknown")")
            return true
        } catch {
            print("❌ Error re-inviting employee: \(error)")
            return false
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
                    TextField("Email", text: $newEmployeeEmail)
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
    @State private var employeeType: String = "fulltime" // "fulltime" | "parttime"
    @State private var showSalarySheet = false
    @State private var showAttendanceReport = false
    @State private var latestAttendance: AttendanceRecordDB? = nil

    private var employeeTypeKey: String { "employee_type_\(member.id.uuidString)" }
    private var salaryKey: String { "employee_salary_\(member.id.uuidString)" }
    private var currentSalary: Double {
        UserDefaults.standard.double(forKey: salaryKey)
    }

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
                    VStack(alignment: .leading, spacing: 12) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(Color.themeTextDark)

                        // Hai ô tile cạnh nhau
                        HStack(spacing: 10) {
                            // Ô chức vụ
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.key")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.themePrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Chức vụ")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                    Text(positionTitle.isEmpty ? "—" : positionTitle)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.themeTextDark)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    showEditPosition = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.themePrimary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.themePrimary.opacity(0.06))
                            .cornerRadius(12)

                            // Ô trạng thái + phân loại
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: statusIcon(member.status))
                                        .font(.caption)
                                        .foregroundStyle(statusColor(member.status))
                                    Text(statusText(member.status))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(statusColor(member.status))
                                }
                                // Phân loại
                                Menu {
                                    Button {
                                        employeeType = "fulltime"
                                        UserDefaults.standard.set("fulltime", forKey: employeeTypeKey)
                                    } label: {
                                        Label("Chính thức", systemImage: employeeType == "fulltime" ? "checkmark" : "")
                                    }
                                    Button {
                                        employeeType = "parttime"
                                        UserDefaults.standard.set("parttime", forKey: employeeTypeKey)
                                    } label: {
                                        Label("Part-time", systemImage: employeeType == "parttime" ? "checkmark" : "")
                                    }
                                } label: {
                                    let isPartTime = employeeType == "parttime"
                                    let statusColor = isPartTime ? Color.orange : Color.green
                                    let iconName = isPartTime ? "clock.badge.questionmark" : "briefcase.fill"
                                    let labelText = isPartTime ? "Part-time" : "Chính thức"
                                    HStack(spacing: 4) {
                                        Image(systemName: iconName)
                                            .font(.caption2)
                                        Text(labelText)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundStyle(statusColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(statusColor.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(statusColor(member.status).opacity(0.06))
                            .cornerRadius(12)
                        }

                        // Hàng 2: Lương + Thời gian làm
                        HStack(spacing: 10) {
                            // Ô lương
                            Button { showSalarySheet = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "banknote.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Lương")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                        Text(currentSalary > 0
                                             ? formatCurrency(currentSalary)
                                             : "Chưa cài")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(currentSalary > 0 ? Color.themeTextDark : .gray)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.07))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            // Ô thời gian làm
                            Button { showAttendanceReport = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.indigo)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Thời gian làm")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                        if let att = latestAttendance {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Vào: \(att.checkInTime.map { formatShortTime($0) } ?? "—")")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.themeTextDark)
                                                Text("Ra: \(att.checkOutTime.map { formatShortTime($0) } ?? "—")")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                        } else {
                                            Text("Chưa có")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.indigo.opacity(0.07))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
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
        .task {
            // Load attendance mới nhất của nhân viên
            if let userId = member.userId {
                latestAttendance = try? await SupabaseDatabaseService().fetchTodayAttendance(userId: userId)
            }
        }
        .sheet(isPresented: $showSalarySheet) {
            EmployeeSalarySheet(memberId: member.id, memberName: name)
        }
        .sheet(isPresented: $showAttendanceReport) {
            if let userId = member.userId {
                EmployeeAttendanceReport(memberId: userId, memberName: name)
            } else {
                Text("Nhân viên chưa có tài khoản")
            }
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
            employeeType = UserDefaults.standard.string(forKey: employeeTypeKey) ?? "fulltime"
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

// MARK: - Helper

private func formatShortTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "vi_VN")
    f.timeZone = .current
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

// MARK: - Employee Salary Sheet

struct EmployeeSalarySheet: View {
    let memberId: UUID
    let memberName: String
    @Environment(\.dismiss) private var dismiss

    private var salaryKey: String { "employee_salary_\(memberId.uuidString)" }
    private var salaryHistoryKey: String { "employee_salary_history_\(memberId.uuidString)" }

    @State private var salaryText: String = ""
    @State private var salaryType: String = "monthly"  // "monthly" | "daily" | "hourly"
    @State private var isSaving = false
    @State private var payHistory: [SalaryPayment] = []
    @State private var showAddPayment = false
    @State private var payAmountText: String = ""
    @State private var payNote: String = ""
    @State private var selectedTab: SalaryTab = .info

    enum SalaryTab: String, CaseIterable {
        case info    = "Mức lương"
        case history = "Lịch sử trả"
    }

    private let salaryTypes: [(value: String, label: String)] = [
        ("monthly", "Tháng"),
        ("daily",   "Ngày"),
        ("hourly",  "Giờ"),
    ]

    private var currentSalary: Double {
        UserDefaults.standard.double(forKey: salaryKey)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(SalaryTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 10)
                .background(Color.white)
                Divider()

                if selectedTab == .info {
                    salaryInfoView
                } else {
                    salaryHistoryView
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Lương – \(memberName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .onAppear {
                salaryText = currentSalary > 0 ? String(format: "%.0f", currentSalary) : ""
                salaryType = UserDefaults.standard.string(forKey: salaryKey + "_type") ?? "monthly"
                loadPayHistory()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Salary info

    private var salaryInfoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current salary card
                VStack(alignment: .leading, spacing: 12) {
                    Label("Mức lương hiện tại", systemImage: "banknote.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)

                    HStack(spacing: 0) {
                        ForEach(salaryTypes, id: \.value) { type in
                            Button {
                                salaryType = type.value
                                UserDefaults.standard.set(type.value, forKey: salaryKey + "_type")
                            } label: {
                                Text(type.label)
                                    .font(.caption).fontWeight(salaryType == type.value ? .bold : .regular)
                                    .foregroundStyle(salaryType == type.value ? .white : Color.themeTextDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(salaryType == type.value ? Color.themePrimary : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    HStack(spacing: 8) {
                        TextField("Nhập mức lương", text: $salaryText)
                            .keyboardType(.numberPad)
                            .font(.title3).fontWeight(.bold)
                        Text("đ/\(salaryTypes.first { $0.value == salaryType }?.label ?? "")")
                            .font(.subheadline).foregroundStyle(.gray)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(10)

                    Button {
                        isSaving = true
                        let val = Double(salaryText.replacingOccurrences(of: ",", with: "")) ?? 0
                        UserDefaults.standard.set(val, forKey: salaryKey)
                        UserDefaults.standard.set(salaryType, forKey: salaryKey + "_type")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isSaving = false }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            else { Image(systemName: "checkmark.circle.fill") }
                            Text("Lưu mức lương")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.themePrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                // Add payment button
                Button { showAddPayment = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                        Text("Ghi nhận trả lương").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal).padding(.vertical, 16)
        }
        .sheet(isPresented: $showAddPayment) {
            addPaymentSheet
        }
    }

    // MARK: Add payment sheet

    private var addPaymentSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Số tiền")) {
                    HStack {
                        TextField("Nhập số tiền", text: $payAmountText).keyboardType(.numberPad)
                        Text("đ").foregroundStyle(.gray)
                    }
                }
                Section(header: Text("Ghi chú")) {
                    TextField("Tháng 5/2025...", text: $payNote)
                }
            }
            .navigationTitle("Ghi nhận trả lương")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { showAddPayment = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let amount = Double(payAmountText.replacingOccurrences(of: ",", with: "")) ?? 0
                        guard amount > 0 else { return }
                        let payment = SalaryPayment(amount: amount, note: payNote, date: Date())
                        payHistory.insert(payment, at: 0)
                        savePayHistory()
                        payAmountText = ""; payNote = ""
                        showAddPayment = false
                        selectedTab = .history
                    }
                    .fontWeight(.bold)
                    .disabled(payAmountText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Salary history

    private var salaryHistoryView: some View {
        Group {
            if payHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
                    Text("Chưa có lịch sử trả lương").foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                List {
                    ForEach(payHistory) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(formatCurrency(p.amount))
                                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.green)
                                if !p.note.isEmpty {
                                    Text(p.note).font(.caption).foregroundStyle(.gray)
                                }
                            }
                            Spacer()
                            Text(formatDate(p.date))
                                .font(.caption).foregroundStyle(.gray)
                        }
                        .listRowBackground(Color.white)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: Helpers

    private func loadPayHistory() {
        guard let data = UserDefaults.standard.data(forKey: salaryHistoryKey),
              let decoded = try? JSONDecoder().decode([SalaryPayment].self, from: data)
        else { return }
        payHistory = decoded
    }

    private func savePayHistory() {
        if let data = try? JSONEncoder().encode(payHistory) {
            UserDefaults.standard.set(data, forKey: salaryHistoryKey)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

struct SalaryPayment: Identifiable, Codable {
    var id: UUID = UUID()
    var amount: Double
    var note: String
    var date: Date
}

// MARK: - Employee Attendance Report

struct EmployeeAttendanceReport: View {
    let memberId: UUID
    let memberName: String
    @Environment(\.dismiss) private var dismiss

    enum RangeMode: String, CaseIterable {
        case today = "Hôm nay"; case week = "Tuần này"; case month = "Tháng này"; case custom = "Tuỳ chọn"
    }

    @State private var rangeMode: RangeMode = .today
    @State private var customStart = Calendar.current.startOfDay(for: Date())
    @State private var customEnd = Date()
    @State private var showCustomPicker = false
    @State private var showRangePicker = false
    @State private var records: [AttendanceRecordDB] = []
    @State private var isLoading = false
    @State private var selectedRecord: AttendanceRecordDB? = nil

    private var dateInterval: (start: Date, end: Date) {
        let cal = Calendar.current; let now = Date()
        switch rangeMode {
        case .today:
            return (cal.startOfDay(for: now), cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: .day, value: 6, to: start).flatMap {
                cal.date(bySettingHour: 23, minute: 59, second: 59, of: $0)
            } ?? now)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now)
        case .custom:
            return (cal.startOfDay(for: customStart),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd)
        }
    }

    private var totalWorkedSeconds: TimeInterval {
        records.reduce(0) { sum, r in
            guard let i = r.checkInTime, let o = r.checkOutTime else { return sum }
            return sum + o.timeIntervalSince(i)
        }
    }

    private var totalWorkedLabel: String {
        let t = Int(totalWorkedSeconds); let h = t / 3600; let m = (t % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Range selector
                Button { showRangePicker = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar").foregroundStyle(Color.themePrimary)
                        Text(rangeMode.rawValue).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white)
                }
                .buttonStyle(.plain)
                Divider()

                if isLoading {
                    VStack { ProgressView(); Spacer() }.padding()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            // Summary
                            if !records.isEmpty {
                                HStack(spacing: 0) {
                                    summaryCell("\(Set(records.map{$0.date}).count)", "Ngày", .green)
                                    Divider().frame(height: 36)
                                    summaryCell("\(records.count)", "Ca", Color.themePrimary)
                                    Divider().frame(height: 36)
                                    summaryCell(totalWorkedLabel, "Tổng giờ", .blue)
                                }
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }

                            if records.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
                                    Text("Chưa có dữ liệu").foregroundStyle(.gray)
                                }
                                .frame(maxWidth: .infinity).padding(40)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(records.sorted { $0.date > $1.date }) { record in
                                        Button { selectedRecord = record } label: {
                                            AttendanceRecordRow(record: record)
                                        }
                                        .buttonStyle(.plain)
                                        Divider().padding(.leading, 60)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 14)
                    }
                    .background(Color.themeBackgroundLight)
                }
            }
            .navigationTitle("Điểm danh – \(memberName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .task { await loadRecords() }
            .onChange(of: rangeMode) { _, m in
                if m == .custom { showCustomPicker = true }
                else { Task { await loadRecords() } }
            }
            .sheet(item: $selectedRecord) { AttendanceDetailSheet(record: $0) }
            .confirmationDialog("Chọn khoảng thời gian", isPresented: $showRangePicker, titleVisibility: .visible) {
                ForEach(RangeMode.allCases, id: \.self) { m in Button(m.rawValue) { rangeMode = m } }
                Button("Huỷ", role: .cancel) { }
            }
            .sheet(isPresented: $showCustomPicker) {
                NavigationStack {
                    Form {
                        Section {
                            DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                            DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Tuỳ chọn ngày").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xong") { showCustomPicker = false; Task { await loadRecords() } }.fontWeight(.bold)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") { rangeMode = .today; showCustomPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func summaryCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadRecords() async {
        isLoading = true; defer { isLoading = false }
        let (start, end) = dateInterval
        records = (try? await SupabaseDatabaseService().fetchAttendanceRecords(
            userId: memberId, from: start, to: end
        )) ?? []
    }
}

// MARK: - Leave Approval View (chủ duyệt đơn nghỉ)

struct LeaveApprovalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var requests: [LeaveRequest] = []
    @State private var isLoading = false
    @State private var filter: StatusFilter = .pending

    enum StatusFilter: String, CaseIterable {
        case pending  = "Chờ duyệt"
        case approved = "Đã duyệt"
        case rejected = "Từ chối"
        var dbValue: String {
            switch self { case .pending: return "pending"; case .approved: return "approved"; case .rejected: return "rejected" }
        }
    }

    private var filtered: [LeaveRequest] {
        requests.filter { $0.status == filter.dbValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $filter) {
                    ForEach(StatusFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 10)
                .background(Color.white)
                Divider()

                if isLoading {
                    VStack { ProgressView(); Spacer() }.padding()
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
                        Text("Không có đơn nào").foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { req in
                            LeaveApprovalRow(request: req) {
                                Task { await loadRequests() }
                            }
                            .listRowBackground(Color.white)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Duyệt đơn nghỉ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .task { await loadRequests() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadRequests() async {
        isLoading = true; defer { isLoading = false }
        requests = (try? await SupabaseDatabaseService().fetchAllLeaveRequests()) ?? []
    }
}

private struct LeaveApprovalRow: View {
    let request: LeaveRequest
    let onUpdated: () -> Void
    @State private var isProcessing = false
    @State private var showRejectSheet = false
    @State private var rejectNote = ""

    private func formatDate(_ s: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return s }
        let f2 = DateFormatter(); f2.locale = Locale(identifier: "vi_VN"); f2.dateFormat = "EEE, dd/MM/yyyy"
        return f2.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.userName).font(.subheadline).fontWeight(.semibold)
                    Text(formatDate(request.leaveDate)).font(.caption).foregroundStyle(.gray)
                    Text(request.leaveTypeLabel).font(.caption).foregroundStyle(Color.themePrimary)
                }
                Spacer()
                statusBadge
            }
            if let reason = request.reason, !reason.isEmpty {
                Text(reason).font(.caption).foregroundStyle(.gray)
            }
            if request.status == "pending" {
                HStack(spacing: 10) {
                    Button {
                        Task { await updateStatus("rejected") }
                        showRejectSheet = true
                    } label: {
                        Text("Từ chối")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.red.opacity(0.08)).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await updateStatus("approved") }
                    } label: {
                        HStack(spacing: 4) {
                            if isProcessing { ProgressView().scaleEffect(0.7).tint(.white) }
                            else { Text("Duyệt").font(.caption).fontWeight(.bold) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.green).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showRejectSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("Lý do từ chối")) {
                        TextField("Nhập lý do...", text: $rejectNote)
                    }
                }
                .navigationTitle("Từ chối đơn").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { showRejectSheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Xác nhận") {
                            Task { await updateStatus("rejected", note: rejectNote) }
                            showRejectSheet = false
                        }.fontWeight(.bold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var statusBadge: some View {
        let color: Color = request.status == "approved" ? .green : request.status == "rejected" ? .red : .orange
        return Text(request.statusLabel)
            .font(.caption2).fontWeight(.bold).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func updateStatus(_ status: String, note: String? = nil) async {
        isProcessing = true; defer { isProcessing = false }
        try? await SupabaseDatabaseService().updateLeaveRequestStatus(id: request.id, status: status, reviewNote: note)
        onUpdated()
    }
}

// MARK: - Work Hours Settings View

struct WorkHoursSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let key = "work_hours_settings"

    @State private var startHour: Int = 8
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 17
    @State private var endMinute: Int = 30
    @State private var lateThresholdMinutes: Int = 15
    @State private var workDays: Set<Int> = [2, 3, 4, 5, 6, 7] // 1=CN, 2=T2...7=T7

    private let dayNames = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Giờ làm việc")) {
                    HStack {
                        Text("Giờ vào")
                        Spacer()
                        Picker("", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel).frame(width: 60, height: 80).clipped()
                        Text(":").font(.title3)
                        Picker("", selection: $startMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel).frame(width: 60, height: 80).clipped()
                    }
                    HStack {
                        Text("Giờ ra")
                        Spacer()
                        Picker("", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel).frame(width: 60, height: 80).clipped()
                        Text(":").font(.title3)
                        Picker("", selection: $endMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel).frame(width: 60, height: 80).clipped()
                    }
                }

                Section(header: Text("Ngưỡng đi trễ")) {
                    Stepper("Trễ sau \(lateThresholdMinutes) phút", value: $lateThresholdMinutes, in: 0...60, step: 5)
                }

                Section(header: Text("Ngày làm việc")) {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                if workDays.contains(day) { workDays.remove(day) }
                                else { workDays.insert(day) }
                            } label: {
                                Text(dayNames[day - 1])
                                    .font(.caption).fontWeight(.semibold)
                                    .frame(width: 36, height: 36)
                                    .background(workDays.contains(day) ? Color.themePrimary : Color.gray.opacity(0.12))
                                    .foregroundStyle(workDays.contains(day) ? .white : Color.themeTextDark)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(footer: Text("Cài đặt này ảnh hưởng đến tính năng điểm danh và báo cáo giờ làm.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Giờ làm việc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save(); dismiss() }.fontWeight(.bold)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let dict: [String: Any] = [
            "startHour": startHour, "startMinute": startMinute,
            "endHour": endHour, "endMinute": endMinute,
            "lateThreshold": lateThresholdMinutes,
            "workDays": Array(workDays)
        ]
        UserDefaults.standard.set(dict, forKey: key)
    }

    private func load() {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) else { return }
        startHour = dict["startHour"] as? Int ?? 8
        startMinute = dict["startMinute"] as? Int ?? 0
        endHour = dict["endHour"] as? Int ?? 17
        endMinute = dict["endMinute"] as? Int ?? 30
        lateThresholdMinutes = dict["lateThreshold"] as? Int ?? 15
        if let days = dict["workDays"] as? [Int] { workDays = Set(days) }
    }
}
