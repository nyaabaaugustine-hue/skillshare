# Build and release

## Prerequisites

| Tool | Version used to verify this document | Notes |
| --- | --- | --- |
| Flutter | 3.47.7 (Dart 3.13.5) | `flutter --version` |
| JDK | Temurin 17.0.20.1 | Android Gradle Plugin requires 17 |
| Android SDK | cmdline-tools 11076708, platform 34 + 36, build-tools 34.0.0 + 36.0.0, NDK 28.2.13676358, CMake 3.22.1 | Installs fine **without admin** — see below |
| CPython | 3.14.8 | Needed for the desktop runtime and the execution tests |

On Windows, a convenient layout that avoids admin rights for the Flutter SDK:

```
C:\Users\<you>\flutter                      # unzipped Flutter SDK
C:\Users\<you>\flutter_dl\jdk-17.0.20.1+1   # portable JDK
```

```powershell
$env:Path = "C:\Users\<you>\flutter\bin;$env:Path"
$env:JAVA_HOME = "C:\Users\<you>\flutter_dl\jdk-17.0.20.1+1"
```

> Building the Windows desktop target (or `flutter test` on some setups) needs
> symlink support. Enable Windows **Developer Mode**, or run from a shell with
> administrative rights. `flutter analyze` and `flutter test` are unaffected.

## Installing the Android SDK without admin rights

Everything below lives under `%LOCALAPPDATA%\Android\Sdk` and needs no
elevation. Verified end to end on Windows 10.

```powershell
# 1. Command-line tools (skip Android Studio entirely)
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
Invoke-WebRequest `
  https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip `
  -OutFile $env:TEMP\clt.zip
Expand-Archive $env:TEMP\clt.zip -DestinationPath $env:TEMP\clt
New-Item -ItemType Directory -Force "$sdk\cmdline-tools" | Out-Null
Move-Item "$env:TEMP\clt\cmdline-tools" "$sdk\cmdline-tools\latest"

# 2. Accept the licences (needs a JDK on the path)
$env:JAVA_HOME = "C:\Users\<you>\flutter_dl\jdk-17.0.20.1+1"
$sm = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"
1..60 | ForEach-Object { "y" } | & $sm --sdk_root="$sdk" --licenses

# 3. The components Flutter 3.47.7, AGP 9.1.0 and the plugins actually need
#    (android-34 is pulled in by connectivity_plus, not by the app)
& $sm --sdk_root="$sdk" platform-tools "platforms;android-36" `
  "build-tools;36.0.0" "platforms;android-34" "build-tools;34.0.0"
& $sm --sdk_root="$sdk" "ndk;28.2.13676358" "cmake;3.22.1"

# 4. Point Flutter at it
flutter config --android-sdk "$sdk"
flutter doctor     # Android toolchain should go green
```

The NDK is ~1 GB and is **required**, not optional: `serious_python` compiles a
native bridge. Versions come from Flutter's `FlutterExtension.kt`
(`compileSdkVersion = 36`, `minSdkVersion = 24`, `ndkVersion = 28.2.13676358`).

## Verify the code before building anything

```powershell
flutter pub get
flutter analyze      # must print "No issues found!"
flutter test         # must be all green
```

The execution tests need a working `python` on `PATH`. If it is elsewhere, set
`SB_PYTHON_EXECUTABLE` (used by the app) or `SB_TEST_PYTHON` (used by the tests).

```powershell
$env:SB_TEST_PYTHON = "C:\Python314\python.exe"
flutter test test\python_runtime_process_test.dart
```

If no interpreter is available those tests **skip with an explicit message** —
they never silently pass.

## Desktop smoke run

The fastest way to exercise the whole app with real Python:

```powershell
# One-off, only needed on a machine without Developer Mode (see below).
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\link_windows_plugins.ps1

