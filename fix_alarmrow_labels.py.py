from pathlib import Path

file = Path("GlassAlarm/Views/ContentView.swift")

if not file.exists():
    print("ContentView.swift not found")
    exit(1)

text = file.read_text(encoding="utf-8")

text = text.replace("onToggle:", "toggle:")
text = text.replace("onDelete:", "delete:")

file.write_text(text, encoding="utf-8")

print("AlarmRow parameter labels fixed")