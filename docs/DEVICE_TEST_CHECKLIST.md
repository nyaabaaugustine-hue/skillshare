# Device test checklist

The app has never been launched on real hardware. This is the pass/fail sheet
for closing that gap. Do not mark the product "device-verified" until every
**Required** row has evidence (screenshot, log line or short note).

## What is needed

- Android phone with USB debugging enabled, or an emulator with a real image.
- The rebuilt APK: `build/app/outputs/flutter-apk/app-debug.apk` (142.1 MB).
- A learner account and an admin account on
  `https://www.skillbridgeacademy.tech`.
- `adb` on PATH.

## Install

```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Record:

| Item | Value |
| --- | --- |
| Device / Android version | |
| APK SHA-256 | `EA2F65ABDCCDB9C437864E18B3E492315469A79101B5B6FA47218B0F50539A49` |
| Install result | |
| First launch to Home (seconds) | |

## Required checks

| # | Check | Steps | Pass condition | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Cold start | Launch, wait for splash, sign in | Home tab appears; no crash or white screen | |
| 2 | Auth | Sign in with the shared account; force-stop and relaunch | Session restores without signing in again | |
| 3 | Guardian view | Sign in with a guardian account | Read-only guardian home appears; learner editing is not reachable | |
| 4 | Real Python | Open a lesson → editor → run `print("hello device")` | stdout shows `hello device` | |
| 5 | Real error | Run `raise ValueError("boom")` | Friendly error shows `ValueError: boom`, not a raw stack trace | |
| 6 | Timeout / cancel | Run `while True: pass`, then Stop | Execution stops promptly and the editor becomes usable again | |
| 7 | Offline draft | Go offline, type code, leave the editor, reopen | Draft survives | |
| 8 | Offline submission | Go offline, submit work, force-stop, relaunch | Submission stays queued | |
| 9 | Reconnect | Restore network, wait for sync | Queue empties; server shows exactly one submission (no duplicate) | |
| 10 | Inbox | Admin publishes an announcement from `/admin/announcements`; learner refreshes inbox | Announcement appears with title, body and read state | |
| 11 | Foreground push | App open when admin publishes | Heads-up notification appears and inbox updates | |
| 12 | Background push | App backgrounded when admin publishes | FCM notification arrives | |
| 13 | Notification tap | Tap the notification | App opens the announcement detail and marks it read | |
| 14 | Cold-start tap | Force-stop app, tap a new announcement notification | Pending tap survives startup and opens the right announcement | |
| 15 | Sign-out push cleanup | Sign out; admin publishes | No new learner announcement is fetched for that account | |

## Useful commands

```powershell
# Watch startup and push errors
adb logcat -v time | Select-String -Pattern "flutter|fcm| firebase|announcement|python|E/"

# Memory after the editor has run code
adb shell dumpsys meminfo com.skillbridge.skillbridge_python_lab

# Confirm the APK is the rebuilt one
Get-FileHash build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256
```

## Stop conditions

Stop and fix before any investor demo if:

- the embedded interpreter crashes or cannot import the bundled stdlib;
- an announcement push arrives but the inbox does not update;
- a notification tap opens the app but not the announcement;
- a queued submission is duplicated or lost after reconnect;
- first launch takes longer than 20 seconds on the test device.

## Not covered by this checklist

iOS, signed release builds, web offline/PWA behaviour and accessibility. Those
need separate passes; see `docs/IOS_AND_RELEASE_HANDOFF.md` and
`docs/WEB_DEPLOYMENT.md`.
