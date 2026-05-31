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
            _title = State(initialValue: "Будильник")
            _time = State(initialValue: .now.addingTimeInterval(3600))
            _repeatDays = State(initialValue: [])
            _ringtone = State(initialValue: .crystal)
            _vibrates = State(initialValue: true)
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
                GlassBackground(theme: .system)

                Form {
                    Section {
                        DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)

                    Section("Название") {
                        TextField("Назовите будильник", text: $title)
                        Toggle("Включен", isOn: $isEnabled)
                        Toggle("Вибрация", isOn: $vibrates)
                    }

                    Section("Повтор") {
                        RepeatDaysPicker(selection: $repeatDays)
                    }

                    Section("Рингтон") {
                        Picker("Рингтон", selection: $ringtone) {
                            ForEach(AlarmRingtone.allCases) { ringtone in
                                Text(ringtone.title).tag(ringtone)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save(makeAlarm())
                        dismiss()
                    }
                }
            }
        }
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
                    if selection.contains(day) {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.shortTitle.prefix(1))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: 34, height: 34)
                        .background(selection.contains(day) ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                        .foregroundStyle(selection.contains(day) ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
