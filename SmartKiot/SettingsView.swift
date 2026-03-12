import SwiftUI
import Supabase
import Combine

struct SettingsView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @Binding var isTabBarVisible: Bool
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showEditProfile = false
    @State private var feedbackText: String = ""
    @State private var isSubmittingFeedback: Bool = false
    @State private var feedbackStatus: String?
    private let database = SupabaseDatabaseService()
    @FocusState private var feedbackFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: authManager.selectedRole == "owner" ? "crown.fill" : "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(Color.themePrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chế độ đăng nhập")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(authManager.selectedRole == "owner" ? "Chủ cửa hàng" : "Nhân viên")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        if authManager.selectedRole == "employee" {
                            let pos = storeManager.currentMember?.positionTitle
                            Text("Chức vụ: \(pos ?? "—")")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    Text("Đang hoạt động")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                }
                .padding(.vertical, 4)
            }
            Section(header: Text("Cửa hàng hiện tại")) {
                    if let store = storeManager.currentStore {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.name)
                                    .font(.headline)
                            }
                            Spacer()
                            Button("Chuyển") {
                                storeManager.currentStore = nil // Triggers StoreSelectionView in ContentView
                            }
                        }
                        
                        if storeManager.hasPermission(.manageEmployees) {
                             NavigationLink(destination: EmployeeManagementView(tabBarManager: tabBarManager)) {
                                Text("Quản lý nhân viên")
                            }
                        }
                        
                        if storeManager.currentMember?.role == .owner && authManager.selectedRole == "owner" {
                            NavigationLink(destination: StoreBankSettingsView(store: store)) {
                                Text("Cài đặt tài khoản ngân hàng")
                            }
                        }
                        
                        if storeManager.hasPermission(.viewCustomization) {
                            NavigationLink(destination: CustomizationSettingsView()) {
                                Text("Tuỳ chỉnh")
                            }
                        }
                    } else {
                         Button("Chọn cửa hàng") {
                             // This case might be rare as ContentView handles it, but good fallback
                         }
                    }
                }

                Section(header: Text("Tài khoản")) {
                    if let profile = authManager.currentUserProfile {
                        HStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(Text(profile.fullName.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(.gray))
                            
                            VStack(alignment: .leading) {
                                Text(profile.fullName)
                                    .font(.headline)
                                Text(profile.phoneNumber ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                if let email = profile.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: { showEditProfile = true }) {
                            Text("Chỉnh sửa hồ sơ")
                        }
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await authManager.signOut()
                        }
                    } label: {
                        HStack {
                            Text("Đăng xuất")
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                Section(header: Text("Ứng dụng")) {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.gray)
                    }
                    
                    Section(header: Text("Góp ý & Hỗ trợ")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ý kiến đóng góp")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            TextEditor(text: $feedbackText)
                                .frame(minHeight: 100)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                                .focused($feedbackFocused)
                            if let status = feedbackStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Button {
                                isSubmittingFeedback = true
                                let fb = UserFeedback(
                                    id: UUID(),
                                    content: feedbackText,
                                    createdAt: Date(),
                                    userId: SupabaseConfig.client.auth.currentUser?.id,
                                    storeId: StoreManager.shared.currentStore?.id
                                )
                                Task {
                                    do {
                                        try await database.saveUserFeedback(fb)
                                        await MainActor.run {
                                            feedbackStatus = "Đã gửi góp ý. Cảm ơn bạn!"
                                            feedbackText = ""
                                            isSubmittingFeedback = false
                                            hideKeyboard()
                                            isTabBarVisible = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            feedbackStatus = "Gửi góp ý thất bại. Thử lại sau."
                                            isSubmittingFeedback = false
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if isSubmittingFeedback {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Gửi góp ý")
                                        .fontWeight(.bold)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSubmittingFeedback || feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Liên hệ hỗ trợ")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("0879855898")
                                Spacer()
                                Button("Gọi") {
                                    if let url = URL(string: "tel://0879855898") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                Section(header: Text("Thông báo")) {
                    Toggle("Bật âm báo tin nhắn", isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: NotificationManager.soundKey) as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: NotificationManager.soundKey) }
                    ))
                    Toggle("Bật thông báo", isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: NotificationManager.notificationsKey) as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: NotificationManager.notificationsKey) }
                    ))
                    Toggle("Hiện banner trong ứng dụng", isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: NotificationManager.bannerKey) as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: NotificationManager.bannerKey) }
                    ))
                    Button("Cho phép quyền thông báo") {
                        NotificationManager.shared.configure()
                        UNUserNotificationCenter.current().getNotificationSettings { settings in
                            if settings.authorizationStatus == .notDetermined {
                                NotificationManager.shared.configure()
                            }
                        }
                    }
                }
                
            }
            .navigationTitle("Cài đặt")
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    EditProfileView(authManager: authManager)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: feedbackFocused) { focused in
                withAnimation {
                    isTabBarVisible = !focused
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: keyboardHeight)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
                if let rect = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) {
                    keyboardHeight = rect.height
                } else {
                    keyboardHeight = 300 // fallback
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

struct StoreBankSettingsView: View {
    let store: Store
    @State private var bankName: String
    @State private var bankAccountNumber: String
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    // Supported Banks (Common VietQR Banks)
    private static let supportedBanks = [
        "Vietcombank (VCB)", "Techcombank (TCB)", "MBBank (MB)", "ACB", "VPBank (VPB)",
        "BIDV", "VietinBank (CTG)", "TPBank (TPB)", "Sacombank (STB)", "HDBank (HDB)",
        "Agribank (VBA)", "VIB", "MSB", "SHB", "OCB", "SeABank (SEAB)", "Eximbank (EIB)",
        "LienVietPostBank (LPB)", "Nam A Bank (NAMAB)", "Shinhan Bank (SHBVN)",
        "VietCapital Bank (BVB)", "NCB", "KienLongBank (KLB)", "Vietbank (VBB)", "OceanBank (OJB)",
        "GPBank (GPB)", "Public Bank (PBVN)", "HongLeong Bank (HLBVN)", "Standard Chartered (SCVN)",
        "CIMB", "UOB", "HSBC", "Woori Bank (WVN)", "Indovina Bank (IVB)", "DongA Bank (DOB)", "SaigonBank (SGB)",
        "PVComBank (PVC)", "ABBank (ABB)", "BaoViet Bank (BVB)", "PGBank (PGB)", "Vietnam - Russia Bank (VRB)"
    ].sorted()
    
    init(store: Store) {
        self.store = store
        // Ensure default value exists in the list to avoid Picker selection error
        let savedBank = store.bankName ?? ""
        if !savedBank.isEmpty && StoreBankSettingsView.supportedBanks.contains(savedBank) {
            _bankName = State(initialValue: savedBank)
        } else {
             // If saved bank is invalid or empty, default to VCB or first available
            _bankName = State(initialValue: "Vietcombank (VCB)")
        }
        _bankAccountNumber = State(initialValue: store.bankAccountNumber ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Thông tin nhận tiền (VietQR)")) {
                Picker("Ngân hàng", selection: $bankName) {
                    ForEach(StoreBankSettingsView.supportedBanks, id: \.self) { bank in
                        Text(bank).tag(bank)
                    }
                }
                .pickerStyle(.navigationLink) // Better for long lists
                    TextField("Số tài khoản", text: $bankAccountNumber)
                        .keyboardType(.asciiCapableNumberPad) // Better for account numbers
            }
            
            Section(header: Text("Lưu ý"), footer: Text("Thông tin này sẽ được sử dụng để tạo mã QR thanh toán trên hóa đơn.")) {
                 // Info section or empty
            }
        }
        .navigationTitle("Cài đặt ngân hàng")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu", action: save)
                    .disabled(isLoading || bankAccountNumber.isEmpty)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Xong") {
                    hideKeyboard()
                }
            }
        }

        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }
    
    func save() {
        isLoading = true
        Task {
            do {
                // Update in Supabase
                try await StoreManager.shared.updateStoreBankInfo(storeId: store.id, bankName: bankName, accountNumber: bankAccountNumber)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error saving bank info: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct CustomizationSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: PriceSettingsView()) {
                    Text("Khoảng cách giá")
                }
                NavigationLink(destination: ReceiptHeaderSettingsView()) {
                    Text("Tên cửa hàng trên hoá đơn")
                }
                NavigationLink(destination: VATSettingsView()) {
                    Text("Cài đặt VAT")
                }
            }
        }
        .navigationTitle("Tuỳ chỉnh")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PriceSettingsView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selectedStep: Int
    @Environment(\.dismiss) var dismiss
    
    init() {
        let initial = StoreManager.shared.priceStep
        _selectedStep = State(initialValue: initial)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Khoảng cách giá (đ)")) {
                Picker("", selection: $selectedStep) {
                    ForEach(Array(stride(from: 1000, through: 200_000, by: 1000)), id: \.self) { v in
                        Text("\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                Text("Áp dụng cho các bánh xe chỉnh giá")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .navigationTitle("Khoảng cách giá")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    storeManager.setPriceStep(selectedStep)
                    dismiss()
                }
            }
        }
    }
}