flutter run -d windows
```

This selects `ProcessPythonRuntime`, which spawns
`python_app/harness_cli.py` in a child process for each Run. That is the same
executor the phone uses, so a desktop smoke test is meaningful.

Verified on this machine: `flutter build windows --debug` produces
`build\windows\x64\runner\Debug\skillbridge_python_lab.exe`, which launches and
renders the seeded home screen. Launch it from the project root — the runtime
finds the harness by walking up from the current directory
(`ProcessPythonRuntime.resolveHarnessPath`). The interpreter is whatever `python`
resolves to on `PATH`; override with `SB_PYTHON_EXECUTABLE`.

**Why the extra script.** `flutter build windows` creates one symlink per
Windows plugin under `windows/flutter/ephemeral/.plugin_symlinks/`, and on
Windows a real symlink needs `SeCreateSymbolicLinkPrivilege`. A
non-administrator only has that with Developer Mode on, and without it the build
stops with "Building with plugins requires symlink support". Enabling Developer
Mode (`start ms-settings:developers`) is the supported fix. Where that is not
possible, the script pre-creates those entries as **directory junctions**, which
need no privilege: Flutter skips any link that already exists, and Dart's
`Link.existsSync()` reports `true` for a junction but `false` for a plain
directory. Run it after `flutter pub get` and before the build, because a
`pub get` that changes the plugin list recreates that directory.

Note the desktop artifact is a Debug build and links an unstripped
`python314_d.dll`; no release build has been produced.

## Web build

Web is a supported **UI** target only. A browser has neither `dart:io` nor
`dart:ffi`, so `AppConfig` always resolves to `FakePythonRuntime` there and a
pressing Run returns a canned result. A working web build is *not* evidence that
Python executes — see `docs/KNOWN_LIMITATIONS.md`, limitation 6. The trade-off
is that the native and embedded runtimes sit behind conditional imports
(`lib/features/python_runtime/python_runtime_factory_*.dart`,
`lib/core/storage/database_factory_*.dart`), so the browser never compiles them.

`sqlite3.wasm` and the shared worker are generated into `web/`, not vendored:

```powershell
dart run sqflite_common_ffi_web:setup   # writes web/sqlite3.wasm, web/sqflite_sw.js
flutter build web --release            # -> build/web, ~40 MB total
```

`sqflite_common_ffi_web` runs SQLite as wasm in a shared worker and persists to
IndexedDB, so the offline story still holds on web.

### PWA: install and offline

`tool/build_web.ps1` also installs the PWA service worker: it copies
`web/sw.js` over the generated `build/web/flutter_service_worker.js`, which is
the file Flutter's bootstrap registers. Do not register a second worker on the
same scope — the two replace each other and the page ends up uncontrolled.
`web/index.html` registers that one file.

Requirements when hosting (see `docs/PWA_COMPATIBILITY.md` for the detail):
HTTPS or localhost, the same origin as `/api/auth`, `text/javascript` for the
worker with no long cache, and a CSP that allows `'wasm-unsafe-eval'` so
CanvasKit and Pyodide can compile their `.wasm`. Ship `manifest.json`,
`apple-touch-icon.png` and `icons/` alongside the bundle.

The shell (document, CanvasKit, fonts, `main.dart.js`) is pre-cached, so an
installed app opens with no network. Pyodide is cached on first use, so an
offline session can run Python only after one online session that used the
editor. Bump `CACHE_VERSION` in `web/sw.js` when the shell list or strategy
changes; old caches are deleted on activate.

To serve it:

```powershell
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1 `
  --dart-define=SB_API_BASE_URL=http://localhost:3001
```

The website's `NEXT_PUBLIC_LEARN_URL` (or `FLUTTER_APP_ORIGIN`) must match the
Flutter app origin. The tutor and sign-in APIs use this exact origin for CORS.
`SB_API_BASE_URL` points the Flutter build at the website API; without it, the
app intentionally uses only its offline tutor.

### Hosting the web build

Use the project script, which validates the API origin, regenerates the wasm
assets, and builds with `--base-href=/app/`:

```powershell
.\tool\build_web.ps1                        # or: .\tool\build_web.ps1 -SiteOrigin https://your-site.example
```

The bundle is **shipped inside the Next.js website**, not on a separate static
host: copy `build\web\*` into `website\public\app` (drop the `*.js.symbols`
files, which are only for crash symbolication). The website serves it at `/app/`
and frames it from `/learn`, so the browser loads the app from the same origin
it signed in on and sends its Neon Auth cookie straight into it. That is what
makes one account work on the phone and in the browser against the same Neon
Auth + Neon Postgres.

Because the app now lives on the site's own origin, `NEXT_PUBLIC_LEARN_URL` and
`FLUTTER_APP_ORIGIN` no longer need to be set in production; leave them unset
unless you deliberately host the bundle elsewhere. If you do, set both to that
exact origin (scheme + host + port) — a mismatch makes `/learn` frame the wrong
place. A `localhost` value is ignored in a production build.

