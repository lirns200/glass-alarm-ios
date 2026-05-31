import SwiftUI

struct GlassBackground: View {
    let theme: AppTheme
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

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
            return [Color(red: 0.92, green: 0.96, blue: 1.0), Color(red: 0.98, green: 0.94, blue: 0.98), Color(red: 0.88, green: 0.94, blue: 0.93)]
        case .dark:
            return [Color(red: 0.02, green: 0.03, blue: 0.05), Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.10, green: 0.06, blue: 0.11)]
        case .system:
            return [Color(red: 0.10, green: 0.13, blue: 0.18), Color(red: 0.16, green: 0.12, blue: 0.22), Color(red: 0.08, green: 0.18, blue: 0.18)]
        }
    }
}

extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 22, x: 0, y: 12)
    }
}
