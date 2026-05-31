from pathlib import Path
import subprocess

root = Path(r"C:\Users\sivma\Documents\Codex\2026-05-31\build-macos-apps-plugin-build-macos\outputs\GlassAlarm")

# ---------- NotificationScheduler ----------

notif = root / "GlassAlarm" / "Services" / "NotificationScheduler.swift"

text = notif.read_text(encoding="utf-8")

text = text.replace(
'let identifiers = alarms.flatMap { identifiers(for: $0) }',
'let notificationIds = alarms.flatMap { identifiers(for: $0) }'
)

text = text.replace(
'removePendingNotificationRequests(withIdentifiers: identifiers)',
'removePendingNotificationRequests(withIdentifiers: notificationIds)',
1
)

notif.write_text(text, encoding="utf-8")

# ---------- ContentView ----------

content = root / "GlassAlarm" / "Views" / "ContentView.swift"

text = content.read_text(encoding="utf-8")

text = text.replace(
r'AnimatedClockCard(nextAlarm: alarmStore.alarms.first(where: .isEnabled))',
'''let nextAlarm = alarmStore.alarms.first(where: { $0.isEnabled })
AnimatedClockCard(nextAlarm: nextAlarm)'''
)

content.write_text(text, encoding="utf-8")

print("Files patched")

subprocess.run(["git", "add", "."], cwd=root)
subprocess.run(["git", "commit", "-m", "fix ios build"], cwd=root)
subprocess.run(["git", "push"], cwd=root)

print("Done")
