import Foundation
import UserNotifications

struct NotificationScheduler {
    private let testNotificationIdentifier = "glass-alarm-test"

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

    func scheduleTestNotification(after seconds: TimeInterval = 5) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testNotificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Тест будильника"
        content.body = "Если вы это видите, уведомления работают"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": "test",
            "vibrates": true
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: testNotificationIdentifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule test notification: \(error.localizedDescription)")
        }
    }

    private func addRequest(for alarm: Alarm, weekday: Weekday?) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "Будильник" : alarm.title
        content.body = "Пора просыпаться!"
        content.sound = sound(for: alarm.ringtone)
        content.interruptionLevel = .timeSensitive // Чтобы уведомление пробивалось через "Фокусирование"
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "vibrates": alarm.vibrates
        ]

        let trigger: UNCalendarNotificationTrigger

        if let weekday {
            var components = DateComponents()
            components.weekday = weekday.rawValue
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            guard let nextDate = alarm.nextTriggerDate() else { return }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nextDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier(for: alarm, weekday: weekday), content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("Scheduled alarm at \(DateFormatters.alarmTimeWithSeconds.string(from: trigger.nextTriggerDate() ?? Date())) id=\(request.identifier)")
            #endif
        } catch {
            print("Failed to schedule alarm \(alarm.id): \(error.localizedDescription)")
        }
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
