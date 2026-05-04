import SwiftUI
import Combine

// MARK: - Attendance Models (placeholder, logic sẽ làm sau)

struct AttendanceRecord: Identifiable {
    let id: UUID
    let userId: UUID
    let userName: String
    let date: Date
    let checkInTime: Date?
    let checkOutTime: Date?
    let note: String?
    let status: AttendanceStatus

    enum AttendanceStatus {
        case checkedIn, checkedOut, absent, late

        var label: String {
            switch self {
            case .checkedIn:  return "Đang làm"
            case .checkedOut: return "Đã về"
            case .absent:     return "Vắng"
            case .late:       return "Đi trễ"
            }
        }

        var color: Color {
            switch self {
            case .checkedIn:  return .green
            case .checkedOut: return .blue
            case .absent:     return .red
            case .late:       return .orange
            }
        }

        var icon: String {
            switch self {
            case .checkedIn:  return "checkmark.circle.fill"
            case .checkedOut: return "arrow.right.circle.fill"
            case .absent:     return "xmark.circle.fill"
            case .late:       return "clock.badge.exclamationmark.fill"
            }
        }
    }
}

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
                // Tab selector
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
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .onReceive(timer) { _ in currentTime = Date() }
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
            Text("Ghi chú")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.themeTextDark)
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

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAnimating = true
            hasCheckedIn = true
            checkInTime = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
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

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAnimating = true
            hasCheckedOut = true
            checkOutTime = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
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
    @State private var selectedMonth = Date()
    @State private var showMonthPicker = false

    // Placeholder data — sẽ thay bằng data thật sau
    private var sampleRecords: [AttendanceRecord] {
        let cal = Calendar.current
        let today = Date()
        return (0..<14).compactMap { offset -> AttendanceRecord? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let weekday = cal.component(.weekday, from: date)
            if weekday == 1 { // Chủ nhật
                return AttendanceRecord(
                    id: UUID(), userId: UUID(),
                    userName: AuthManager.shared.currentUserProfile?.fullName ?? "Nhân viên",
                    date: date, checkInTime: nil, checkOutTime: nil, note: nil,
                    status: .absent
                )
            }
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour = 8; comps.minute = Int.random(in: 0...30)
            let inTime = cal.date(from: comps) ?? date
            comps.hour = 17; comps.minute = Int.random(in: 0...30)
            let outTime = cal.date(from: comps) ?? date
            let isLate = comps.minute ?? 0 > 15
            return AttendanceRecord(
                id: UUID(), userId: UUID(),
                userName: AuthManager.shared.currentUserProfile?.fullName ?? "Nhân viên",
                date: date, checkInTime: inTime, checkOutTime: outTime, note: nil,
                status: isLate ? .late : .checkedOut
            )
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonth).capitalized
    }

    // Summary stats
    private var totalDays: Int { sampleRecords.count }
    private var presentDays: Int { sampleRecords.filter { $0.status != .absent }.count }
    private var lateDays: Int { sampleRecords.filter { $0.status == .late }.count }
    private var absentDays: Int { sampleRecords.filter { $0.status == .absent }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month selector
                monthSelector

                // Summary bar
                summaryBar

                // Records list
                VStack(spacing: 0) {
                    ForEach(sampleRecords) { record in
                        AttendanceRecordRow(record: record)
                        if record.id != sampleRecords.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }

    // MARK: Month selector

    private var monthSelector: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(Color.themePrimary)
                    .padding(10)
                    .background(Circle().fill(Color.themePrimary.opacity(0.1)))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showMonthPicker = true
            } label: {
                Text(monthLabel)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.themePrimary)
                    .padding(10)
                    .background(Circle().fill(Color.themePrimary.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Summary bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            statCell(value: "\(presentDays)", label: "Có mặt", color: .green)
            Divider().frame(height: 40)
            statCell(value: "\(lateDays)", label: "Đi trễ", color: .orange)
            Divider().frame(height: 40)
            statCell(value: "\(absentDays)", label: "Vắng", color: .red)
            Divider().frame(height: 40)
            statCell(value: "\(totalDays)", label: "Tổng ngày", color: Color.themePrimary)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Attendance Record Row

private struct AttendanceRecordRow: View {
    let record: AttendanceRecord

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.timeZone = .current
        f.dateFormat = "EEE, dd/MM"
        return f.string(from: date)
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
            // Status icon
            ZStack {
                Circle()
                    .fill(record.status.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: record.status.icon)
                    .font(.subheadline)
                    .foregroundStyle(record.status.color)
            }

            // Date + status
            VStack(alignment: .leading, spacing: 3) {
                Text(formatDate(record.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.themeTextDark)
                Text(record.status.label)
                    .font(.caption)
                    .foregroundStyle(record.status.color)
            }

            Spacer()

            // Times
            if record.status != .absent {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle").font(.caption2).foregroundStyle(.green)
                        Text(record.checkInTime.map { formatTime($0) } ?? "—")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle").font(.caption2).foregroundStyle(.blue)
                        Text(record.checkOutTime.map { formatTime($0) } ?? "—")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    if let hours = workedHours {
                        Text(hours)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.themePrimary)
                    }
                }
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
