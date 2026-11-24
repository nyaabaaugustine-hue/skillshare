# Notifications and announcements

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

- **Web:** local reminders are unavailable (the settings row explains this). Web
  push announcements are optional and require a VAPID key — see below.
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

## Admin announcements (Firebase Cloud Messaging)

One-way messages from the website admin console to signed-in learners. The
**in-app inbox is authoritative**; FCM is a best-effort delivery channel. When
Firebase credentials or a device token are unavailable, publishing still
succeeds with `pushEnabled: false` and the message waits in the inbox.

### Firebase project

- Project: `skillbridge-academy` (`skillbridge-academy-e5e4c`).
- Flutter config: `lib/firebase_options.dart`, `android/app/google-services.json`,
  `web/firebase-messaging-sw.js`.
- Web push needs a VAPID key from Firebase Console → Cloud Messaging → Web
  configuration. Supply it at build time:

  ```bash
  flutter build web --dart-define=SB_FCM_VAPID_KEY=<key>
  ```

  Without the key, native push still works and web falls back to the inbox.
- iOS additionally needs an APNs key uploaded to Firebase and the Push
  Notifications capability enabled in Xcode.

### Backend

- Apply `.work/academy-live/db/014_announcements.sql` to the Neon database.
- Set `FIREBASE_SERVICE_ACCOUNT_JSON` in the backend environment (or
  `GOOGLE_APPLICATION_CREDENTIALS`). Never commit the service-account file or
  ship it in the Flutter app.
- Publish from `/admin/announcements`; the server derives the user id from the
  Neon Auth session, so a client cannot send messages as another learner.

### Data payload and tap routing

FCM data payload:

```json
{
  "type": "announcement",
  "announcementId": "<uuid>",
  "title": "Title",
  "body": "Short preview"
}
```

`PushMessage.fromData` ignores anything else. Foreground messages post a local
heads-up (ids `2000+`) through the existing reminder channel. Tapping a heads-up,
a background FCM notification or a terminated-app launch opens
`/announcements/<id>` via `AppRouter.navigatorKey`; the detail screen marks the
announcement read.

### Flutter files

| File | Role |
|---|---|
| `lib/features/messages/push_gateway.dart` | Testable push interface |
| `lib/features/messages/push_service.dart` | Firebase adapter, token + tap streams |
| `lib/features/messages/push_message.dart` | Payload parsing |
| `lib/features/messages/announcement*.dart` | Model, repository, controller, inbox UI |
| `lib/main.dart` | Firebase bootstrap, providers, tap routing |
| `lib/features/auth/auth_controller.dart` | Token register/delete on auth changes |

### Privacy

Tokens are registered only for signed-in accounts and deleted on sign-out. The
server stores one token per device per user and prunes tokens FCM reports as
invalid. Announcement titles/bodies are duplicated in the push payload only so a
tap can render immediately; the authoritative copy and read state stay in the
database.
