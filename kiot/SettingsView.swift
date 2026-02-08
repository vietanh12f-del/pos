import SwiftUI

struct SettingsView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showEditProfile = false
    
    var body: some View {
        List {
            Section(header: Text("Cửa hàng")) {
                    if let store = storeManager.currentStore {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.name)
                                    .font(.headline)
                                if let role = storeManager.currentMember?.role {
                                    Text(role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
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
                        
                        if storeManager.currentMember?.role == .owner {
                            NavigationLink(destination: StoreBankSettingsView(store: store)) {
                                Text("Cài đặt tài khoản ngân hàng")
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
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showEditProfile) {
                NavigationView {
                    EditProfileView(authManager: authManager)
                }
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
                .pickerStyle(.automatic) // Better for long lists
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

struct EditProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var address: String
    
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        _name = State(initialValue: authManager.currentUserProfile?.fullName ?? "")
        _email = State(initialValue: authManager.currentUserProfile?.email ?? "")
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

