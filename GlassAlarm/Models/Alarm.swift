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
            return "Once"
        }

        let ordered = Weekday.allCases.filter { repeatDays.contains($0) }
        if ordered.count == Weekday.allCases.count {
            return "Every day"
        }

        return ordered.map(\.shortTitle).joined(separator: " ")
    }
}

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
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
        case .crystal: return "Crystal"
        case .pulse: return "Pulse"
        case .sunrise: return "Sunrise"
        case .focus: return "Focus"
        case .classic: return "Classic"
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
