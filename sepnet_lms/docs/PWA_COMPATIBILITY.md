# PWA conversion and browser compatibility

The Flutter app now ships as an installable, offline-capable Progressive Web
App. This document records what was changed, what was verified on this machine,
and what each browser and platform can and cannot do with it.

Status at the time of writing: **verified on Chromium 141 (Windows) only.** No
iOS, Firefox, Samsung Internet or Android hardware was available here. Claims
about those browsers are expectations from platform documentation and the
plugins' own web support, not measurements — they are marked accordingly.

## 1. Why work was needed

The web target already existed (`flutter build web`, `web/manifest.json` with
192/512 icons, `id`/`start_url`/`scope` of `/app/`), so the app was already
*installable*. It was not *offline*: Flutter 3.47 generates a
`flutter_service_worker.js` whose entire body unregisters itself, and
`--pwa-strategy` no longer exists. An installed app opened without a network
showed the browser's offline error (see `KNOWN_LIMITATIONS.md`, limitation 6,
before this change).

## 2. What changed

| File | Change |
| --- | --- |
| `web/sw.js` (new) | Cache-backed service worker. Pre-caches the 22-file boot set; cache-first for same-origin app assets; network-first navigations with a cached-shell fallback; versioned caches (`skillbridge-shell-v4`, `skillbridge-runtime-v4`) cleaned on activate; `/api/` calls, cross-origin media, and Range requests never cached. |
| `tool/build_web.ps1` | After a successful build, copies `web/sw.js` over the generated `build/web/flutter_service_worker.js`. Flutter's bootstrap registers that exact file, so there is one script and one registration. |
| `web/index.html` | Registers `flutter_service_worker.js` at scope `./`; adds `apple-mobile-web-app-capable`, a 180×180 `apple-touch-icon`, and aligns `theme-color` with the manifest (`#1697F5`). |
| `web/manifest.json` | Adds `display_override: ["standalone", "minimal-ui"]` and `categories: ["education", "productivity"]`. |
| `web/apple-touch-icon.png` (new) | 180×180 PNG generated from `web/icons/Icon-192.png`; iOS ignores manifest icons for the home-screen tile. |

Two competing registrations were deliberately avoided. Registering a second
worker on `/app/` makes the two replace each other; during this work that left
the page uncontrolled while Flutter's worker unregistered itself. That is why
the caching worker is installed *as* `flutter_service_worker.js` instead of
next to it.

## 3. What was verified here

Build: `tool/build_web.ps1` → `flutter build web --release --no-web-resources-cdn
--base-href=/app/ --dart-define=SB_API_BASE_URL=…`, exit 0, 419 s compile.
Served from a static server at `http://127.0.0.1:8099/app/` (equivalent to the
website hosting `build/web` in `public/app`).

| Check | Result |
| --- | --- |
| `index.html`, `manifest.json`, `flutter_service_worker.js` served | 200, correct content types (`text/javascript` for the worker) |
| Manifest contents | `name`, `id`/`start_url`/`scope` = `/app/`, `display: standalone`, `display_override`, 192/512 + maskable icons, `theme_color` |
| `apple-touch-icon.png` | 200, `image/png`, 180×180 |
| Service worker registration | active, scope `http://127.0.0.1:8099/app/`, script `flutter_service_worker.js` |
| Page controlled by the worker | yes (`navigator.serviceWorker.controller` set) |
| Pre-cache | 22 entries in `skillbridge-shell-v4` (document, loader, `main.dart.js`, CanvasKit js/wasm for both renderer paths, fonts, manifests, icons) |
| App boots online | yes (`<flutter-view>` present) |
| **App boots with the server stopped** | yes — reload with nothing listening on 8099 still painted the app |
| **Cache serves while offline** | `fetch(..., {cache:'no-store'})` for `canvaskit/canvaskit.js` (87 KB), `assets/FontManifest.json` and `manifest.json` returned 200 from the worker with the server down |

