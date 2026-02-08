import SwiftUI

struct VoiceOverlayView: View {
    @ObservedObject var viewModel: OrderViewModel
    var bottomPadding: CGFloat = 80
    
    var body: some View {
        if viewModel.speechRecognizer.isRecording || viewModel.isProcessingVoice {
            ZStack(alignment: .bottom) {
                // Dimmed Background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if viewModel.isProcessingVoice {
                            viewModel.cancelVoiceProcessing()
                        } else {
                            viewModel.toggleRecording()
                        }
                    }
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Transcript Area
                    if !viewModel.currentInput.isEmpty {
                        Text(viewModel.currentInput)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(24)
                            .background(Material.ultraThinMaterial)
                            .cornerRadius(24)
                            .shadow(radius: 10)
                            .padding(.horizontal, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if viewModel.isProcessingVoice {
                        Text("Đang xử lý...")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, 10)
                    }
                    
                    // Simple Stop Button
                    Button(action: {
                        if viewModel.isProcessingVoice {
                            viewModel.cancelVoiceProcessing()
                        } else {
                            viewModel.toggleRecording()
                        }
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .shadow(radius: 10)
                                
                                Image(systemName: viewModel.isProcessingVoice ? "xmark" : "stop.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                            }
                            
                            Text(viewModel.isProcessingVoice ? "Hủy" : "Dừng ghi âm")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, bottomPadding)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: viewModel.speechRecognizer.isRecording)
            .animation(.easeInOut, value: viewModel.isProcessingVoice)
        }
    }
}
