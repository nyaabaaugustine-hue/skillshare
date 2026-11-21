/*
 * SkillBridge Academy — PWA service worker.
 *
 * Flutter 3.47 no longer ships a cache-backed worker: the generated
 * `flutter_service_worker.js` only unregisters itself, so an installed app
 * cannot start without a network. This worker replaces it.
 *
 * Strategy
 *  - Install caches the boot shell (document, loader, compiled Dart, icons).
 *  - Runtime requests under the app's scope are cache-first, so the CanvasKit
 *    renderer, sound fonts, handouts, course images and the Pyodide runtime are
 *    kept after the first time the app asks for them.
 *  - Navigations are network-first with a cached-shell fallback, so a deploy
 *    reaches learners on the next visit and a cold, offline launch still boots.
 *  - Cross-origin requests (Cloudinary video/images) and /api/ calls are never
 *    cached: they need live data or are large media the browser handles itself.
 *  - Range requests are passed through untouched; video seeking depends on them.
 *
 * Bump CACHE_VERSION when the shell file list or strategy changes. The old
 * caches are deleted on activate, and the new worker takes control at once.
 */
'use strict';

const CACHE_VERSION = 'v4';
const SHELL_CACHE = `skillbridge-shell-${CACHE_VERSION}`;
const RUNTIME_CACHE = `skillbridge-runtime-${CACHE_VERSION}`;

// Everything the browser asked for before the first frame was on screen
// (observed in a real Chromium session). Without these, an offline launch
// paints an empty page instead of the app.
const SHELL = [
  './',
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'favicon.png',
  'apple-touch-icon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/fonts/fallback/Roboto-Regular.ttf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'assets/assets/icon/app_mark.png',
];

const SCOPE_PATH = new URL(self.registration.scope).pathname;

const inScope = (url) => url.pathname.startsWith(SCOPE_PATH);

const isApi = (url) => url.pathname.includes('/api/');

const isWorker = (url) => url.pathname.endsWith('/sw.js');

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL_CACHE);
      // Tolerant on purpose: one missing icon must not fail the whole install.
      await Promise.all(
        SHELL.map((path) =>
          cache.add(new Request(path, { cache: 'reload' })).catch(() => {}),
        ),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keep = new Set([SHELL_CACHE, RUNTIME_CACHE]);
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith('skillbridge-') && !keep.has(name))
          .map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin || !inScope(url) || isWorker(url)) return;
  if (isApi(url)) return;
  if (request.headers.has('range')) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const response = await fetch(request);
          if (response.ok) {
            // Awaited inside respondWith: a put that is merely started can be
            // dropped when the worker goes idle after the response lands.
            const cache = await caches.open(SHELL_CACHE);
            await cache.put('index.html', response.clone()).catch(() => {});
          }
          return response;
        } catch {
          const cache = await caches.open(SHELL_CACHE);
          return (
            (await cache.match('index.html')) ||
            (await cache.match('./')) ||
            Response.error()
          );
        }
      })(),
    );
    return;
  }

  event.respondWith(
    (async () => {
      // ignoreSearch: Flutter appends a build query to some asset URLs, and a
      // precached path must still answer for `path?v=…`.
      const cached = await caches.match(request, { ignoreSearch: true });
      if (cached) return cached;
      try {
        const response = await fetch(request);
        if (response.ok && response.type === 'basic') {
          const cache = await caches.open(RUNTIME_CACHE);
          await cache.put(request, response.clone()).catch(() => {});
        }
        return response;
      } catch (error) {
        return cached || Response.error();
      }
    })(),
  );
});