Not verified, and not claimed:

* The real install prompt, standalone window chrome, and home-screen icon on a
  phone or tablet (desktop Chromium in a test profile only).
* iOS/Safari, Firefox, Samsung Internet.
* Lighthouse/installability audits.
* Python execution offline. Pyodide (~14 MB) is runtime-cached, not
  pre-cached, so the first *offline* run only works after a prior online run
  that used the editor.
* Multi-day storage-quota behaviour and eviction.

## 4. Browser and platform matrix

| Browser / platform | Install | Standalone window | Service worker | Wasm (Python via Pyodide) | Notes |
| --- | --- | --- | --- | --- | --- |
| Chrome / Edge — desktop | Yes, install icon in the address bar | Yes | Yes | Yes | Fully verified path on desktop Chromium. |
| Chrome — Android | Yes, install prompt / "Add to Home screen" | Yes | Yes | Yes | Expect a slow first paint on low-end phones: the shell alone is ~11 MB before Python. |
| Samsung Internet | Yes | Yes | Yes | Yes | Chromium-based; expect parity with Chrome. |
| Safari — iOS 16.4+ / iPadOS | Manual: Share → Add to Home Screen (no `beforeinstallprompt`) | Yes, with `apple-mobile-web-app-*` meta | Yes | Yes | Uses `apple-touch-icon`. No push (unused here). iOS may evict site data for long-unused sites — drafts in IndexedDB are at risk. |
| Safari — macOS (Sonoma+) | File → Add to Dock | Yes | Yes | Yes | Icon comes from the manifest. |
| Firefox — desktop | Yes ("Install" in the address bar, 115+) | Yes | Yes | Yes | CanvasKit rendering is heavier than on Chromium. |
| Firefox — Android | No install UI | n/a | Yes (runs as a normal site) | Yes | Usable, but not installable. |
| Older/embedded browsers without Wasm | No | No | No | No | Flutter web itself needs a modern JS engine; below that the app does not load at all. |

## 5. Feature-by-feature compatibility

Evidence column names the code path that decides the behaviour.

