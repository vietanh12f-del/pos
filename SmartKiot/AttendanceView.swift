import SwiftUI
import Combine

// MARK: - Attendance View

struct AttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AttendanceTab = .checkIn

    enum AttendanceTab: String, CaseIterable {
        case checkIn  = "Điểm danh"
        case history  = "Lịch sử"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(AttendanceTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.white)

                Divider()

                Group {
                    if selectedTab == .checkIn {
                        CheckInView()
                    } else {
                        AttendanceHistoryView()
                    }
                }
                .background(Color.themeBackgroundLight)
            }
            .navigationTitle("Điểm danh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Check-In View

private struct CheckInView: View {
    @State private var currentTime = Date()
    @State private var hasCheckedIn = false
    @State private var hasCheckedOut = false
    @State private var checkInTime: Date? = nil
    @State private var checkOutTime: Date? = nil
    @State private var noteText = ""
    @State private var showNoteInput = false
    @State private var isAnimating = false

    // Camera & selfie
    @State private var showCheckInCamera = false
    @State private var showCheckOutCamera = false
    @State private var checkInSelfie: UIImage? = nil
    @State private var checkOutSelfie: UIImage? = nil
    @State private var checkInSelfieURL: String? = nil
    @State private var checkOutSelfieURL: String? = nil
    @State private var isUploadingSelfie = false
    @State private var todayRecordId: UUID? = nil
    @State private var currentShift: Int = 1
    @State private var showLeaveRequest = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        if hour < 12 { return "Chào buổi sáng" }
        if hour < 18 { return "Chào buổi chiều" }
        return "Chào buổi tối"
    }

    private var userName: String {
        AuthManager.shared.currentUserProfile?.fullName ?? "Nhân viên"
    }

    private var userId: UUID {
        AuthManager.shared.currentUserProfile?.id ?? UUID()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                headerCard

                // Check-in / Check-out buttons
                actionCard

                // Note input
                if showNoteInput {
                    noteCard
                }

                // Today summary
                if hasCheckedIn {
                    todaySummaryCard
                }

                // Button đăng ký nghỉ
                Button {
                    showLeaveRequest = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.title3)
                        Text("Đăng ký nghỉ")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.07))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .onReceive(timer) { _ in currentTime = Date() }
        // Load record hôm nay nếu đã điểm danh trước đó
        .task {
            if let record = try? await SupabaseDatabaseService().fetchTodayAttendance(userId: userId) {
                todayRecordId = record.id
                checkInTime = record.checkInTime
                checkOutTime = record.checkOutTime
                checkInSelfieURL = record.checkInSelfieURL
                checkOutSelfieURL = record.checkOutSelfieURL
                noteText = record.note ?? ""
                hasCheckedIn = record.checkInTime != nil
                hasCheckedOut = record.checkOutTime != nil
                currentShift = record.shift
            }
        }
        // Camera cho check-in (front camera)
        .fullScreenCover(isPresented: $showCheckInCamera) {
            SelfieCameraView { image in
                showCheckInCamera = false
                guard let image else { return }
                checkInSelfie = image
                Task { await uploadAndCheckIn(image: image) }
            }
            .ignoresSafeArea()
        }
        // Camera cho check-out (front camera)
        .fullScreenCover(isPresented: $showCheckOutCamera) {
            SelfieCameraView { image in
                showCheckOutCamera = false
                guard let image else { return }
                checkOutSelfie = image
                Task { await uploadAndCheckOut(image: image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLeaveRequest) {
            LeaveRequestSheet()
        }
    }

    // MARK: Header card

    private var headerCard: some View {
        VStack(spacing: 12) {
            // Avatar hoặc ảnh selfie check-in
            ZStack {
                if let selfie = checkInSelfie {
                    Image(uiImage: selfie)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.green, lineWidth: 2))
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.themePrimary, Color.themePrimary.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                    Text(userName.prefix(1).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                if isUploadingSelfie {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 72, height: 72)
                    ProgressView().tint(.white)
                }
            }

            VStack(spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text(userName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeTextDark)
                if currentShift > 1 {
                    Text("Ca \(currentShift)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.indigo))
                }
            }

            // Live clock
            Text(formatTime(currentTime))
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .foregroundStyle(Color.themeTextDark)
                .monospacedDigit()

            Text(formatDate(currentTime))
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: Action card

    private var actionCard: some View {
        VStack(spacing: 16) {
            if !hasCheckedIn {
                // Check-in button → mở camera trước
                Button {
                    showCheckInCamera = true
                } label: {
                    HStack(spacing: 12) {
                        if isUploadingSelfie {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                        }
                        Text(isUploadingSelfie ? "Đang lưu ảnh..." : "Điểm danh vào")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .scaleEffect(isAnimating ? 0.95 : 1)
                    .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUploadingSelfie)

            } else if !hasCheckedOut {
                // Checked-in status
                HStack(spacing: 10) {
                    if let selfie = checkInSelfie {
                        Image(uiImage: selfie)
                            .resizable().scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Đã điểm danh vào")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        if let t = checkInTime {
                            Text(formatTime(t))
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    if checkInSelfieURL != nil {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.7))
                    }
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)

                // Check-out button → mở camera trước
                Button {
                    showCheckOutCamera = true
                } label: {
                    HStack(spacing: 12) {
                        if isUploadingSelfie {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                        }
                        Text(isUploadingSelfie ? "Đang lưu ảnh..." : "Điểm danh ra")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .scaleEffect(isAnimating ? 0.95 : 1)
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUploadingSelfie)

            } else {
                // Fully checked out
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        if let selfie = checkInSelfie {
                            Image(uiImage: selfie)
                                .resizable().scaledToFill()
                                .frame(width: 32, height: 32).clipShape(Circle())
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        Text("Vào: \(checkInTime.map { formatTime($0) } ?? "—")")
                            .font(.subheadline).foregroundStyle(.green)
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        if let selfie = checkOutSelfie {
                            Image(uiImage: selfie)
                                .resizable().scaledToFill()
                                .frame(width: 32, height: 32).clipShape(Circle())
                        } else {
                            Image(systemName: "arrow.right.circle.fill").foregroundStyle(.blue)
                        }
                        Text("Ra: \(checkOutTime.map { formatTime($0) } ?? "—")")
                            .font(.subheadline).foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .padding(14)
                .background(Color.blue.opacity(0.06))
                .cornerRadius(12)

                Text("Đã hoàn tất điểm danh hôm nay")
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                // Button bắt đầu ca mới
                Button {
                    withAnimation {
                        // Reset state cho ca mới
                        currentShift += 1
                        todayRecordId = nil
                        hasCheckedIn = false
                        hasCheckedOut = false
                        checkInTime = nil
                        checkOutTime = nil
                        checkInSelfie = nil
                        checkOutSelfie = nil
                        checkInSelfieURL = nil
                        checkOutSelfieURL = nil
                        noteText = ""
                        showNoteInput = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bắt đầu ca \(currentShift + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Điểm danh ca làm tiếp theo")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.indigo.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.indigo.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }

            // Note toggle
            if hasCheckedIn {
                Button {
                    withAnimation { showNoteInput.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showNoteInput ? "chevron.up" : "note.text.badge.plus")
                            .font(.caption)
                        Text(showNoteInput ? "Ẩn ghi chú" : "Thêm ghi chú")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.themePrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: Note card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ghi chú")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await saveRecord(checkInTime: checkInTime, checkOutTime: checkOutTime,
                                           checkInURL: checkInSelfieURL, checkOutURL: checkOutSelfieURL) }
                    withAnimation { showNoteInput = false }
                } label: {
                    Text("Lưu")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.themePrimary))
                }
                .buttonStyle(.plain)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Nhập ghi chú (tuỳ chọn)...")
                        .foregroundStyle(.gray.opacity(0.6))
                        .padding(.top, 8).padding(.leading, 4)
                }
                TextEditor(text: $noteText)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
            .padding(10)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(10)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Today summary

    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hôm nay")
                .font(.headline)
                .foregroundStyle(Color.themeTextDark)

            HStack(spacing: 0) {
                summaryTile(
                    label: "Giờ vào",
                    value: checkInTime.map { formatTime($0) } ?? "—",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
                Divider().frame(height: 40)
                summaryTile(
                    label: "Giờ ra",
                    value: checkOutTime.map { formatTime($0) } ?? "—",
                    icon: "arrow.up.circle.fill",
                    color: .blue
                )
                Divider().frame(height: 40)
                summaryTile(
                    label: "Số giờ",
                    value: workedHours,
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func summaryTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.themeTextDark)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var workedHours: String {
        guard let inTime = checkInTime else { return "—" }
        let end = checkOutTime ?? currentTime
        let diff = end.timeIntervalSince(inTime)
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    // MARK: Upload & confirm check-in

    private func uploadAndCheckIn(image: UIImage) async {
        isUploadingSelfie = true
        defer { isUploadingSelfie = false }

        let fileName = "checkin_\(UUID().uuidString)"
        if let data = image.jpegData(compressionQuality: 0.82),
           let url = try? await StorageManager.shared.uploadAttendanceSelfie(
               data: data, userId: userId, fileName: fileName
           ) {
            checkInSelfieURL = url
        }

        let now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAnimating = true
            hasCheckedIn = true
            checkInTime = now
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isAnimating = false }

        // Lưu vào DB
        await saveRecord(checkInTime: now, checkOutTime: nil,
                         checkInURL: checkInSelfieURL, checkOutURL: nil)
    }

    private func uploadAndCheckOut(image: UIImage) async {
        isUploadingSelfie = true
        defer { isUploadingSelfie = false }

        let fileName = "checkout_\(UUID().uuidString)"
        if let data = image.jpegData(compressionQuality: 0.82),
           let url = try? await StorageManager.shared.uploadAttendanceSelfie(
               data: data, userId: userId, fileName: fileName
           ) {
            checkOutSelfieURL = url
        }

        let now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAnimating = true
            hasCheckedOut = true
            checkOutTime = now
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isAnimating = false }

        // Lưu vào DB (upsert — cập nhật record hôm nay)
        await saveRecord(checkInTime: checkInTime, checkOutTime: now,
                         checkInURL: checkInSelfieURL, checkOutURL: checkOutSelfieURL)
    }

    private func saveRecord(checkInTime: Date?, checkOutTime: Date?,
                            checkInURL: String?, checkOutURL: String?) async {
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // Tính status
        let lateHour = 8; let lateMinute = 15
        var status = "checked_in"
        if let inTime = checkInTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: inTime)
            let h = comps.hour ?? 0; let m = comps.minute ?? 0
            if h > lateHour || (h == lateHour && m > lateMinute) { status = "late" }
        }
        if checkOutTime != nil { status = "checked_out" }

        let record = AttendanceRecordDB(
            id: todayRecordId ?? UUID(),
            storeId: storeId,
            userId: userId,
            userName: userName,
            date: today,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            checkInSelfieURL: checkInURL,
            checkOutSelfieURL: checkOutURL,
            note: noteText.isEmpty ? nil : noteText,
            status: status,
            shift: currentShift
        )
        try? await SupabaseDatabaseService().upsertAttendanceRecord(record)
        if todayRecordId == nil { todayRecordId = record.id }
        // Trigger refresh thông báo
        NotificationCenter.default.post(name: .appNotificationShouldRefresh, object: nil)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "EEEE, dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - Attendance History View

private struct AttendanceHistoryView: View {
    // MARK: - Date range
    enum RangeMode: String, CaseIterable {
        case today  = "Hôm nay"
        case week   = "Tuần này"
        case month  = "Tháng này"
        case custom = "Tuỳ chọn"
    }

    @State private var rangeMode: RangeMode = .today
    @State private var customStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showRangePicker = false
    @State private var showCustomDatePicker = false

    @State private var records: [AttendanceRecordDB] = []
    @State private var isLoading = false
    @State private var selectedRecord: AttendanceRecordDB? = nil

    private var userId: UUID {
        AuthManager.shared.currentUserProfile?.id ?? UUID()
    }

    // MARK: - Date interval

    private var dateInterval: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch rangeMode {
        case .today:
            return (cal.startOfDay(for: now),
                    cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now)
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

    private var rangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "dd/MM"
        switch rangeMode {
        case .today:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        case .week:
            let (s, e) = dateInterval
            return "\(df.string(from: s)) – \(df.string(from: e))"
        case .month:
            let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.dateFormat = "MM/yyyy"
            return "Tháng \(f.string(from: Date()))"
        case .custom:
            return "\(df.string(from: customStart)) – \(df.string(from: customEnd))"
        }
    }

    // MARK: - Summary

    private var uniqueDates: Set<String> { Set(records.map { $0.date }) }
    private var presentCount: Int { Set(records.filter { $0.status != "absent" }.map { $0.date }).count }
    private var lateCount: Int    { Set(records.filter { $0.status == "late" }.map { $0.date }).count }

    private var totalWorkedSeconds: TimeInterval {
        records.reduce(0) { sum, r in
            guard let inTime = r.checkInTime, let outTime = r.checkOutTime else { return sum }
            return sum + outTime.timeIntervalSince(inTime)
        }
    }

    private var totalWorkedLabel: String {
        let total = Int(totalWorkedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    private var sortedRecords: [AttendanceRecordDB] {
        records.sorted { $0.date > $1.date || ($0.date == $1.date && $0.shift < $1.shift) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Range selector
                rangeSelector

                if isLoading {
                    ProgressView().padding(40)
                } else if sortedRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.4))
                        Text("Chưa có dữ liệu điểm danh")
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    summaryBar

                    VStack(spacing: 0) {
                        ForEach(sortedRecords) { record in
                            Button { selectedRecord = record } label: {
                                AttendanceRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            if record.id != sortedRecords.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .task { await loadRecords() }
        .onChange(of: rangeMode) { _ in
            if rangeMode == .custom { showCustomDatePicker = true }
            else { Task { await loadRecords() } }
        }
        .sheet(item: $selectedRecord) { record in
            AttendanceDetailSheet(record: record)
        }
        .confirmationDialog("Chọn khoảng thời gian", isPresented: $showRangePicker, titleVisibility: .visible) {
            ForEach(RangeMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) { rangeMode = mode }
            }
            Button("Huỷ", role: .cancel) { }
        }
        .sheet(isPresented: $showCustomDatePicker) {
            NavigationStack {
                Form {
                    Section(header: Text("Chọn khoảng ngày")) {
                        DatePicker("Từ ngày", selection: $customStart, displayedComponents: .date)
                        DatePicker("Đến ngày", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    }
                }
                .navigationTitle("Tuỳ chọn ngày")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Xong") {
                            showCustomDatePicker = false
                            Task { await loadRecords() }
                        }
                        .fontWeight(.bold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") {
                            rangeMode = .today
                            showCustomDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Range selector

    private var rangeSelector: some View {
        Button {
            showRangePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(Color.themePrimary)
                Text(rangeMode.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
                Text("·")
                    .foregroundStyle(.gray)
                Text(rangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            statCell(value: "\(presentCount)", label: "Có mặt", color: .green)
            Divider().frame(height: 40)
            statCell(value: "\(lateCount)", label: "Đi trễ", color: .orange)
            Divider().frame(height: 40)
            statCell(value: totalWorkedLabel, label: "Tổng giờ", color: .blue)
            Divider().frame(height: 40)
            statCell(value: "\(uniqueDates.count)", label: "Tổng ngày", color: Color.themePrimary)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(color)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }
        let (start, end) = dateInterval
        records = (try? await SupabaseDatabaseService().fetchAttendanceRecords(
            userId: userId, from: start, to: end
        )) ?? []
    }
}

// MARK: - Attendance Record Row

struct AttendanceRecordRow: View {
    let record: AttendanceRecordDB

    private var statusColor: Color {
        switch record.status {
        case "late":        return .orange
        case "checked_out": return .blue
        default:            return .green
        }
    }

    private var statusIcon: String {
        switch record.status {
        case "late":        return "clock.badge.exclamationmark.fill"
        case "checked_out": return "arrow.right.circle.fill"
        default:            return "checkmark.circle.fill"
        }
    }

    private var statusLabel: String {
        switch record.status {
        case "late":        return "Đi trễ"
        case "checked_out": return "Đã về"
        default:            return "Đang làm"
        }
    }

    private var workedHours: String? {
        guard let inTime = record.checkInTime, let outTime = record.checkOutTime else { return nil }
        let diff = outTime.timeIntervalSince(inTime)
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(formatDisplayDate(record.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    if record.shift > 1 {
                        Text("Ca \(record.shift)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.indigo))
                    }
                }
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle").font(.caption2).foregroundStyle(.green)
                    Text(record.checkInTime.map { formatTime($0) } ?? "—")
                        .font(.caption).foregroundStyle(.gray)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle").font(.caption2).foregroundStyle(.blue)
                    Text(record.checkOutTime.map { formatTime($0) } ?? "—")
                        .font(.caption).foregroundStyle(.gray)
                }
                if let h = workedHours {
                    Text(h)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.themePrimary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.gray.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDisplayDate(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "vi_VN"); f2.timeZone = .current; f2.dateFormat = "EEE, dd/MM"
        return f2.string(from: date)
    }
}

// MARK: - Attendance Detail Sheet

struct AttendanceDetailSheet: View {
    let record: AttendanceRecordDB
    @Environment(\.dismiss) private var dismiss

    private var statusColor: Color {
        switch record.status {
        case "late":        return .orange
        case "checked_out": return .blue
        default:            return .green
        }
    }

    private var statusLabel: String {
        switch record.status {
        case "late":        return "Đi trễ"
        case "checked_out": return "Đã về"
        default:            return "Đang làm"
        }
    }

    private var workedDuration: String {
        guard let inTime = record.checkInTime, let outTime = record.checkOutTime else { return "—" }
        let diff = outTime.timeIntervalSince(inTime)
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        return String(format: "%d giờ %02d phút", h, m)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text(formatDisplayDate(record.date))
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(Color.themeTextDark)
                        HStack(spacing: 8) {
                            Text(statusLabel)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Capsule().fill(statusColor))
                            if record.shift > 1 {
                                Text("Ca \(record.shift)")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(Capsule().fill(Color.indigo))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                    // Times card
                    VStack(spacing: 0) {
                        timeRow(label: "Giờ vào", time: record.checkInTime, color: .green,
                                icon: "arrow.down.circle.fill")
                        Divider().padding(.leading, 50)
                        timeRow(label: "Giờ ra", time: record.checkOutTime, color: .blue,
                                icon: "arrow.up.circle.fill")
                        Divider().padding(.leading, 50)
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            Text("Số giờ làm").font(.subheadline).foregroundStyle(.gray)
                            Spacer()
                            Text(workedDuration)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.themeTextDark)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                    // Selfie photos
                    if record.checkInSelfieURL != nil || record.checkOutSelfieURL != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ảnh điểm danh")
                                .font(.headline).foregroundStyle(Color.themeTextDark)
                            HStack(spacing: 12) {
                                if let url = record.checkInSelfieURL {
                                    selfieCard(url: url, label: "Vào", color: .green)
                                }
                                if let url = record.checkOutSelfieURL {
                                    selfieCard(url: url, label: "Ra", color: .blue)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                    }

                    // Note
                    if let note = record.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ghi chú", systemImage: "note.text")
                                .font(.headline).foregroundStyle(Color.themeTextDark)
                            Text(note)
                                .font(.subheadline).foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Chi tiết điểm danh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func timeRow(label: String, time: Date?, color: Color, icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color)
            }
            Text(label).font(.subheadline).foregroundStyle(.gray)
            Spacer()
            Text(time.map { formatTime($0) } ?? "—")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(time != nil ? Color.themeTextDark : .gray)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func selfieCard(url: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: url)) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.12)
                        .overlay(ProgressView().scaleEffect(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1.5))

            Text(label)
                .font(.caption).fontWeight(.semibold).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN"); f.timeZone = .current; f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func formatDisplayDate(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "vi_VN"); f2.timeZone = .current
        f2.dateFormat = "EEEE, dd/MM/yyyy"
        return f2.string(from: date).capitalized
    }
}

// MARK: - Leave Request Sheet

struct LeaveRequestSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var leaveDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var leaveType: String = "personal"
    @State private var reason: String = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var myRequests: [LeaveRequest] = []
    @State private var isLoadingHistory = false
    @State private var selectedTab: LeaveTab = .new

    enum LeaveTab: String, CaseIterable {
        case new     = "Đăng ký mới"
        case history = "Lịch sử"
    }

    private let leaveTypes: [(value: String, label: String, icon: String)] = [
        ("personal", "Việc cá nhân",    "person.fill"),
        ("sick",     "Nghỉ bệnh",       "cross.fill"),
        ("annual",   "Nghỉ phép năm",   "calendar"),
        ("other",    "Lý do khác",      "ellipsis.circle.fill"),
    ]

    private var userId: UUID { AuthManager.shared.currentUserProfile?.id ?? UUID() }
    private var userName: String { AuthManager.shared.currentUserProfile?.fullName ?? "Nhân viên" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(LeaveTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 10)
                .background(Color.white)

                Divider()

                if selectedTab == .new {
                    newRequestForm
                } else {
                    historyList
                }
            }
            .background(Color.themeBackgroundLight)
            .navigationTitle("Đăng ký nghỉ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task { await loadHistory() }
            .onChange(of: selectedTab) { t in
                if t == .history { Task { await loadHistory() } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - New request form

    private var newRequestForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date picker
                VStack(alignment: .leading, spacing: 10) {
                    Label("Ngày xin nghỉ", systemImage: "calendar")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    DatePicker("", selection: $leaveDate,
                               in: Calendar.current.date(byAdding: .day, value: 0, to: Date())!...,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color.themePrimary)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                // Leave type
                VStack(alignment: .leading, spacing: 10) {
                    Label("Loại nghỉ", systemImage: "tag.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    VStack(spacing: 8) {
                        ForEach(leaveTypes, id: \.value) { type in
                            Button {
                                leaveType = type.value
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: type.icon)
                                        .foregroundStyle(leaveType == type.value ? Color.themePrimary : .gray)
                                        .frame(width: 20)
                                    Text(type.label)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.themeTextDark)
                                    Spacer()
                                    if leaveType == type.value {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.themePrimary)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(leaveType == type.value
                                    ? Color.themePrimary.opacity(0.07)
                                    : Color.gray.opacity(0.04))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                // Reason
                VStack(alignment: .leading, spacing: 10) {
                    Label("Lý do (tuỳ chọn)", systemImage: "note.text")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.themeTextDark)
                    ZStack(alignment: .topLeading) {
                        if reason.isEmpty {
                            Text("Nhập lý do xin nghỉ...")
                                .foregroundStyle(.gray.opacity(0.6))
                                .padding(.top, 8).padding(.leading, 4)
                        }
                        TextEditor(text: $reason)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(10)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)

                // Submit button
                Button {
                    Task { await submitRequest() }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: showSuccess ? "checkmark.circle.fill" : "paperplane.fill")
                        }
                        Text(showSuccess ? "Đã gửi!" : "Gửi đăng ký")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(showSuccess ? Color.green : Color.themePrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .shadow(color: (showSuccess ? Color.green : Color.themePrimary).opacity(0.35),
                            radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isSaving || showSuccess)
            }
            .padding(.horizontal).padding(.vertical, 16)
        }
    }

    // MARK: - History list

    private var historyList: some View {
        Group {
            if isLoadingHistory {
                VStack { ProgressView(); Spacer() }.padding()
            } else if myRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.gray.opacity(0.4))
                    Text("Chưa có đăng ký nghỉ nào").foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                List {
                    ForEach(myRequests) { req in
                        LeaveRequestRow(request: req)
                            .listRowBackground(Color.white)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func submitRequest() async {
        isSaving = true
        defer { isSaving = false }
        guard let storeId = StoreManager.shared.currentStore?.id else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let request = LeaveRequest(
            storeId: storeId, userId: userId, userName: userName,
            leaveDate: df.string(from: leaveDate),
            leaveType: leaveType,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason,
            status: "pending"
        )
        try? await SupabaseDatabaseService().saveLeaveRequest(request)
        NotificationCenter.default.post(name: .appNotificationShouldRefresh, object: nil)
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccess = false
            selectedTab = .history
            Task { await loadHistory() }
        }
    }

    private func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        myRequests = (try? await SupabaseDatabaseService().fetchLeaveRequests(userId: userId)) ?? []
    }
}

// MARK: - Leave Request Row

private struct LeaveRequestRow: View {
    let request: LeaveRequest

    private var statusColor: Color {
        switch request.status {
        case "approved": return .green
        case "rejected": return .red
        default:         return .orange
        }
    }

    private var statusIcon: String {
        switch request.status {
        case "approved": return "checkmark.circle.fill"
        case "rejected": return "xmark.circle.fill"
        default:         return "clock.fill"
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "vi_VN"); f2.timeZone = .current
        f2.dateFormat = "EEE, dd/MM/yyyy"
        return f2.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: statusIcon).foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(formatDate(request.leaveDate))
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.themeTextDark)
                Text(request.leaveTypeLabel)
                    .font(.caption).foregroundStyle(.gray)
                if let reason = request.reason, !reason.isEmpty {
                    Text(reason).font(.caption).foregroundStyle(.gray).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(request.statusLabel)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(statusColor)
                if let note = request.reviewNote, !note.isEmpty {
                    Text(note).font(.caption2).foregroundStyle(.gray).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Selfie Camera View (front camera)

struct SelfieCameraView: UIViewControllerRepresentable {
    /// Callback: image = ảnh chụp, nil = người dùng huỷ
    let onCapture: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = UIImagePickerController.isCameraDeviceAvailable(.front) ? .front : .rear
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
