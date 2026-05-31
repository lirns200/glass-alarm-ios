import Foundation
import UserNotifications

struct NotificationScheduler {
    func schedule(_ alarm: Alarm) async {
        await cancel(alarm)

        if alarm.repeatDays.isEmpty {
            await addRequest(for: alarm, weekday: nil)
        } else {
            for weekday in alarm.repeatDays {
                await addRequest(for: alarm, weekday: weekday)
            }
        }
    }

    func cancel(_ alarm: Alarm) async {
        let ids = identifiers(for: alarm)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll(_ alarms: [Alarm]) async {
        let notificationIds = alarms.flatMap { identifiers(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
    }

    private func addRequest(for alarm: Alarm, weekday: Weekday?) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "Будильник" : alarm.title
        content.body = "Пора просыпаться! (\(alarm.timeUntilText))"
        content.sound = sound(for: alarm.ringtone)
        content.interruptionLevel = .timeSensitive // Чтобы уведомление пробивалось через "Фокусирование"

        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        if let weekday {
            components.weekday = weekday.rawValue
        }

        let repeats = weekday != nil
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier(for: alarm, weekday: weekday), content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func sound(for ringtone: AlarmRingtone) -> UNNotificationSound {
        guard let name = ringtone.notificationSoundName else {
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(name))
    }

    private func identifiers(for alarm: Alarm) -> [String] {
        if alarm.repeatDays.isEmpty {
            return [identifier(for: alarm, weekday: nil)]
        }
        return alarm.repeatDays.map { identifier(for: alarm, weekday: $0) }
    }

    private func identifier(for alarm: Alarm, weekday: Weekday?) -> String {
        if let weekday {
            return "glass-alarm-\(alarm.id.uuidString)-\(weekday.rawValue)"
        }
        return "glass-alarm-\(alarm.id.uuidString)-once"
    }
}
