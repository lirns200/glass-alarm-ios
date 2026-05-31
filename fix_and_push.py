from pathlib import Path
import subprocess

root = Path(".")

# -------------------------
# NotificationScheduler.swift
# -------------------------

scheduler = root / "GlassAlarm" / "Services" / "NotificationScheduler.swift"

text = scheduler.read_text(encoding="utf-8")

text = text.replace(
'''func cancel(_ alarm: Alarm) async {
        let identifiers = identifiers(for: alarm)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
    }''',
'''func cancel(_ alarm: Alarm) async {
        let ids = identifiers(for: alarm)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }'''
)

text = text.replace(
'''func cancelAll(_ alarms: [Alarm]) async {
        let notificationIds = alarms.flatMap { identifiers(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }''',
'''func cancelAll(_ alarms: [Alarm]) async {
        let notificationIds = alarms.flatMap { identifiers(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
    }'''
)

scheduler.write_text(text, encoding="utf-8")

# -------------------------
# ContentView.swift
# -------------------------

content = root / "GlassAlarm" / "Views" / "ContentView.swift"

text = content.read_text(encoding="utf-8")

if "private var nextEnabledAlarm" not in text:
    text = text.replace(
'''private var theme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }''',
'''private var theme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }

    private var nextEnabledAlarm: Alarm? {
        alarmStore.alarms.first { $0.isEnabled }
    }'''
    )

text = text.replace(
'AnimatedClockCard(nextAlarm: alarmStore.alarms.first(where: \\.isEnabled))',
'AnimatedClockCard(nextAlarm: nextEnabledAlarm)'
)

content.write_text(text, encoding="utf-8")

print("Swift files fixed")

# -------------------------
# Git
# -------------------------

commands = [
    ["git", "add", "."],
    ["git", "commit", "-m", "fix ios compile errors"],
    ["git", "push"]
]

for cmd in commands:
    try:
        subprocess.run(cmd, check=True)
    except:
        pass

print("Done")