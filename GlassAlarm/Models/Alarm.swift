import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var repeatDays: Set<Weekday>
    var ringtone: AlarmRingtone
    var vibrates: Bool

    init(
        id: UUID = UUID(),
        title: String,
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        repeatDays: Set<Weekday> = [],
        ringtone: AlarmRingtone = .crystal,
        vibrates: Bool = true
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.ringtone = ringtone
        self.vibrates = vibrates
    }

    var time: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatText: String {
        if repeatDays.isEmpty {
            return "Один раз"
        }

        let ordered = Weekday.allCases.filter { repeatDays.contains($0) }
        if ordered.count == Weekday.allCases.count {
            return "Каждый день"
        }

        return ordered.map(\.shortTitle).joined(separator: " ")
    }

    var timeUntilText: String {
        let now = Date()
        let calendar = Calendar.current
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        guard let alarmDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else {
            return ""
        }
        
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: alarmDate)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0
        
        if hours > 0 {
            return "Через \(hours) ч \(minutes) мин"
        } else {
            return "Через \(minutes) мин"
        }
    }
}

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .monday: return "Понедельник"
        case .tuesday: return "Вторник"
        case .wednesday: return "Среда"
        case .thursday: return "Четверг"
        case .friday: return "Пятница"
        case .saturday: return "Суббота"
        case .sunday: return "Воскресенье"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: return "Пн"
        case .tuesday: return "Вт"
        case .wednesday: return "Ср"
        case .thursday: return "Чт"
        case .friday: return "Пт"
        case .saturday: return "Сб"
        case .sunday: return "Вс"
        }
    }
}

enum AlarmRingtone: String, CaseIterable, Codable, Identifiable {
    case crystal
    case pulse
    case sunrise
    case focus
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crystal: return "Кристалл"
        case .pulse: return "Пульс"
        case .sunrise: return "Рассвет"
        case .focus: return "Фокус"
        case .classic: return "Классика"
        }
    }

    var notificationSoundName: String? {
        switch self {
        case .crystal: return "crystal.wav"
        case .pulse: return "pulse.wav"
        case .sunrise: return "sunrise.wav"
        case .focus: return "focus.wav"
        case .classic: return nil
        }
    }
}
