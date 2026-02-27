import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    @Binding var showNewOrder: Bool
    @Binding var showNewRestock: Bool
    @Binding var showNewChat: Bool
    @Binding var showNewOperatingExpense: Bool
    @Binding var showAddEmployee: Bool
    
    // Configuration
    private let tabBarHeight: CGFloat = 60
    private let buttonSize: CGFloat = 64
    
    // Computed properties for dynamic button
    private var mainButtonAction: () -> Void {
        switch selectedTab {
        case 3: // Inventory
            return { showNewRestock = true }
        case 5: // Chat
            return { showNewChat = true }
        case 4: // Costs
            return { showNewOperatingExpense = true }
        case 6: // Settings
            return { showAddEmployee = true }
        default: // Home (0), Orders (1), More (8), Others
            return { showNewOrder = true }
        }
    }
    
    private var mainButtonColor: Color {
        switch selectedTab {
        case 3: // Inventory -> Blue/Orange distinctive
            return Color.orange
        case 5: // Chat -> Blue
            return Color.blue
        case 4: // Costs -> Red/Pink
            return Color.red
        case 6: // Settings -> Purple
            return Color.purple
        default: // Standard
            return Color.themePrimary
        }
    }
    
    private var mainButtonIcon: String {
        switch selectedTab {
        case 3: return "arrow.down.doc.fill" // Restock
        case 5: return "square.and.pencil" // New Chat
        case 4: return "banknote.fill" // New Expense
        case 6: return "person.badge.plus.fill" // Add Employee
        default: return "plus" // New Order
        }
    }
    
    private var mainButtonLabel: String {
        switch selectedTab {
        case 3: return "Nhập hàng"
        case 5: return "Tạo Chat"
        case 4: return "Thêm chi phí"
        case 6: return "Thêm NV"
        default: return "Lên đơn"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Tabs
            TabBarButton(icon: "house.fill", title: "Tổng quan", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            .frame(maxWidth: .infinity)
            
            TabBarButton(icon: "clock.arrow.circlepath", title: "Đơn hàng", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            .frame(maxWidth: .infinity)
            
            // Center Plus Button
            ZStack {
                // Outer ring/curve simulation
                Circle()
                    .fill(Color.white) // Match tab bar background
                    .frame(width: buttonSize + 12, height: buttonSize + 12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
                
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    mainButtonAction()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [mainButtonColor, mainButtonColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: mainButtonColor.opacity(0.4), radius: 8, x: 0, y: 4)
                            .overlay(
                                Image(systemName: mainButtonIcon)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(selectedTab == 3 ? 0 : 0)) // Optional animation
                            )
                        
                        // Curved Label
                        // Radius = ButtonRadius (32) + Gap (~16 for visual clearance)
                        CurvedText(text: mainButtonLabel, radius: (buttonSize / 2) + 16, background: mainButtonColor)
                    }
                }
            }
            .offset(y: -24) // Lifted up slightly more
            .frame(width: buttonSize)
            
            // Right Tabs
            TabBarButton(icon: "cube.box.fill", title: "Kho hàng", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
            .frame(maxWidth: .infinity)
            
            TabBarButton(icon: "square.grid.2x2.fill", title: "Thêm", isSelected: [4, 5, 6, 7, 8].contains(selectedTab)) {
                selectedTab = 8
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
        // Dynamic bottom padding: respects safe area automatically
        // We add a small buffer for aesthetics
        .padding(.bottom, 8)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom) // Extend background to bottom edge
        )
    }
}

struct CurvedText: View {
    var text: String
    var radius: CGFloat
    var background: Color
    
    private var spread: Double {
        // Dynamic spread based on text length
        // Approx 9 degrees per character for tighter fit
        return Double(text.count) * 9.0
    }
    
    var body: some View {
        ZStack {
            // Background Arc
            Circle()
                .trim(from: 0, to: (spread + 40) / 360) // Add padding (40 degrees total)
                .stroke(background, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90 - (spread + 40) / 2)) // Center the arc at top
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: background.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Text
            ForEach(Array(text.enumerated()), id: \.offset) { index, letter in
                VStack(spacing: 0) {
                    Text(String(letter))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: -5) // Move up to center vertically in the stroke
                    Spacer()
                }
                .frame(height: radius * 2) // Height = Diameter
                .rotationEffect(angle(at: index, total: text.count))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }
    
    func angle(at index: Int, total: Int) -> Angle {
        let startAngle = -spread / 2
        
        if total == 1 {
            return .degrees(0)
        }
        
        let step = spread / Double(total - 1)
        let currentAngle = startAngle + Double(index) * step
        return .degrees(currentAngle)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Color.themePrimary : Color.gray)
            }
            .frame(height: 50)
        }
    }
}
