# Learning reminders

Two local notifications, both with the bundled chime
(`android/app/src/main/res/raw/reminder_chime.wav`, generated: A5 then E6).

| Reminder | Fires | Cancelled by |
|---|---|---|
| **Daily** (`id 1001`) | At the learner's study time (default **6:00 PM**) on a day they have not learned | Finishing a step — it then moves to tomorrow; turning reminders off |
| **Comeback** (`id 1002`) | 3 hours after a lesson is opened | Finishing that step; turning reminders off |

The daily reminder is always *one* scheduled notification, not a repeating one:
it is re-scheduled on every launch, on every finished step and whenever the time
changes. That is what makes "if skipped" honest — a learner who studies at 9am is
never nudged at 6pm, and a learner who skips a day is nudged at 6pm that day.

## Where the code lives

| File | Role |
|---|---|
| `lib/core/notifications/reminders.dart` | Chooses the platform implementation (`dart.library.io`) |
| `lib/core/notifications/reminders_stub.dart` | Web: no-op, `supported == false` |
| `lib/core/notifications/reminders_io.dart` | Android/iOS: `flutter_local_notifications` + `timezone` |
| `lib/core/notifications/reminder_gateway.dart` | Interface the rules depend on |
| `lib/core/notifications/reminder_service.dart` | The scheduling rules above |
| `lib/features/settings/settings_screen.dart` | Switch + time picker |
| `lib/features/course/course_path_screen.dart` | Arms the comeback reminder, cancels on completion |
| `lib/main.dart` | `bootstrap()` after the dependency graph is ready |

## Android setup that must stay in place

- `AndroidManifest.xml`: `POST_NOTIFICATIONS` (Android 13+ shows nothing without
  the runtime grant) and `RECEIVE_BOOT_COMPLETED`, plus the plugin's
  `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`.
- `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` and the
  `desugar_jdk_libs` dependency. The plugin schedules with `java.time`; without
  desugaring the release build fails to compile.
- The channel id is `skillbridge_reminders_v1`. Android locks a channel's sound
  when it is created, so a new tone needs a new channel id (bump the suffix).

## Behaviour and limits

- **Web:** no notifications at all; the settings row still shows so accounts are
  consistent, and the app explains the platform limit in the subtitle copy.
- **Permission:** requested once, on the first launch after reminders are on
  (`reminder_permission_asked`). If the learner denies it, nothing is scheduled
  and the OS can only re-prompt from system settings — the app does not nag.
- **Exact timing:** scheduling is `inexactAllowWhileIdle`, so Android may deliver
  the reminder a few minutes late. This is deliberate: exact alarms need a
  special permission that Play Store policy restricts for non-alarm apps.
- **Timezone:** taken from the device (`flutter_timezone`); if that lookup fails
  the app falls back to UTC rather than dropping the reminder.
- **Not covered:** reminders while the app is force-stopped by the user, and any
  email/SMS channel. The guardian digest is a separate, server-side feature.

## Verification

- `flutter test test/reminder_service_test.dart` — 7 tests covering scheduling,
  the studied-today copy, the 3-hour comeback, cancellation and the time change.
- `flutter build web --release` — EXIT 0 (the web build excludes the plugin via
  the conditional export).
- `flutter build apk --debug` — EXIT 0. This compiles the native path, the
  desugaring change and the manifest edits. Two build failures were found and
  fixed on the way: the resolved plugin wanted Android SDK 37 (not installed),
  so it is pinned to 19.x; and `flutter_timezone` compiled Kotlin 1.8 against
  this project's Java 11 target, so it was removed and the local zone is now
  derived from the device UTC offset.
- Artifact checks on `app-debug.apk`: `aapt2 dump permissions` lists
  `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`, the merged manifest contains
  both `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`,
  and `res/raw/reminder_chime.wav` (56 KB) is packaged.
- **Not verified:** actual delivery on a phone — permission prompt, the chime
  playing, 3-hour timing and behaviour after a reboot. No device or emulator test
  was run, so treat delivery as untested until someone installs the APK.
