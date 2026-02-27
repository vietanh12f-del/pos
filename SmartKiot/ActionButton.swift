import SwiftUI

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String, color: Color = .black, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 50, height: 50).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                }
                Text(title).font(.caption).fontWeight(.bold).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