`SB_API_BASE_URL` points the Flutter build at the website API; a build without
it folds `cloudAuthEnabled` to a compile-time `false`, tree-shakes the whole
cloud sign-in path out, and can neither register nor sign in.

The **Wasm** target does *not* build: `serious_python` imports `dart:ffi`, and
dart2js rejects it without `--enable-experimental-ffi`. The default JS target is
what the commands above produce.

## Android build

### 1. Package the embedded Python runtime (one-off per platform)

`serious_python` **5.0.0** changed packaging: for every *native* target the
processed Python app is staged into a directory you name, and the platform's
Gradle/CMake build copies it from there into the bundle. `package` refuses to
run without it:

```
Error: Exception: SERIOUS_PYTHON_APP environment variable must be set for
Android packaging (staging dir for the unpacked app).
```

So both the package step **and** the Gradle build need the same two variables:

```powershell
$root = "C:\Users\<you>\skillbridge_python_lab"
$env:SERIOUS_PYTHON_APP           = "$root\build\python-app"
$env:SERIOUS_PYTHON_SITE_PACKAGES = "$root\build\python-site-packages"

dart run serious_python:main package python_app -p Android --cleanup-app
```

`build/` is already git-ignored, which is why it is the right home for these.
The Android plugin (`serious_python_android/android/build.gradle.kts`) reads
`SERIOUS_PYTHON_APP` and zips it into a **stored** `app.zip` asset that is
unpacked once on the phone, so the directory must still exist at
`flutter build` time. `build/python-app/` should end up containing `main.py`,
`skillbridge_exec.py` and `harness_cli.py`.

`__pypackages__/` is also added to `sys.path` at run time, so pure-Python
dependencies can be dropped next to the sources without a `requirements.txt`.

This must be re-run whenever anything under `python_app/` changes. Skipping it is
the single most common reason a device build fails at runtime with "the embedded
Python runtime did not start in time".

### 2. Debug build / install

```powershell
flutter devices                     # confirm a device or emulator is visible
flutter build apk --debug
flutter install --debug
```

Verified on Windows 10 with the toolchain above: `flutter build apk --debug`
completes in roughly 7–17 minutes cold, ~7 minutes warm, and produces
`build/app/outputs/flutter-apk/app-debug.apk`.

**What is actually inside (checked with `aapt2` and by unzipping the APK):**

| Entry | Size | Meaning |
| --- | --- | --- |
| `lib/<abi>/libpython3.14.so` | 5.6 MB | The real embedded CPython |
| `lib/<abi>/libdart_bridge.so` | 0.03 MB | The Dart ↔ Python FFI bridge |
| `lib/<abi>/lib_*`, `lib*.so` | ~30 MB/ABI | Python extension modules, loaded from the APK via mmap |
| `assets/stdlib.zip` | 10.4 MB | Python standard library, stored uncompressed for `zipimport` |
| `assets/app.zip` | 29 KB | Our `main.py`, `skillbridge_exec.py`, `harness_cli.py` |
| `assets/sitepackages.zip` | 0 KB | Empty — the app has no third-party requirements |

ABIs shipped: `arm64-v8a`, `armeabi-v7a`, `x86_64`. `minSdkVersion` 24,
`targetSdkVersion` 36, package `com.skillbridge.skillbridge_python_lab`, label
"SkillBridge Python Lab".

The **debug APK is ~209 MB** for three reasons, all avoidable in release:

1. Three ABIs. `--split-per-abi` or `flutter build appbundle` fixes this.
2. Debug builds are unstripped.
3. `libVkLayer_khronos_validation.so` (14.5 MB per ABI) is the debug-only
   Vulkan validation layer; it is not in a release build.

Do not read "the APK contains `libpython3.14.so`" as "the runtime works". It
has never been executed on a device — see `docs/KNOWN_LIMITATIONS.md`.

### 3. Release build

