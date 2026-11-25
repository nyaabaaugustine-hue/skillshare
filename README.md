# SkillBridge Academy

Offline-capable Python learning and practice app for SkillBridge Academy learners.

Status: working Flutter learner app with a Next.js website and staff dashboard. The app includes a course path, a real Python editor with on-device execution, an offline submission queue, progress sync, AI tutor, guardian reports and an announcements inbox. See `docs/ARCHITECTURE.md`, `docs/VALUE_ROADMAP.md` and `docs/KNOWN_LIMITATIONS.md` for what is implemented, verified and still outstanding.

## First-time setup (Windows)

1. Install Git, Flutter SDK, Android Studio (with SDK, Command-line Tools, Platform-Tools), and Node.js LTS.
2. Check your tools:
   ```
   flutter --version
   flutter doctor -v
   adb devices
   node --version
   ```
3. In this folder, generate the Android/iOS platform files:
   ```
   cd C:\Users\HP\Desktop\skillbridge_python_lab
   flutter create --org com.skillbridge --project-name skillbridge_python_lab --platforms android,ios .
   ```
4. Tell Claude when step 3 is done. `lib/main.dart` is then replaced to start `SkillBridgeApp`.
5. Run on a connected phone:
   ```
   flutter pub get
   flutter run
   ```

## Docs
- `docs/ARCHITECTURE_DECISION_RECORD.md`: draft decisions, runtime spike checklist, open questions.

## Known limitations
- Python runtime and editor are not chosen/verified yet.
- No LMS integration yet; a mock will be built first.
