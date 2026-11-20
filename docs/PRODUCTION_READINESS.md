# Production Readiness — SkillsBridge / Sepnet LMS

Single source of truth for **what runs where**, **which config each unit needs**,
and **what is still broken** before the app can be launched.

Last reviewed: 2026-11-19.

---

## 1. The four units

| Unit | Lives in | Runs on | Notes |
| --- | --- | --- | --- |
| Website | `website/` | Vercel (Next.js 16, nodejs runtime routes) | marketing pages, `/learn` iframe shell, `/api/*` proxy + auth + leaderboard + uploads |
| Tutor Worker | `guardian_mailer/` | Cloudflare Workers | `skillbridge-tutor` — Workers AI chat/vision/video, guardian email, Durable Object rate limiter |
| Flutter app | `sepnet_lms/` | Android (primary), iOS (never built), web (UI only) | embedded CPython via `serious_python` |
| Data | Neon | Neon Postgres + Neon Auth (Better Auth) + Neon Object Storage (S3-compatible) | no Supabase any more |

**Request path for the AI tutor** (the flagship feature):

```
Flutter app  --(Neon JWT)-->  Website /api/tutor/v1/tutor/*  --(bearer)-->  Worker  --> Workers AI
   sign-in via /api/auth                                          verifies JWT via JWKS
```

Every link must be configured or the tutor silently degrades to the offline brain.

---

## 2. Unit status matrix

Verified live against the deployed Worker and Vercel site on 2026-11-19.

| Unit | Status | Evidence / blocker |
| --- | --- | --- |
| Accounts + sign-in | **OK** | Neon Auth reachable; `/api/auth` proxies sign-in |
| Leaderboard read/write | **OK** | Neon Postgres + `leaderboard_entries` table |
| AI tutor chat (code) | **Fixed, needs redeploy** | site previously returned `503 tutor_unavailable`; now defaults to the Worker URL (see §3.1) |
| AI tutor chat (live) | **Blocked on config** | APK must be rebuilt with `SB_API_BASE_URL`; Vercel must know the Worker URL |
| AI tutor vision | **OK when chat works** | same proxy, `@cf/meta/llama-3.2-11b-vision-instruct` |
| Tutor video resources | **BROKEN** | Worker `/health` → `video_configured:false` — `YOUTUBE_API_KEY` missing |
| Guardian progress email | **BROKEN** | Worker `/health` → `email_configured:false` — `RESEND_API_KEY` missing |
| File uploads | **BROKEN** | site `/api/health` → `storage:"error"` — `AWS_*` (Neon Object Storage) not set in Vercel |
| `/learn` web app embed | **BROKEN** | prod iframe `src` still points at `http://localhost:8080`; no host for the Flutter web build |
| Worker rate limit | **OK** | `/health` → `rate_limit_configured:true` (Durable Object bound) |
| Worker AI + auth | **OK** | `/health` → `ai_configured:true`, `auth_configured:true` |

Worker `/health` is the fastest way to re-check the Worker half:

```powershell
curl.exe https://skillbridge-tutor.skillsbridg-academy.workers.dev/health
```

---

## 3. Environment contract

Treat env as a **reviewed contract**: one list here, no guessing. Anything marked
**required** means a unit is broken without it.

### 3.1 Website — Vercel project env

| Variable | Required | Purpose | If missing |
| --- | --- | --- | --- |
| `NEON_AUTH_BASE_URL` | yes | Neon Auth (Better Auth) endpoint | app throws at import (`lib/auth/server.ts`) |
| `NEON_AUTH_COOKIE_SECRET` | yes | session cookie signing | sign-in fails |
| `DATABASE_URL` | yes | Neon Postgres (pooled) | leaderboard + progress fail |
| `TUTOR_WORKER_URL` | recommended | `.../api/tutor` proxy target | falls back to the hard-coded default in `app/api/tutor/[...path]/route.ts` |
| `FLUTTER_APP_ORIGIN` | yes (for `/learn`) | origin allowed to be iframed + CORS | `/learn` shows "not linked"; tutor CORS rejects the web app |
| `NEXT_PUBLIC_LEARN_URL` | yes (for `/learn`) | iframe `src` for the Flutter web build | `/learn` renders the "not linked yet" notice |
| `AWS_ENDPOINT_URL_S3` | yes (uploads) | Neon Object Storage endpoint | `/api/health` → `storage:"error"`, uploads fail |
| `AWS_REGION` | yes (uploads) | S3 region | same |
| `AWS_ACCESS_KEY_ID` | yes (uploads) | S3 key | same |
| `AWS_SECRET_ACCESS_KEY` | yes (uploads) | S3 secret | same |
| `AWS_S3_BUCKET_NAME` | optional | uploads bucket | falls back to the default bucket name |

