import SwiftUI

struct AlarmRow: View {
    let alarm: Alarm
    let toggle: (Bool) -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.timeText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Label(alarm.title.isEmpty ? "Alarm" : alarm.title, systemImage: "bell.fill")
                    Text(alarm.repeatText)
                    Text(alarm.ringtone.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Toggle("Enabled", isOn: Binding(
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
            .accessibilityLabel("Delete alarm")
        }
        .padding(18)
        .opacity(alarm.isEnabled ? 1 : 0.52)
        .glassCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: alarm.isEnabled)
    }
}
