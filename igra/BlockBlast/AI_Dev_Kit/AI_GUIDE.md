# AI Developer Guide & Troubleshooting

## Core Rules for AI Coding
1. **No duplicate IDs**: Never add a second `buildUniqueId` in `GlassAlarmApp.swift`. The build tool handles it.
2. **Async Syntax**: Do NOT use `guard condition || await asyncFunc()`. Swift doesn't like `await` in complex logical expressions. Use:
   ```swift
   if !condition {
       guard await asyncFunc() else { return }
   }
   ```
3. **UI Layers**: Always use `.allowsHitTesting(false)` for decorative background elements to prevent blocking buttons.
4. **Overheating**: Avoid `TimelineView` + `Canvas` for heavy animations. Use simple `withAnimation` and basic shapes.

## Notification Handling
- **Critical Alerts**: Use `.critical` interruption level for alarms.
- **Categories**: Use `ALARM_CATEGORY` with `STOP_ACTION` and `SNOOZE_ACTION`.

## Performance
- Keep `GlassBackground` lightweight.
- Use `.glassCard()` extension for consistent UI.