```powershell
flutter build apk --release `
  --dart-define=SB_ENV=staging `
  --dart-define=SB_API_BASE_URL=https://academy-skillshare.vercel.app `
  --dart-define=SB_LMS_BASE_URL=https://lms.example.org/api/v1 `
  --dart-define=SB_LMS_CLIENT_ID=skillbridge-android `
  --dart-define=SB_LEADERBOARD_URL=https://academy-skillshare.vercel.app
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

`android/app/build.gradle.kts` signs the release build from a git-ignored
`android/keystore.properties` when that file exists, and otherwise falls back to
the debug key so `flutter run --release` keeps working locally. Configure the
real signing before distributing anything — see
[Release signing](#4-release-signing).

### 4. Release signing

One-off: generate an upload keystore. It is kept out of the repo — `*.jks` is
git-ignored.

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/keystore.properties.example` to `android/keystore.properties`
(git-ignored) and fill it in. `storeFile` is resolved relative to `android/app`,
so `../upload-keystore.jks` means `android/upload-keystore.jks`:

```
storeFile=../upload-keystore.jks
storePassword=<your keystore password>
keyAlias=upload
keyPassword=<your key password>
```

Build the App Bundle Play needs, with the same `--dart-define`s as the APK:

```powershell
flutter build appbundle --release `
  --dart-define=SB_ENV=staging `
  --dart-define=SB_API_BASE_URL=https://academy-skillshare.vercel.app `
  --dart-define=SB_LMS_BASE_URL=https://lms.example.org/api/v1 `
  --dart-define=SB_LMS_CLIENT_ID=skillbridge-android `
  --dart-define=SB_LEADERBOARD_URL=https://academy-skillshare.vercel.app
```

Output: `build/app/outputs/bundle/release/app-release.aab`. Prefer Play App
Signing so Google holds the app-signing key and only the upload key lives here.

### Build variants

* `--split-per-abi` produces smaller per-ABI APKs, useful for sideloading to a
  mixed classroom.
* An App Bundle (`flutter build appbundle`) is required for Play distribution.

## Configuration reference (`--dart-define`)

| Define | Default | Meaning |
| --- | --- | --- |
| `SB_ENV` | `development` | Label shown in diagnostics |
| `SB_LMS_BASE_URL` | *(empty)* | **Empty means "use `MockLmsClient`".** There is no production URL yet. |
| `SB_LMS_CLIENT_ID` | *(empty)* | OAuth/OIDC client identifier |
| `SB_LMS_TOKEN` | *(empty)* | Dev-only bearer token, read via `StaticTokenProvider` |
| `SB_LEADERBOARD_URL` | *(empty; falls back to `SB_LMS_BASE_URL`)* | Website origin that serves `/api/leaderboard` |
| `SB_PYTHON_RUNTIME` | *(platform default)* | `serious` \| `process` \| `fake` |
| `SB_PYTHON_EXECUTABLE` | `python` / `python3` | Interpreter for the desktop/dev runtime |
| `SB_GUARDIAN_REPORT_URL` | *(empty)* | **Empty means "never email progress reports".** URL of the mailer endpoint that renders the report and calls Resend with a server-side key (`guardian_mailer/`, never a key in the app) |
| `SB_AI_TUTOR_BASE_URL` | *(empty)* | Optional direct Cloudflare tutor Worker. Empty uses `<SB_API_BASE_URL>/api/tutor`; with both empty the offline tutor answers |
| `SB_API_BASE_URL` | *(empty)* | Website origin that serves `/api/auth` (the shared account layer). Empty means no cloud account, so no remote tutor either |

No secret belongs in any of these at rest. `SB_LMS_TOKEN` exists only so a
developer can hit a staging endpoint; production must use a real
`AuthTokenProvider` backed by platform secure storage.

The remote tutor needs **two** things, and silently falls back to the offline
brain if either is missing:

1. `SB_API_BASE_URL` — the website origin. It is used for sign-in (the Better
   Auth access JWT the Worker verifies) **and** as the tutor endpoint, because
the site proxies `/api/tutor/v1/tutor/*` to the Worker. The Worker URL itself
is server-side (`TUTOR_WORKER_URL` in the website environment), so moving it
never requires rebuilding the app. (There is no Supabase dependency in the app
any more; older docs mentioning `SB_SUPABASE_URL` were stale.)
2. A signed-in learner session with a non-empty token.

`SB_AI_TUTOR_BASE_URL` remains an optional override for builds that talk to the
Worker directly, bypassing the proxy.

