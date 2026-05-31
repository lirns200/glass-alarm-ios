import SwiftUI

struct GlassBackground: View {
    let theme: AppTheme
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Анимированные "пузыри" для дорогого вида
            GeometryReader { proxy in
                ZStack {
                    BlobView(color: .cyan.opacity(0.15), size: 400, x: drift ? 0.8 : 0.2, y: drift ? 0.2 : 0.7)
                    BlobView(color: .purple.opacity(0.12), size: 350, x: drift ? 0.1 : 0.9, y: drift ? 0.8 : 0.3)
                    BlobView(color: .blue.opacity(0.1), size: 500, x: drift ? 0.5 : 0.6, y: drift ? 0.1 : 0.9)
                }
                .blur(radius: 80)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let seconds = timeline.date.timeIntervalSinceReferenceDate
                    let spacing: CGFloat = 34
                    var path = Path()

                    for x in stride(from: -spacing, through: size.width + spacing, by: spacing) {
                        let offset = sin(seconds * 0.45 + Double(x) * 0.02) * 8
                        path.move(to: CGPoint(x: x + offset, y: 0))
                        path.addLine(to: CGPoint(x: x - offset, y: size.height))
                    }

                    for y in stride(from: -spacing, through: size.height + spacing, by: spacing) {
                        let offset = cos(seconds * 0.38 + Double(y) * 0.018) * 8
                        path.move(to: CGPoint(x: 0, y: y + offset))
                        path.addLine(to: CGPoint(x: size.width, y: y - offset))
                    }

                    context.stroke(path, with: .color(.white.opacity(0.055)), lineWidth: 1)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var backgroundColors: [Color] {
        switch theme {
        case .light:
            return [.white, .white]
        case .dark:
            return [.black, .black]
        case .system:
            return [Color(red: 0.05, green: 0.05, blue: 0.05), .black]
        }
    }
}

struct BlobView: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(
                x: UIScreen.main.bounds.width * x,
                y: UIScreen.main.bounds.height * y
            )
    }
}

extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
