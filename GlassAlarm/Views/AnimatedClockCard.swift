import SwiftUI

struct AnimatedClockCard: View {
    let nextAlarm: Alarm?
    @State private var pulse = false
    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), lineWidth: 22)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0.05, to: 0.82)
                    .stroke(
                        AngularGradient(colors: [.cyan, .indigo, .pink, .cyan], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .cyan.opacity(0.28), radius: 18)

                Circle()
                    .stroke(.white.opacity(0.26), lineWidth: 1)
                    .frame(width: pulse ? 160 : 138, height: pulse ? 160 : 138)
                    .opacity(pulse ? 0.2 : 0.72)

                VStack(spacing: 4) {
                    Text(nextAlarm?.timeText ?? "--:--")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(nextAlarm == nil ? "Нет активных" : "Следующий")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            VStack(spacing: 4) {
                Text(nextAlarm?.repeatText ?? "Нажмите +, чтобы создать")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                if let nextAlarm {
                    Text(nextAlarm.timeUntilText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassCard()
        .onAppear {
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
