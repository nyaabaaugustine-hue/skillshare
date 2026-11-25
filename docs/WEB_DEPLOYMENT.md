# Web deployment

The Flutter app is **not** served from the site root. It is served from
`/app/index.html` by the Next.js app in `.work/academy-live/public/app`.
Building with the default `/` base href breaks the live app: the generated
`index.html` asks for `/main.dart.js`, which returns 404. Always use
`--base-href=/app/`.

## Build and sync

From the Flutter repo root:

```powershell
flutter build web --release --base-href=/app/ `
  --dart-define=SB_FCM_VAPID_KEY=BPc1Ed7KtjSKLU8l9ni0MsOk-oii_HpLSMp1A_VDhvRYuVmVb3ozFcuZUFquT5GRursvWhSCXnJu7kfZpfVSFI4
```

Check before copying:

```powershell
Select-String -Path build\web\index.html -Pattern '<base href'
# expected: <base href="/app/">
```

Copy into the site without deleting site-only files such as
`public/app/apple-touch-icon.png`:

```powershell
robocopy build\web .work\academy-live\public\app /E
```

`robocopy` exit codes 0–3 are success. Confirm the FCM/offline worker is present:

```powershell
Test-Path .work\academy-live\public\app\firebase-messaging-sw.js
```

Do not hand-edit `main.dart.js` to add the AI tutor icon. The Cloudinary icon
URL now lives in `lib/features/ai/ai_tutor_screen.dart`, so every clean build
includes it and the backend test
`compiled Flutter app includes AI tutor icon URL` stays green. The older
`scripts/patch-app-robot.mjs` in the website repo is kept only for the one-off
label change; it is not part of the normal build.

## Deploy

From `.work/academy-live`:

```powershell
npx --yes vercel@latest --prod --yes
```

The direct deploy includes uncommitted static files; commit them separately.

## Verify production

```powershell
$base = 'https://www.skillbridgeacademy.tech'
foreach ($p in @('/api/health', '/', '/app/index.html', '/app/main.dart.js',
                 '/app/flutter_bootstrap.js', '/app/firebase-messaging-sw.js')) {
  "$p = $(curl.exe -s -o NUL -w '%{http_code}' ($base + $p))"
}
curl.exe -s ($base + '/app/index.html') | Select-String '<base href'
```

Expected: every checked path returns 200 and the base href is `/app/`.
`/main.dart.js` at the site root should be 404 — that is correct.

## Service workers

There are two deliberately separate workers:

| Worker | Scope | Purpose |
| --- | --- | --- |
| `/sw.js` | `/` | Website's existing direct Web Push system |
| `/app/firebase-messaging-sw.js` | `/app/` | FCM announcements + app-shell offline cache |

`PushService` registers the `/app/` worker explicitly because Firebase's default
`/firebase-messaging-sw.js` does not exist on this site. Do not copy the FCM
worker to the root: registering it at `/` would replace the website's direct
push worker.

The `/app/` worker uses stale-while-revalidate for static assets and
network-first-with-cache-fallback for navigations. Bump `CACHE_NAME` in
`web/firebase-messaging-sw.js` if a clean cache is ever needed.

## Browser check performed

The live app was opened in connected Chrome and manually verified:

- `/app/index.html` boots with `<base href="/app/">` and renders the CanvasKit
  surface.
- The scoped worker registers at scope `/app/` and activates from
  `/app/firebase-messaging-sw.js`.
- Its `skillbridge-app-v1` cache contains the app shell (`index.html`,
  `main.dart.js`, `flutter.js`, `flutter_bootstrap.js`, manifests and icons).
- Flutter's fallback font requests are fetched from `fonts.gstatic.com`; the
  site CSP was updated to allow that origin in `connect-src`.
- The same CSP allows the Firebase Installations and FCM subscription endpoints
  used by web push. Without them the worker can load but token registration or
  message delivery can be blocked.
- A browser-harness offline emulation detached the service-worker controller,
  so that attempt was **not** treated as evidence that offline reload works.

## Still unverified

- Offline reload after closing the browser/PWA and returning later.
- Real FCM background notification and tap routing on web.
- End-to-end announcement deep link after a real notification tap. The parser
  is unit-tested, and the app deliberately defers fragment routing until the
  splash and auth bootstrap finish; it does not use `MaterialApp.initialRoute`,
  which would build the detail route before its providers exist.

Use Chrome DevTools → Application → Service Workers and Network → Offline to
check the remaining items before claiming the web app is truly offline.
