import SwiftUI

// MARK: - Voice AI Button
struct VoiceAIButton: View {
    @ObservedObject var viewModel: OrderViewModel
    var size: CGFloat = 64
    
    var body: some View {
        Button(action: { viewModel.toggleRecording() }) {
            ZStack {
                // Outer Glow / Pulse
                if viewModel.speechRecognizer.isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.5), .blue.opacity(0.0)],
                                center: .center,
                                startRadius: size * 0.5,
                                endRadius: size * 1.5
                            )
                        )
                        .frame(width: size * 2.5, height: size * 2.5)
                        .scaleEffect(viewModel.speechRecognizer.isRecording ? 1.1 : 0.8)
                        .opacity(viewModel.speechRecognizer.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.speechRecognizer.isRecording)
                }
                
                // Main Button Background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: viewModel.speechRecognizer.isRecording ? [.red, .orange] : [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: (viewModel.speechRecognizer.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, x: 0, y: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                
                // Icon
                if #available(iOS 17.0, *) {
                    Image(systemName: viewModel.speechRecognizer.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: viewModel.speechRecognizer.isRecording)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image(systemName: viewModel.speechRecognizer.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
