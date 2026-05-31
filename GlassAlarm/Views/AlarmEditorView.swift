import SwiftUI

struct AlarmEditorView: View {
    enum Mode {
        case create
        case edit(Alarm)

        var title: String {
            switch self {
            case .create: return "Новый будильник"
            case .edit: return "Изменить"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue

    let mode: Mode
    let save: (Alarm) -> Void

    @State private var title: String
    @State private var time: Date
    @State private var repeatDays: Set<Weekday>
    @State private var ringtone: AlarmRingtone
    @State private var vibrates: Bool
    @State private var isEnabled: Bool

    private let originalID: UUID?

    init(mode: Mode, save: @escaping (Alarm) -> Void) {
        self.mode = mode
        self.save = save

        switch mode {
        case .create:
            let defaultRingtoneRaw = UserDefaults.standard.string(forKey: AppSettingsKeys.defaultRingtone) ?? AlarmRingtone.crystal.rawValue
            let defaultRingtone = AlarmRingtone(rawValue: defaultRingtoneRaw) ?? .crystal
            let defaultVibration = UserDefaults.standard.object(forKey: AppSettingsKeys.defaultVibration) as? Bool ?? true

            _title = State(initialValue: "Будильник")
            _time = State(initialValue: .now.addingTimeInterval(3600))
            _repeatDays = State(initialValue: [])
            _ringtone = State(initialValue: defaultRingtone)
            _vibrates = State(initialValue: defaultVibration)
            _isEnabled = State(initialValue: true)
            originalID = nil
        case .edit(let alarm):
            _title = State(initialValue: alarm.title)
            _time = State(initialValue: alarm.time)
            _repeatDays = State(initialValue: alarm.repeatDays)
            _ringtone = State(initialValue: alarm.ringtone)
            _vibrates = State(initialValue: alarm.vibrates)
            _isEnabled = State(initialValue: alarm.isEnabled)
            originalID = alarm.id
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(theme: currentTheme)

                Form {
                    Section("Время") {
                        DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .environment(\.colorScheme, .dark)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.black.opacity(0.55))

                    Section("Название") {
                        TextField("Назовите будильник", text: $title)
                            .foregroundStyle(.white)

                        Toggle("Включен", isOn: $isEnabled)
                            .tint(Color.accentColor)

                        Toggle("Вибрация", isOn: $vibrates)
                            .tint(Color.accentColor)
                    }
                    .listRowBackground(Color.black.opacity(0.45))

                    Section("Повтор") {
                        RepeatDaysPicker(selection: $repeatDays)
                    }
                    .listRowBackground(Color.black.opacity(0.45))

                    Section("Рингтон") {
                        Picker("Рингтон", selection: $ringtone) {
                            ForEach(AlarmRingtone.allCases) { ringtone in
                                Text(ringtone.title).tag(ringtone)
                            }
                        }
                        .tint(.white)
                        .onChange(of: ringtone) { _, newRingtone in
                            alarmStore.previewRingtone(newRingtone)
                        }

                        Button {
                            alarmStore.previewRingtone(ringtone)
                        } label: {
                            Label("Прослушать", systemImage: "play.circle.fill")
                                .foregroundStyle(.white)
                        }

                        Button {
                            alarmStore.stopRingtonePreview()
                        } label: {
                            Label("Остановить", systemImage: "stop.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.45))
                }
                .scrollContentBackground(.hidden)
                .tint(.white)
                .foregroundStyle(.white)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        alarmStore.stopRingtonePreview()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        alarmStore.stopRingtonePreview()
                        save(makeAlarm())
                        dismiss()
                    }
                }
            }
            .onDisappear {
                alarmStore.stopRingtonePreview()
            }
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .dark
    }

    private func makeAlarm() -> Alarm {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Alarm(
            id: originalID ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: components.hour ?? 7,
            minute: components.minute ?? 0,
            isEnabled: isEnabled,
            repeatDays: repeatDays,
            ringtone: ringtone,
            vibrates: vibrates
        )
    }
}

private struct RepeatDaysPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if selection.contains(day) {
                            selection.remove(day)
                        } else {
                            selection.insert(day)
                        }
                    }
                } label: {
                    Text(day.shortTitle.prefix(1))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: 34, height: 34)
                        .background(selection.contains(day) ? Color.accentColor : Color.white.opacity(0.12), in: Circle())
                        .foregroundStyle(selection.contains(day) ? .white : .white)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
