import SwiftUI

struct VoiceOverlayView: View {
    @ObservedObject var viewModel: OrderViewModel
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    @State private var orbColor1: Color = .blue
    @State private var orbColor2: Color = .purple
    
    var body: some View {
        if viewModel.speechRecognizer.isRecording || viewModel.isProcessingVoice {
            ZStack(alignment: .bottom) {
                // Dimmed Background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.toggleRecording()
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
                    
                    // Beautiful Bubble / Orb Animation
                    ZStack {
                        // Outer Glow
                        Circle()
                            .fill(
                                RadialGradient(colors: [orbColor1.opacity(0.6), orbColor2.opacity(0.0)], center: .center, startRadius: 0, endRadius: 80)
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .blur(radius: 10)
                        
                        // Core Orb
                        Circle()
                            .fill(
                                LinearGradient(colors: [orbColor1, orbColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: orbColor1.opacity(0.5), radius: 20, x: 0, y: 0)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    }
                    .padding(.bottom, 80)
                    .onAppear {
                        startAnimation()
                    }
                    .onChange(of: viewModel.isProcessingVoice) { isProcessing in
                        if isProcessing {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                                orbColor1 = .orange
                                orbColor2 = .pink
                                scale = 1.3
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever()) {
                                orbColor1 = .blue
                                orbColor2 = .purple
                                scale = 1.1
                            }
                        }
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: viewModel.speechRecognizer.isRecording)
            .animation(.easeInOut, value: viewModel.isProcessingVoice)
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            scale = 1.2
            opacity = 0.8
        }
    }
}
