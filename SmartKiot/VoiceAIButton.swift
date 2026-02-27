import SwiftUI

// MARK: - Voice AI Button
struct VoiceAIButton: View {
    @ObservedObject var viewModel: OrderViewModel
    var size: CGFloat = 64
    
    var body: some View {
        let isActiveRecording = viewModel.speechRecognizer.isRecording && !viewModel.isRecordingCustomerName
        Button(action: { viewModel.toggleRecording() }) {
            ZStack {
                
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isActiveRecording ? [.red, .orange] : [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: (isActiveRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, x: 0, y: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                
                Image(systemName: isActiveRecording ? "waveform" : "mic.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: isActiveRecording)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }
}
