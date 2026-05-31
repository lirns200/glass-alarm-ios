import SwiftUI

struct AlarmRow: View {
    let alarm: Alarm
    let toggle: (Bool) -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeText)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    
                    if alarm.isEnabled {
                        Text(alarm.timeUntilText)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Label(alarm.title.isEmpty ? "Будильник" : alarm.title, systemImage: "bell.fill")
                    Text(alarm.repeatText)
                    Text(alarm.ringtone.title)
                    if alarm.vibrates {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            }

            Spacer()

            Toggle("Включен", isOn: Binding(
                get: { alarm.isEnabled },
                set: { toggle($0) }
            ))
            .labelsHidden()

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.headline)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Удалить")
        }
        .padding(18)
        .opacity(alarm.isEnabled ? 1 : 0.52)
        .glassCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: alarm.isEnabled)
    }
}
