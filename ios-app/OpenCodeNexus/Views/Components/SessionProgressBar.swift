import SwiftUI

struct SessionProgressBar: View {
    let isBusy: Bool
    
    @State private var progress: CGFloat = 0
    @State private var animationTimer: Timer?
    
    var body: some View {
        if isBusy {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.interactiveBlue.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.interactiveBlue)
                        .frame(width: geometry.size.width * progress)
                        .animation(.linear(duration: 0.3), value: progress)
                }
                .frame(height: 3)
            }
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
        }
    }
    
    private func startAnimation() {
        animationTimer?.invalidate()
        progress = 0
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress += 0.05
            if progress >= 1 {
                progress = 0
            }
        }
    }
}
