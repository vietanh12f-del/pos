import SwiftUI

struct WheelTabBarView: View {
    @ObservedObject var tabBarManager: CustomTabBarManager
    @Binding var selectedTab: Int
    @Binding var showNewOrder: Bool
    @Binding var showEditTabBar: Bool
    
    // Rotation State
    @State private var rotation: Double = 0
    @State private var dragOffset: Double = 0
    
    // Configuration
    private let circleRadius: CGFloat = 120 
    private let itemRadius: CGFloat = 120 
    private let visibleHeight: CGFloat = 220 // Increased height to ensure buttons are within frame
    private let iconSize: CGFloat = 44
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2
            // Center the rotation exactly on the FAB
            // FAB is at bottom section
            let centerY = visibleHeight - 50 
            
            ZStack {
                // 1. The Rotating Wheel (Background + Items)
                wheelContent
                    .frame(width: itemRadius * 2, height: itemRadius * 2)
                    .position(x: centerX, y: centerY)
                
                // 2. Floating Action Button
                fabButton
                    .position(x: centerX, y: centerY)
            }
        }
        .frame(height: visibleHeight)
    }
    
    // MARK: - Subviews
    
    private var wheelContent: some View {
        ZStack {
            // Touch Capture Background (Transparent)
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: itemRadius * 2, height: itemRadius * 2)
            
            // Visible Ring (Track) - Visible top half, faded bottom
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0), // Bottom (faded)
                            .init(color: Color.gray.opacity(0.15), location: 0.4), // Start visible near horizon
                            .init(color: Color.gray.opacity(0.15), location: 0.6), // Fully visible top
                            .init(color: .clear, location: 1.0) // Bottom (faded)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 60
                )
                .frame(width: itemRadius * 2, height: itemRadius * 2)
                
            // Spokes
            ForEach(0..<72) { i in
                let angle = Double(i) * 5
                let visualState = getVisualState(for: angle, rotation: rotation + dragOffset)
                
                if visualState.opacity > 0.1 {
                    Rectangle()
                        .fill(Color.gray.opacity(i % 6 == 0 ? 0.2 : 0.1))
                        .frame(width: 2, height: i % 6 == 0 ? 12 : 6)
                        .offset(y: -itemRadius)
                        .rotationEffect(.degrees(angle))
                        .opacity(visualState.opacity)
                }
            }
            
            // Tab Items
            wheelItems
        }
        .rotationEffect(.degrees(rotation + dragOffset))
        .gesture(dragGesture)
    }
    
    private var wheelItems: some View {
        let tabs = tabBarManager.activeTabs
        let totalTabs = tabs.count
        
        return ForEach(0..<12) { i in
            let index = i % totalTabs
            let tab = tabs[index]
            let baseAngle = Double(i) * 30.0 - 90.0
            let visualState = getVisualState(for: baseAngle, rotation: rotation + dragOffset)
            
            if visualState.opacity > 0 {
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = tab.type.tagIndex
                        // Optional: Rotate this item to center when tapped?
                        // For now, just select it.
                    }
                }) {
                    VStack(spacing: 0) {
                        Image(systemName: tab.type.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(selectedTab == tab.type.tagIndex ? Color.themePrimary : Color.gray)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(selectedTab == tab.type.tagIndex ? Color.white : Color.clear)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                            )
                            .scaleEffect(visualState.scale) // Scale effect for "float in/out"
                        
                        if selectedTab == tab.type.tagIndex {
                            Circle()
                                .fill(Color.themePrimary)
                                .frame(width: 4, height: 4)
                                .offset(y: 4)
                        }
                    }
                    .rotationEffect(.degrees(-(rotation + dragOffset + baseAngle)))
                    .contentShape(Rectangle())
                }
                .offset(y: -itemRadius)
                .rotationEffect(.degrees(baseAngle))
                .opacity(visualState.opacity)
                .disabled(visualState.opacity < 0.3) // Disable interaction for faded items
            }
        }
    }
    
    // Helper to calculate opacity and scale based on position relative to top center
    private func getVisualState(for itemAngle: Double, rotation: Double) -> (opacity: Double, scale: CGFloat) {
        // Calculate the absolute angle of the item in the view
        // 0 is right, -90 is top, 90 is bottom, 180 is left
        let currentAngle = itemAngle + rotation
        
        // Normalize deviation from Top (-90 degrees)
        // We want the difference between currentAngle and -90
        let diff = (currentAngle + 90).remainder(dividingBy: 360)
        let dist = abs(diff)
        
        // Config: Visible area is top half (0 to +/- 90 degrees)
        // Fade area is bottom half (+/- 90 to 180 degrees)
        
        // Hard cutoff for visibility at +/- 115 degrees (allow more items on sides)
        if dist > 115 {
            return (0, 0.5)
        }
        
        // Opacity Logic:
        // 0 - 90 degrees: Fully Visible (1.0)
        // 90 - 115 degrees: Quick Fade Out
        var opacity: Double = 1.0
        if dist > 90 {
             let fadeProgress = (dist - 90) / 25 // 0.0 to 1.0 over the 25 degree fade zone
             opacity = 1.0 - fadeProgress
        }
        
        // Scale Logic:
        // Keep scale mostly uniform, slight shrink at edges
        let scale = 1.1 - (0.1 * (dist / 115))
        
        return (opacity, scale)
    }
    
    private var fabButton: some View {
        Button(action: { showNewOrder = true }) {
            ZStack {
                Circle()
                    .fill(Color.themePrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.themePrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .onLongPressGesture {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            showEditTabBar = true
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let sensitivity: Double = 0.6
                let dragAmount = value.translation.width
                let angleChange = (dragAmount / itemRadius) * (180 / 3.14) * sensitivity
                
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = angleChange
                }
            }
            .onEnded { value in
                let sensitivity: Double = 0.6
                let dragAmount = value.translation.width
                let angleChange = (dragAmount / itemRadius) * (180 / 3.14) * sensitivity
                
                let velocity = (value.predictedEndTranslation.width / itemRadius) * (180 / .pi) * 0.3
                let rawEnd = rotation + angleChange + velocity
                
                let snapStep: Double = 30
                let snappedEnd = round(rawEnd / snapStep) * snapStep
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    rotation = snappedEnd
                    dragOffset = 0
                }
            }
    }
    
    // Helper: Position on circle (No longer needed, but kept for reference if needed)
    func positionOnCircle(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = angle * .pi / 180
        let x = center.x + radius * CGFloat(cos(radians))
        let y = center.y + radius * CGFloat(sin(radians))
        return CGPoint(x: x, y: y)
    }
    
    // Helper: Distribute items (No longer needed)
    func angleForIndex(_ index: Int, total: Int) -> Double {
        return 0
    }
    
    // Helper: Check visibility
    func isItemVisible(_ point: CGPoint, in width: CGFloat) -> Bool {
        return point.x >= -20 && point.x <= width + 20 && point.y < 150
    }
}
