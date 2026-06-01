import SwiftUI

struct GlassBackground: View {
    let theme: AppTheme
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Оптимизированные пузыри (меньше блюра, нет TimelineView для экономии батареи)
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(theme == .dark ? 0.1 : 0.2))
                        .frame(width: 300)
                        .offset(x: drift ? 50 : -50, y: drift ? -100 : 100)
                    
                    Circle()
                        .fill(Color.purple.opacity(theme == .dark ? 0.08 : 0.15))
                        .frame(width: 250)
                        .offset(x: drift ? -80 : 80, y: drift ? 150 : -150)
                }
                .blur(radius: 60) // Уменьшен радиус блюра (был 95)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }

            // Статическая сетка вместо Canvas (Canvas + TimelineView сильно греет телефон)
            GridPattern()
                .stroke(.white.opacity(theme == .dark ? 0.04 : 0.07), lineWidth: 0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var backgroundColors: [Color] {
        switch theme {
        case .light:
            return [Color(red: 0.95, green: 0.97, blue: 1.0), .white]
        case .dark:
            return [Color.black, Color(red: 0.02, green: 0.02, blue: 0.02)]
        case .system:
            return [Color(red: 0.05, green: 0.05, blue: 0.05), .black]
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40
        
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

extension View {
    func glassCard(darkMode: Bool = true) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(darkMode ? 0.15 : 0.25), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
