import Foundation
import SwiftUI
import UserNotifications
import AVFoundation

@MainActor
class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let storageKey = "saved_alarms"
    private let scheduler = NotificationScheduler()
    private var audioPlayer: AVAudioPlayer?

    init() {
        load()
    }

    func bootstrap() async {
        await refreshAuthorizationStatus()
    }

    func requestNotifications() async -> Bool {
        let granted = await ensureNotificationAuthorization()
        await refreshAuthorizationStatus()
        return granted
    }

    func add(_ alarm: Alarm) async {
        alarms.append(alarm)
        sortAndSave()
        await scheduleIfNeeded(alarm)
        await updateStaticStatusNotification()
    }

    func update(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let previous = alarms[index]
        alarms[index] = alarm
        sortAndSave()

        // Cancel old identifiers first
        await scheduler.cancel(previous)
        await scheduleIfNeeded(alarm)
        await updateStaticStatusNotification()
    }

    func delete(_ alarm: Alarm) async {
        alarms.removeAll { $0.id == alarm.id }
        save()
        await scheduler.cancel(alarm)
        await updateStaticStatusNotification()
    }

    func setEnabled(_ alarm: Alarm, isEnabled: Bool) async {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            var edited = alarms[index]
            edited.isEnabled = isEnabled
            await update(edited)
        }
    }

    func appBecameActive() async {
        await refreshAuthorizationStatus()
        await rescheduleEnabledAlarms()
        await updateStaticStatusNotification()
    }

    private func scheduleIfNeeded(_ alarm: Alarm) async {
        guard alarm.isEnabled else { return }
        let canNotify = authorizationStatus == .authorized || authorizationStatus == .provisional
        if !canNotify {
            guard await ensureNotificationAuthorization() else { return }
        }
        await scheduler.schedule(alarm)
    }

    private func updateStaticStatusNotification() async {
        let next = alarms.filter { $0.isEnabled }.first
        await scheduler.updateStaticStatus(nextAlarm: next)
    }

    func previewRingtone(_ ringtone: AlarmRingtone) {
        stopRingtonePreview()

        guard let soundName = ringtone.notificationSoundName,
              let url = Bundle.main.url(forResource: soundName.replacingOccurrences(of: ".wav", with: ""), withExtension: "wav") else {
            AudioServicesPlaySystemSound(1005)
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to preview ringtone: \(error.localizedDescription)")
            AudioServicesPlaySystemSound(1005)
        }
    }

    func stopRingtonePreview() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func previewVibration() {
        HapticsService.playAlarmPreview()
    }

    func scheduleTestNotification(after seconds: TimeInterval = 5) async -> Bool {
        let granted = await ensureNotificationAuthorization()
        guard granted else { return false }
        await scheduler.scheduleTestNotification(after: seconds)
        return true
    }

    private func rescheduleEnabledAlarms() async {
        await scheduler.cancelAll(alarms)

        let canNotify = authorizationStatus == .authorized || authorizationStatus == .provisional
        if !canNotify {
            guard await ensureNotificationAuthorization() else { return }
        }

        for alarm in alarms where alarm.isEnabled {
            await scheduler.schedule(alarm)
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func ensureNotificationAuthorization() async -> Bool {
        let canNotify = authorizationStatus == .authorized || authorizationStatus == .provisional
        if canNotify {
            return true
        }

        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted || authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Alarm].self, from: data) else {
            return
        }
        alarms = decoded.sorted { $0.timeText < $1.timeText }
    }

    private func sortAndSave() {
        alarms.sort { $0.timeText < $1.timeText }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