`FLUTTER_APP_ORIGIN` wins over `NEXT_PUBLIC_LEARN_URL` when both are set
(`lib/flutter-app-origin.ts`).

### 3.2 Tutor Worker — Cloudflare secrets/vars

Set with `wrangler secret put <NAME>` in `guardian_mailer/`.

| Name | Required | Purpose | If missing |
| --- | --- | --- | --- |
| `YOUTUBE_API_KEY` | for video | lesson video suggestions | `/health` → `video_configured:false`, video button latches off |
| `RESEND_API_KEY` | for email | guardian progress email | `/health` → `email_configured:false`, email send fails |
| `NEON_AUTH_ISSUER` / JWKS origin | yes | verify the JWT the website forwards | tutor returns `401 unauthorized` |
| `RESEND_FROM` | optional | sender address | uses the code default |

### 3.3 Flutter app — `--dart-define` (compile time)

| Define | Required | Purpose |
| --- | --- | --- |
| `SB_API_BASE_URL` | **yes for release** | enables cloud sign-in + the tutor proxy; empty ⇒ guest/offline mode |
| `SB_LEADERBOARD_URL` | optional | overrides the leaderboard host (defaults to `SB_API_BASE_URL`) |
| `SB_GUARDIAN_REPORT_URL` | optional | guardian report endpoint |
| `SB_ENV` | optional | `production` forces cloud auth |

`SB_API_BASE_URL` is what flips `cloudAuthEnabled` to true in
`lib/core/config/app_config.dart`. **An empty value is the single most common
cause of "Cloudflare AI not working".**

---

## 4. Plan (10 items)

| # | Item | Status |
| --- | --- | --- |
| 1 | This document: plan + environment contract | **done** |
| 2 | Fail loudly on missing config: build-time assert + in-app online/offline banner | **done** |
| 3 | Android release signing (git-ignored `keystore.properties`) | **done** |
| 4 | Rate limit public write endpoints | **done** |
| 5 | Enforcing Content-Security-Policy on the website | **done** |
| 6 | CI/CD: `flutter-ci` + `release` in `sepnet_lms/.github/`, `website-ci` in `website/.github/`, `worker-tests` + `uptime` at the repo root | **done** |
| 7 | Observability: health monitor + alerting | **done** |
| 8 | Repo cleanup: stale Supabase migration, temp files, committed artifacts | **done** |
| 9 | Web app hosting: `sepnet_lms/tool/build_web.ps1` + guide in `BUILD_AND_RELEASE.md` | **done** |
| 10 | Device smoke test: `sepnet_lms/tool/smoke_test.ps1` for the embedded Python runtime | **done** |

---

## 5. Launch checklist

Ordered so each step unblocks the next.

1. **Worker secrets** (§3.2): `wrangler secret put YOUTUBE_API_KEY` and
   `RESEND_API_KEY`; re-check `/health` shows both `true`.
2. **Vercel env** (§3.1): add the four `AWS_*` values; set `FLUTTER_APP_ORIGIN`
   and `NEXT_PUBLIC_LEARN_URL` once the web build is hosted. Redeploy.
3. **Web build hosting**: run `sepnet_lms/tool/build_web.ps1`, host the
   resulting `build/web` (any static host), then set `NEXT_PUBLIC_LEARN_URL`
   and `FLUTTER_APP_ORIGIN` to that exact origin. See "Hosting the web build"
   in `sepnet_lms/docs/BUILD_AND_RELEASE.md`.
4. **Rebuild the APK/AAB** with `SB_API_BASE_URL` set:
   `sepnet_lms/tool/build_apk.ps1` (debug) or the `release.yml` workflow (AAB).
5. **Rotate credentials** that ever sat in a tracked file (`.env.local`), then
   confirm `/api/health` → `status:"ok"`.
6. **Device smoke test**: run `sepnet_lms/tool/smoke_test.ps1` to prove the
   embedded CPython actually executes on a device. Then sign in and ask the
   tutor one question with Wi-Fi on — the app must show **Online**, not
   **Fallback**.

Dashboard-only items (need owner access, cannot be done from the repo): the
Vercel env values, the Worker secrets, and the credential rotation in step 5.
