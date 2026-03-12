import SwiftUI

struct ProductionManagementView: View {
    @ObservedObject var viewModel: OrderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMode: Mode? = .nhapNguyenLieu
    @State private var showMaterialEntry = false
    @State private var materialTab: Int = 0
    @State private var searchText: String = ""
    
    enum Mode: String, CaseIterable {
        case nhapNguyenLieu = "Nhập Nguyên liệu"
        case xuatNguyenLieu = "Xuất Nguyên liệu"
        case nhapThanhPham = "Nhập Thành Phẩm"
        case xuatThanhPham = "Xuất Thành Phẩm"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Tiles
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Button {
                            selectedMode = m
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: icon(for: m))
                                    .font(.title2)
                                    .foregroundStyle(selectedMode == m ? Color.white : Color.themePrimary)
                                Text(m.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(selectedMode == m ? Color.white : Color.themeTextDark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(selectedMode == m ? Color.themePrimary : Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.08), radius: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedMode == m ? Color.themePrimary : Color.gray.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                if let mode = selectedMode {
                    VStack(spacing: 12) {
                        Picker("Chế độ", selection: $materialTab) {
                            Text(leftTitle(for: mode)).tag(0)
                            Text(rightTitle(for: mode)).tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if materialTab == 0 {
                            VStack(spacing: 16) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                Text("Chưa có dữ liệu")
                                    .font(.headline)
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                Text("Chưa có lịch sử")
                                    .font(.headline)
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                        }
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
            }
            .navigationTitle("Quản Lý Sản Xuất")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .sheet(isPresented: $showMaterialEntry) {
                let mode = selectedMode ?? .nhapNguyenLieu
                RestockEntryView(
                    viewModel: viewModel,
                    titleText: centerButtonTitle(for: mode),
                    summaryTitle: summaryTitle(for: mode),
                    useInventoryList: false,
                    onComplete: { items in
                        viewModel.completeProductionTransaction(mode: centerButtonTitle(for: mode))
                    }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if let mode = selectedMode {
                    Button {
                        showMaterialEntry = true
                    } label: {
                        Text(centerButtonTitle(for: mode))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themePrimary)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    func icon(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "tray.and.arrow.down.fill"
        case .xuatNguyenLieu: return "tray.and.arrow.up.fill"
        case .nhapThanhPham: return "shippingbox.and.arrow.down.fill"
        case .xuatThanhPham: return "shippingbox.and.arrow.up.fill"
        }
    }
    func leftTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Nguyên liệu"
        case .xuatNguyenLieu: return "Nguyên liệu"
        case .nhapThanhPham: return "Thành phẩm"
        case .xuatThanhPham: return "Thành phẩm"
        }
    }
    func rightTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Lịch sử nhập"
        case .xuatNguyenLieu: return "Lịch sử xuất"
        case .nhapThanhPham: return "Lịch sử nhập"
        case .xuatThanhPham: return "Lịch sử xuất"
        }
    }
    func centerButtonTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Nhập nguyên liệu"
        case .xuatNguyenLieu: return "Xuất nguyên liệu"
        case .nhapThanhPham: return "Nhập thành phẩm"
        case .xuatThanhPham: return "Xuất thành phẩm"
        }
    }
    func summaryTitle(for mode: Mode) -> String {
        switch mode {
        case .nhapNguyenLieu: return "Tóm tắt nhập nguyên liệu"
        case .xuatNguyenLieu: return "Tóm tắt xuất nguyên liệu"
        case .nhapThanhPham: return "Tóm tắt nhập thành phẩm"
        case .xuatThanhPham: return "Tóm tắt xuất thành phẩm"
        }
    }
}