On the Worker side, set `NEON_AUTH_BASE_URL` (the same value the website uses) so
it can fetch the JWKS; `NEON_AUTH_JWKS_URL`, `NEON_AUTH_ISSUER` and
`NEON_AUTH_AUDIENCE` can override it. See `guardian_mailer/README.md`.

## iOS

The project is scaffolded for iOS but has **never been built** (no macOS host
available). Expect to need:

```bash
cd ios && pod install && cd ..
export SERIOUS_PYTHON_APP="$PWD/build/python-app"
export SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/python-site-packages"
export SERIOUS_PYTHON_BUNDLE_ID=com.skillbridge.skillbridge_python_lab
dart run serious_python:main package python_app -p iOS
flutter build ios --release
```

Xcode signing, the minimum iOS version for `serious_python`, and the loopback
server's behaviour under iOS background-execution rules all need verification.

## CI recipe

A minimal pipeline that catches everything this repo currently catches:

```yaml
steps:
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: 3.47.7
  - uses: actions/setup-java@v4
    with:
      distribution: temurin
      java-version: '17'
  - uses: android-actions/setup-android@v3
  - run: sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "platforms;android-34" "build-tools;34.0.0" "ndk;28.2.13676358" "cmake;3.22.1"
  - uses: actions/setup-python@v5
    with:
      python-version: '3.12'
  - run: flutter pub get
  - run: flutter analyze
  - run: flutter test --reporter expanded
  - run: dart run serious_python:main package python_app -p Android --cleanup-app
    env:
      SERIOUS_PYTHON_APP: ${{ github.workspace }}/build/python-app
      SERIOUS_PYTHON_SITE_PACKAGES: ${{ github.workspace }}/build/python-site-packages
  - run: flutter build apk --debug
    env:
      SERIOUS_PYTHON_APP: ${{ github.workspace }}/build/python-app
      SERIOUS_PYTHON_SITE_PACKAGES: ${{ github.workspace }}/build/python-site-packages
```

Both Android steps need the *same* `SERIOUS_PYTHON_APP`: the package command
writes into it and Gradle reads back out of it. Dropping the env from either one
produces a hard failure, not a warning.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `flutter test` hangs until the timeout with no failure | A widget test awaiting the database. `testWidgets` runs in a fake-async zone; SQLite's FFI path schedules a real internal timer that never fires there | Route storage reads through `tester.runAsync` — see the `real()` helper in `test/widget_test.dart` |
| A widget test passes but the screen shows `Loading…` for ever | Same cause; the load future never resolves | As above |
| `flutter test` fails with "A Timer is still pending" | An indeterminate progress indicator, or an abandoned database future | Do not use `pumpAndSettle` around spinners; advance fixed time steps instead |
| `Error: Exception: SERIOUS_PYTHON_APP environment variable must be set for Android packaging` | `serious_python` 5.0.0 stages the processed app for the native build to pick up | Export `SERIOUS_PYTHON_APP` **and** `SERIOUS_PYTHON_SITE_PACKAGES` before the package command |
| `SERIOUS_PYTHON_SITE_PACKAGES environment variable is not set` at `build.gradle.kts:229` | The Android plugin requires *both* variables at Gradle configuration time — it fails before any task runs | Export it for `flutter build` too, not just for the package step. It may point at an empty directory |
| `Failed to install the following SDK components: platforms;android-34` | `connectivity_plus` compiles against SDK 34 even though the app targets 36 | `sdkmanager "platforms;android-34" "build-tools;34.0.0"` |
| `compressDebugAssets` fails on `kernel_blob.bin` / `stdlib.zip` / `sitepackages.zip` | Usually a stale Gradle daemon holding the files | `gradlew --stop`, then rebuild. Re-running the `serious_python` packaging also refreshes these |
| Desktop build fails on symlinks | Windows Developer Mode off | Enable Developer Mode or use an admin shell |
| `The embedded Python runtime did not start in time` | `python_app/` not packaged | Re-run the `serious_python` packaging command |
| Every network call fails in release but works in debug | Missing `INTERNET` permission | Already declared in `android/app/src/main/AndroidManifest.xml` |
| LMS calls fail with a TLS error on `http://127.0.0.1` | Network security config blocks cleartext | Already exempted for loopback in `res/xml/network_security_config.xml` |
| `Could not start "python"` | Interpreter not on `PATH` | Set `SB_PYTHON_EXECUTABLE` |
