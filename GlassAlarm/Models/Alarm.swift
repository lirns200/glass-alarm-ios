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
        ringtone: AlarmRingtone = .pup,
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

    func nextTriggerDate(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        if repeatDays.isEmpty {
            return calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }

        var nearestDate: Date?
        for weekday in repeatDays {
            var weekdayComponents = components
            weekdayComponents.weekday = weekday.rawValue
            weekdayComponents.second = 0

            guard let candidate = calendar.nextDate(
                after: now,
                matching: weekdayComponents,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) else {
                continue
            }

            if let currentNearest = nearestDate {
                if candidate < currentNearest {
                    nearestDate = candidate
                }
            } else {
                nearestDate = candidate
            }
        }

        return nearestDate
    }

    var timeUntilText: String {
        let now = Date()
        let calendar = Calendar.current

        guard let nextDate = nextTriggerDate(from: now, calendar: calendar) else {
            return ""
        }

        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextDate)
        let days = max(0, diff.day ?? 0)
        let hours = max(0, diff.hour ?? 0)
        let minutes = max(0, diff.minute ?? 0)

        if days > 0 {
            return "Через \(days) д \(hours) ч"
        }

        if hours > 0 {
            return "Через \(hours) ч \(minutes) мин"
        }

        return "Через \(minutes) мин"
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
    case pulse
    case sunrise
    case pup
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return "Пульс"
        case .sunrise: return "Рассвет"
        case .pup: return "Пуп"
        case .classic: return "Классика"
        }
    }

    var notificationSoundName: String? {
        switch self {
        case .pulse: return "pulse.wav"
        case .sunrise: return "sunrise.wav"
        case .pup: return "pup.wav"
        case .classic: return nil
        }
    }
}
