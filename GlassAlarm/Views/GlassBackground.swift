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
                    BlobView(color: .cyan.opacity(theme == .dark ? 0.08 : 0.15), size: 400, x: drift ? 0.8 : 0.2, y: drift ? 0.2 : 0.7)
                    BlobView(color: .purple.opacity(theme == .dark ? 0.06 : 0.12), size: 350, x: drift ? 0.1 : 0.9, y: drift ? 0.8 : 0.3)
                    BlobView(color: .blue.opacity(theme == .dark ? 0.05 : 0.1), size: 500, x: drift ? 0.5 : 0.6, y: drift ? 0.1 : 0.9)
                }
                .blur(radius: theme == .dark ? 95 : 80)
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

                    context.stroke(path, with: .color(.white.opacity(theme == .dark ? 0.03 : 0.055)), lineWidth: 1)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var backgroundColors: [Color] {
        switch theme {
        case .light:
            return [Color(red: 0.94, green: 0.96, blue: 1.0), .white]
        case .dark:
            return [Color.black, Color(red: 0.01, green: 0.01, blue: 0.01)]
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
    func glassCard(darkMode: Bool = true) -> some View {
        self
            .background(
                LinearGradient(
                    colors: darkMode
                        ? [Color.white.opacity(0.08), Color.white.opacity(0.02)]
                        : [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(darkMode ? 0.22 : 0.0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(darkMode ? 0.14 : 0.2), lineWidth: darkMode ? 0.6 : 0.7)
            }
            .shadow(color: .black.opacity(darkMode ? 0.45 : 0.28), radius: darkMode ? 22 : 16, x: 0, y: darkMode ? 10 : 8)
    }
}
