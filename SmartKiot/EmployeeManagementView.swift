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
                                    HStack(spacing: 4) {
                                        Image(systemName: employeeType == "parttime" ? "clock.badge.questionmark" : "briefcase.fill")
                                            .font(.caption2)
                                        Text(employeeType == "parttime" ? "Part-time" : "Chính thức")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundStyle(employeeType == "parttime" ? Color.orange : Color.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(
                                        (employeeType == "parttime" ? Color.orange : Color.green).opacity(0.12)
                                    ))
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
            latestAttendance = try? await SupabaseDatabaseService().fetchTodayAttendance(userId: member.userId)
        }
        .sheet(isPresented: $showSalarySheet) {
            EmployeeSalarySheet(memberId: member.id, memberName: name)
        }
        .sheet(isPresented: $showAttendanceReport) {
            EmployeeAttendanceReport(memberId: member.userId, memberName: name)
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