| Feature | Web behaviour | Evidence |
| --- | --- | --- |
| UI, lessons, editor, navigation | Full parity with native UI | Dart UI, CanvasKit renderer |
| Python execution | Real CPython through Pyodide in a worker; needs Wasm and the ~14 MB runtime | `web/pyodide_worker.js`, `python_runtime_factory` → `PythonRuntimeKind.pyodide` on `kIsWeb` (`app_config.dart:188`) |
| Execution time limit | Python-side output caps apply; the `SIGALRM`/watchdog half is inert (Pyodide has no threads) | existing `KNOWN_LIMITATIONS.md` 6 |
| Offline drafts and submissions | SQLite compiled to Wasm, persisted in IndexedDB | `database_factory_web.dart` → `sqflite_common_ffi_web` |
| Storage durability | Tied to site data; clearing site data or browser eviction loses drafts. Never encrypted (native parity) | `database_factory_web.dart`, limitations 13 |
| Sign-in / shared account | Works when the bundle is served from the same origin as `/api/auth` (the site's `/app/`); the browser sends its HttpOnly Neon Auth cookie and `kIsWeb` skips the manual cookie jar | `cloud_auth.dart:417,460,526` |
| Cross-origin hosting of `/app/` | Not supported: the cookie would not be sent, and the tutor/CORS setup assumes one origin | `cloud_auth.dart`, `docs/BUILD_AND_RELEASE.md` |
| Remote AI tutor / leaderboard | Need the network; the offline tutor answers when the API is unreachable | `ai_tutor_screen.dart`, `lms_hub_screen.dart` |
| Local reminders / notifications | Not available — the web build uses a no-op scheduler | `reminders.dart` → `reminders_stub.dart` |
| Text to speech | `speechSynthesis`; voice list varies by OS/browser, iOS needs a user gesture | `flutter_tts`, `ai_tutor_screen.dart` |
| Speech to text | Web Speech API; Chrome/Edge good, Safari partial, Firefox limited — unverified here | `speech_to_text`, `ai_tutor_screen.dart` |
| Video lessons | `<video>` element; Cloudinary MP4 (H.264/AAC) plays on Chrome/Edge/Safari and on Firefox where the OS codec is present. Autoplay with sound is blocked until a gesture | `video_player`, `cloudinary_video_screen.dart` |
| Camera / gallery image pick | Browser file picker; camera capture depends on the OS and browser | `image_picker` |
| Handout download | Blob + `<a download>` — works in all current browsers | `handout_saver_web.dart` |
| Certificate save | No filesystem path in a browser: the app asks the learner to right-click → "Save image as…" | `lms_hub_screen.dart:1647` |
| Offline app shell | Yes, after the first online visit (pre-cached) | `web/sw.js` |
| Offline Python / handouts | Only after that asset was fetched once online | `web/sw.js` runtime cache |
| Accessibility | CanvasKit draws to a canvas; without Flutter's semantics tree enabled a screen reader sees almost nothing. Not audited on any platform | limitation 31 |
| Deep links / back button | The app is a single entry point with no URL routes; browser back leaves the app rather than moving between screens | app structure |

## 6. Hosting requirements

The bundle must keep working when copied into the website (`build\web\*` →
`website\public\app`), as `docs/BUILD_AND_RELEASE.md` describes:

1. **HTTPS** (or `localhost`). Service workers and install are refused
   otherwise; registration is skipped on insecure origins by design.
2. **Same origin as `/api/auth`.** `/app/` is served by the Next.js site so the
   sign-in cookie is in scope. A CDN on another hostname breaks auth and is not
   supported.
3. **Serve `flutter_service_worker.js` with `Content-Type: text/javascript`**
   and short-lived caching (`Cache-Control: no-cache`). A long max-age on the
   worker delays every future update.
4. **CSP must allow WebAssembly compilation** (`script-src 'wasm-unsafe-eval'`,
   or `'unsafe-eval'` where the older equivalent is needed). CanvasKit and
   Pyodide both compile `.wasm`; a `wasm-unsafe-eval`-less policy makes the app
   render blank/never start Python.
5. **No COOP/COEP needed.** Pyodide runs without `SharedArrayBuffer` and
   `sqflite_common_ffi_web` persists to IndexedDB, so the site does not need
   cross-origin isolation (which would break the framed `/learn` page).
6. **Ship the whole folder**: `flutter_service_worker.js`, `manifest.json`,
   `apple-touch-icon.png`, `icons/`, `canvaskit/`, `assets/`, `pyodide/`,
   `sqlite3.wasm`, `sqflite_sw.js`. Dropping any of them breaks offline or
   Python. `*.js.symbols` files can be dropped.

Size to plan for: `build/web` ≈ 58 MB (CanvasKit 37 MB, Pyodide 14 MB,
`main.dart.js` 3.6 MB). Serve with gzip/brotli — `main.dart.js` drops from
3.6 MB to 1.1 MB. Only one CanvasKit renderer variant is downloaded at run
time, so the 37 MB is not a per-learner cost, but the host does store it.

## 7. Remaining gaps and sensible next steps

* **Pyodide is not pre-cached** (14 MB). Caching it would make a first-ever
  offline run possible but imposes a large download on every install; the
  current trade-off favours the learner's data bundle. Revisit if classrooms
  hand out devices that are offline from day one.
* **No "new version available" prompt.** The worker takes control immediately
  (`skipWaiting` + `clients.claim`), so a deploy is picked up on the next
  launch rather than mid-session. A prompt would need a small Dart/JS bridge.
* **Storage eviction is not handled.** A learner whose browser clears site data
  loses drafts; native does not have this failure mode.
* **No real-device or iOS testing**, and no Lighthouse installability audit.
* **Reminders/notifications remain native-only.**
