import SwiftUI

enum Brand {
    static let name = "OpencodeNexus"
    static let tagline = "Connect. Coordinate. Conquer."
}

struct NexusBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color(red: 58.0 / 255.0, green: 63.0 / 255.0, blue: 70.0 / 255.0), .black],
                        center: .init(x: 0.5, y: 0.42),
                        startRadius: 12,
                        endRadius: 90
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.92), lineWidth: 4)
                .frame(width: 74, height: 74)

            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
                .foregroundStyle(Theme.textBase.opacity(0.8))
                .frame(width: 48, height: 48)

            Path { path in
                path.move(to: CGPoint(x: 30, y: 30))
                path.addLine(to: CGPoint(x: 70, y: 70))
                path.move(to: CGPoint(x: 70, y: 30))
                path.addLine(to: CGPoint(x: 30, y: 70))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .shadow(color: .white.opacity(0.16), radius: 4)

            ForEach([Angle.degrees(0), .degrees(45), .degrees(90), .degrees(135)], id: \.self) { angle in
                Capsule(style: .continuous)
                    .fill(Theme.textBase.opacity(0.88))
                    .frame(width: 3, height: 14)
                    .offset(y: -47)
                    .rotationEffect(angle)
            }

            ForEach(Array([
                CGPoint(x: 50, y: 3),
                CGPoint(x: 50, y: 97),
                CGPoint(x: 3, y: 50),
                CGPoint(x: 97, y: 50)
            ].enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .position(point)
            }
        }
        .frame(width: 100, height: 100)
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        .accessibilityHidden(true)
    }
}