struct ReceiptHeaderSettingsView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @StateObject private var speech = SpeechRecognizer()
    @State private var line1: String = ""
    @State private var line2: String = ""
    @State private var line3: String = ""
    @State private var line4: String = ""
    @State private var activeField: Int? = nil
    
    init() {
        if let storeId = StoreManager.shared.currentStore?.id {
            let lines = StoreManager.shared.receiptHeaderLines(for: storeId)
            _line1 = State(initialValue: lines.count > 0 ? lines[0] : "")
            _line2 = State(initialValue: lines.count > 1 ? lines[1] : "")
            _line3 = State(initialValue: lines.count > 2 ? lines[2] : "")
            _line4 = State(initialValue: lines.count > 3 ? lines[3] : "")
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Tên cửa hàng hiển thị trên hoá đơn")) {
                HStack {
                    TextField("Ví dụ: Cửa Hàng Hoa Tươi", text: $line1)
                    Button {
                        toggleRecording(for: 1)
                    } label: {
                        Image(systemName: speech.isRecording && activeField == 1 ? "waveform" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    TextField("Ví dụ: ĐẠI THẮNG", text: $line2)
                    Button {
                        toggleRecording(for: 2)
                    } label: {
                        Image(systemName: speech.isRecording && activeField == 2 ? "waveform" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    TextField("Ví dụ: SĐT: 0834926779", text: $line3)
                    Button {
                        toggleRecording(for: 3)
                    } label: {
                        Image(systemName: speech.isRecording && activeField == 3 ? "waveform" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    TextField("Ví dụ: Đ/C: 8/7N Nguyễn Thị Sóc...", text: $line4)
                    Button {
                        toggleRecording(for: 4)
                    } label: {
                        Image(systemName: speech.isRecording && activeField == 4 ? "waveform" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Text("Bạn có thể nhập bằng giọng nói cho từng dòng.")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .navigationTitle("Tên cửa hàng")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    save()
                    dismiss()
                }
                .disabled(storeManager.currentStore == nil)
            }
        }
        .onReceive(speech.$transcript) { t in
            guard let idx = activeField, !t.isEmpty else { return }
            let spoken = t.trimmingCharacters(in: .whitespacesAndNewlines)
            switch idx {
            case 1: line1 = spoken
            case 2: line2 = spoken
            case 3: line3 = spoken
            case 4: line4 = spoken
            default: break
            }
        }
        .onReceive(speech.$isRecording.dropFirst()) { rec in
            if !rec {
                activeField = nil
            }
        }
    }
    
    private func toggleRecording(for field: Int) {
        if speech.isRecording {
            speech.stopRecording()
            activeField = nil
        } else {
            activeField = field
            do {
                try speech.startRecording()
            } catch { }
        }
    }
    
    private func save() {
        guard let storeId = storeManager.currentStore?.id else { return }
        storeManager.setReceiptHeaderLines(storeId: storeId, line1: line1, line2: line2, line3: line3, line4: line4)
    }
}

struct VATSettingsView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var enabled: Bool = false
    @State private var rateText: String = "10"
    
    init() {
        if let storeId = StoreManager.shared.currentStore?.id {
            let e = StoreManager.shared.vatEnabled(for: storeId)
            let r = StoreManager.shared.vatRate(for: storeId)
            _enabled = State(initialValue: e)
            _rateText = State(initialValue: String(format: "%.0f", r))
        }
    }
    
    var rateValue: Double {
        Double(rateText) ?? 0
    }
    
    var body: some View {
        Form {
            Section(header: Text("VAT trong hoá đơn")) {
                Toggle("Bật VAT", isOn: $enabled)
                HStack {
                    Text("VAT (%)")
                    Spacer()
                    TextField("0–50", text: $rateText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                Text("Nếu tắt, hoá đơn chỉ hiển thị Tổng cộng.")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .navigationTitle("Cài đặt VAT")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    save()
                    dismiss()
                }
                .disabled(storeManager.currentStore == nil)
            }
        }
    }
    
    private func save() {
        guard let storeId = storeManager.currentStore?.id else { return }
        storeManager.setVATSettings(storeId: storeId, enabled: enabled, rate: rateValue)
    }
}
struct EditProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var address: String
    
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        let fallbackUser = SupabaseConfig.client.auth.currentUser
        let initialName: String = {
            if let n = authManager.currentUserProfile?.fullName, !n.isEmpty { return n }
            if case let .string(n)? = fallbackUser?.userMetadata["full_name"] { return n }
            return ""
        }()
        let initialEmail: String = {
            if let e = authManager.currentUserProfile?.email, !e.isEmpty { return e }
            return fallbackUser?.email ?? ""
        }()
        _name = State(initialValue: initialName)
        _email = State(initialValue: initialEmail)
        _address = State(initialValue: authManager.currentUserProfile?.address ?? "")
    }
    
    var body: some View {
            Form {
                Section(header: Text("Thông tin cá nhân")) {
                    TextField("Họ và tên", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Địa chỉ", text: $address)
                }
            }
            .navigationTitle("Chỉnh sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            let success = await authManager.updateProfile(name: name, email: email, address: address)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.isEmpty || authManager.isLoading)
                }
            }
            .overlay {
                if authManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
        }
    }
