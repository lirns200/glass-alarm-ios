import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let storageKey = "savedAlarms"
    private let scheduler = NotificationScheduler()
    private var audioPlayer: AVAudioPlayer?

    func bootstrap() async {
        load()
        await refreshAuthorizationStatus()

        if alarms.isEmpty {
            let morning = Alarm(title: "Morning glass", hour: 7, minute: 30, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday], ringtone: .sunrise)
            let focus = Alarm(title: "Focus start", hour: 9, minute: 0, repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday], ringtone: .pulse)
            alarms = [morning, focus]
            save()
        }

        await rescheduleEnabledAlarms()
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorizationStatus()
        await rescheduleEnabledAlarms()
    }

    func add(_ alarm: Alarm) async {
        alarms.append(alarm)
        sortAndSave()
        await scheduleIfNeeded(alarm)
    }

    func update(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let previous = alarms[index]
        alarms[index] = alarm
        sortAndSave()

        // Cancel old identifiers first (important when repeat days changed)
        await scheduler.cancel(previous)
        await scheduleIfNeeded(alarm)
    }

    func delete(_ alarm: Alarm) async {
        alarms.removeAll { $0.id == alarm.id }
        save()
        await scheduler.cancel(alarm)
    }

    func setEnabled(_ alarm: Alarm, isEnabled: Bool) async {
        var edited = alarm
        edited.isEnabled = isEnabled
        await update(edited)
    }

    func appBecameActive() async {
        await refreshAuthorizationStatus()
        await rescheduleEnabledAlarms()
    }

    private func scheduleIfNeeded(_ alarm: Alarm) async {
        let canNotify = authorizationStatus == .authorized || authorizationStatus == .provisional
        guard alarm.isEnabled, canNotify else { return }
        await scheduler.schedule(alarm)
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

    private func rescheduleEnabledAlarms() async {
        await scheduler.cancelAll(alarms)
        for alarm in alarms where alarm.isEnabled {
            await scheduleIfNeeded(alarm)
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
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
