# Glass Alarm

Glass Alarm is a SwiftUI iOS alarm app scaffold with:

- glass-style SwiftUI interface;
- animated clock card;
- black, white, and automatic themes;
- local notification alarms;
- repeat weekdays;
- several bundled short notification sounds.

## Important iOS Limit

iOS does not allow third-party apps to behave exactly like the built-in Clock app in the background forever. This app uses `UNUserNotificationCenter`, which is the official way to schedule alarm-style local notifications.

Custom notification sounds must be bundled with the app and should stay under 30 seconds. The included sounds are short `.wav` files.

## Build

Open `GlassAlarm.xcodeproj` in Xcode on macOS, choose your iPhone, set a development team, and run.

For sideloading from Windows, you still need an `.ipa` built by macOS/Xcode or a cloud macOS build service. Windows alone cannot compile this iOS project.
