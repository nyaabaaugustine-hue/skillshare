# iOS and signed-release handoff

These are the tasks that cannot be completed in this Windows environment. They
need an Apple Developer account, a Mac with Xcode, and signing material from the
owner. Nothing here has been built or tested yet.

## 1. iOS Firebase and APNs

1. In Firebase Console → Project settings → Your apps, add an iOS app.
2. Use the existing bundle identifier from `ios/Runner.xcodeproj/project.pbxproj`:
   `com.skillbridge.skillbridgePythonLab`.
3. Download `GoogleService-Info.plist` and place it at
   `ios/Runner/GoogleService-Info.plist`. It is a public config file; keep it in
   source control if the repo is private, but never add service-account keys.
4. In Firebase Console → Cloud Messaging, upload the APNs authentication key
   (.p8) for the same app ID. Record the key ID and team ID in the password
   manager, not in Git.
5. In Xcode, open `ios/Runner.xcworkspace`, select the Runner target and enable:
   - Push Notifications capability;
   - Background Modes → Remote notifications.
6. Build on the Mac:

   ```bash
   flutter build ios --release \
     --dart-define=SB_ENV=production \
     --dart-define=SB_API_BASE_URL=https://www.skillbridgeacademy.tech
   ```

7. Test the same nine announcement cases as Android in
   `docs/DEVICE_TEST_CHECKLIST.md`, plus background and cold-start taps on a
   physical iPhone. Push does not work reliably in the simulator.

## 2. Android release signing

`android/app/build.gradle.kts` already reads `android/keystore.properties` and
falls back to debug signing when it is absent. Generate a real upload key:

```powershell
keytool -genkey -v -keystore android\app\upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create the git-ignored `android/keystore.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=<from password manager>
keyAlias=upload
keyPassword=<from password manager>
```

Then build smaller, signed APKs:

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=SB_ENV=production `
  --dart-define=SB_API_BASE_URL=https://www.skillbridgeacademy.tech
```

Outputs land in `build/app/outputs/flutter-apk/`. Prefer an App Bundle for Play:

```powershell
flutter build appbundle --release `
  --dart-define=SB_ENV=production `
  --dart-define=SB_API_BASE_URL=https://www.skillbridgeacademy.tech
```

Do **not** replace the website's current download link until a signed APK has
passed the device checklist. The 142.1 MB artifact in `build/` is debug-signed.

## 3. What still needs a human decision

- Whether to publish on Google Play (App Bundle + store listing) or only
  sideload signed APKs.
- Whether to support iOS at all in the first investor demo; if not, say
  "Android + web" rather than showing an iOS download button.
- Privacy policy, terms and guardian-consent copy before public distribution.

## 4. Verification evidence to collect

| Item | Evidence |
| --- | --- |
| Signed APK SHA-256 and size | |
| `apksigner verify --verbose <apk>` output | |
| iOS build machine / Xcode version | |
| APNs token registered by backend `/api/device-tokens` | |
| Background announcement received on iPhone | |
