# Guardian report mailer

Small Worker that emails a learner's progress report to their Parent / Guardian
through [Resend](https://resend.com). The Flutter app never holds a Resend key:
it posts a structured report here and this Worker renders the email.

## Why a server is required

A Resend API key compiled into an APK can be extracted from the bundle by anyone
who unzips it. A key that can email the parents of children must stay
server-side, so the app only knows this endpoint's URL.

## Setup

1. Create a Resend account and an API key (`re_...`).
2. Verify the sending domain in Resend (Domains → Add domain → DNS records).
   Until then Resend only accepts `onboarding@resend.dev` as `from`.
3. Deploy this Worker (see below) and note its URL, e.g.
   `https://guardian-mailer.example.workers.dev`.
4. Configure the Worker:
   - Workers AI is bound as `AI` in `wrangler.jsonc`; no Cloudflare API token is
     needed by the deployed Worker.
   - `CF_AI_MODEL` defaults to the supported
     `@cf/meta/llama-4-scout-17b-16e-instruct`. The previous
     `@cf/meta/llama-3.1-8b-instruct-fp8-fast` ID is no longer in Cloudflare's
     current model catalog.
   - Set `NEON_AUTH_JWKS_URL`, `NEON_AUTH_ISSUER`, and
     `NEON_AUTH_AUDIENCE` from the same Neon Auth branch used by the website.
     The Worker verifies a signed JWT locally against JWKS and fails closed if
     any value is missing. Do not point it at an unverified issuer or audience.
   - The verifier requires `sub` and rejects `o.role = "member"` (the guardian
     marker). Student tokens no longer need to carry any organisation claim, so
     a learner outside a family group still works.
   - `TUTOR_RATE_LIMITER` is a Durable Object binding. Production fails closed
     for tutor requests if it is missing.
   - Set `AI_ALLOWED_ORIGINS` to the exact deployed web-app origin(s). Native
     Android/iOS clients do not send an Origin header.
   - Before launch, rotate any Cloudflare, Resend, or other credentials that
     were previously exposed. Do not copy values from the legacy `.env` file.
   - Set `RESEND_API_KEY` as a secret and `MAIL_FROM` as a verified sender.
   - For short videos, set `YOUTUBE_API_KEY` as a secret and
     `YOUTUBE_ALLOWED_CHANNEL_IDS` to a curated list of trusted education
     channels. Only short videos with captions are returned. Video lookup
     remains disabled without both settings.

   For local development, copy `.dev.vars.example` to `.dev.vars`, fill in
   local values, then run `npm install` and `npm run dev`. `.dev.vars` is not
   committed. The legacy `.env` file is not read by the Worker.
5. Deploy with `npm run deploy`. The first deployment provisions the
   `TutorRateLimiter` Durable Object migration. Add any secrets using
   `npx wrangler secret put <NAME>`; never put them in the Flutter build or in
   committed config.
6. **Preferred:** point the website at the Worker once — set
   `TUTOR_WORKER_URL` in `website/.env.local` — and build clients with only
   `--dart-define=SB_API_BASE_URL=https://<website>`. The site's
   `/api/tutor/v1/tutor/*` route forwards the bearer token and streams the
   answer back, so there is one origin, no CORS preflight and nothing extra to
   rebuild when the Worker moves. `SB_AI_TUTOR_BASE_URL` still overrides it for
   direct-to-Worker builds.

   Build the app with the Worker URL **and** the website origin. `SB_API_BASE_URL`
   is what lets the learner sign in and obtain the Better Auth access JWT the
   Worker verifies — without it `cloudAuthEnabled` is false, the remote tutor is
   never attempted, and the app answers from the offline brain with no error
   shown. The old note that the Flutter client was Supabase-based is obsolete:
   the app no longer reads `SB_SUPABASE_*` at all.
   ```
   --dart-define=SB_AI_TUTOR_BASE_URL=https://<worker> `
   --dart-define=SB_API_BASE_URL=https://<website> `
   --dart-define=SB_GUARDIAN_REPORT_URL=https://<worker>/guardian-report
   ```

Without `SB_GUARDIAN_REPORT_URL` the app silently skips progress emails; the
rest of the app is unaffected.

## Deployed instance

| Item | Value |
|---|---|
| Worker URL | `https://skillbridge-tutor.skillsbridg-academy.workers.dev` |
| Website proxy | `TUTOR_WORKER_URL` in `website/.env.local` (already set) |
| `/health` | `ai_configured: true`, `auth_configured: true`, `rate_limit_configured: true` |
| Auth secret | `NEON_AUTH_BASE_URL` set from the website value; JWKS derived as `<base>/.well-known/jwks.json` |

Smoke test (401 is the correct answer without a learner token — it proves the auth check ran):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'content-type: application/json' -d '{"message":"hi"}' \
  https://skillbridge-tutor.skillsbridg-academy.workers.dev/v1/tutor/chat
```

## Tutor endpoints

- `GET /health` reports whether AI, auth, rate limiting, and optional video
  search are configured. It never returns tokens or learner information.
- `POST /v1/tutor/chat` returns a short learner-safe explanation and curated
  links to official Python documentation.
- `POST /v1/tutor/chat/stream` streams the Workers AI response using SSE.
- `POST /v1/tutor/vision` analyzes a learner-selected code/error screenshot.
- `POST /v1/tutor/resources` returns captioned short videos only from the
  configured trusted-channel allowlist. The app calls it only when the learner
  asks for a video after the tutor has explained the topic.

Every tutor route requires a valid, signed Neon JWT from the configured issuer
(and audience, when one is configured). Guardian sessions (`o.role === "member"`)
are rejected with 403, so the student-only policy is enforced server-side rather
than only in the UI. Requests are rate-limited per verified subject, the budget
is spent only after the payload validates, and prompts and tokens are never
logged. Unsafe input and output are filtered and contact details are redacted.

**Migration status:** the Flutter client signs in through the website's Neon
Auth proxy and sends the access JWT; there is no Supabase dependency any more.
The Worker refreshes nothing itself - the app refreshes the JWT before it
expires or after a 401. The only unverified piece is Neon's exact production
claim shape, which the synthetic tests exercise but cannot reproduce.

## Local test

```bash
RESEND_API_KEY=re_test node --input-type=module -e "
  const worker = (await import('./worker.mjs')).default;
  const res = await worker.fetch(
    new Request('http://localhost/health'),
    { RESEND_API_KEY: 're_test' },
  );
  console.log(res.status, await res.text());
"
```

## Contract used by the app

`POST /guardian-report`

```json
{
  "studentName": "Ama Mensah",
  "guardianName": "Kofi Mensah",
  "guardianEmail": "kofi@example.com",
  "reportKey": "progress-local-ab12cd34ef-2026-11-12",
  "report": {
    "generatedAt": "2026-11-12T09:10:00.000Z",
    "averageScore": 84,
    "attempted": 5,
    "totalSteps": 12,
    "retries": 2,
    "steps": [
      {
        "title": "Hello, Python",
        "kind": "Coding",
        "score": 84,
        "attempts": 2,
        "band": "Developing",
        "weak": true,
        "advice": "Practise writing and running this code a little each day."
      }
    ]
  }
}
```

`200 {"ok":true,"id":"<resend-id>"}` on success. Errors are
`400` (validation), `413` (payload too large), `502` (Resend refused or was
unreachable) and `503` (no `RESEND_API_KEY`).

`reportKey` is sent to Resend as the `Idempotency-Key`, so a retry — or a second
tap on the same day — does not deliver a duplicate email.

## Abuse notes

The endpoint is public, because a mobile app cannot keep a secret. Guards:

- the body must match the report schema; it cannot carry arbitrary HTML, a
  custom subject or extra recipients, so it is not usable as an open relay;
- one recipient per request, validated, with size and length limits.

It can still be used to send *report-shaped* email to an arbitrary address, so
put Cloudflare rate limiting (or a WAF rule) in front of it before launch, and
rotate the key if you see unexpected traffic.


## Tutor auth configuration (read this if the tutor answers offline)

The Worker verifies the learner's Better Auth access JWT before calling Workers
AI. Set **one** of these on the Worker (`wrangler secret`/vars or the dashboard):

| Variable | Meaning |
|---|---|
| `NEON_AUTH_BASE_URL` | Same value the website uses. The Worker derives `<base>/.well-known/jwks.json` as the key set and uses the base as the issuer |
| `NEON_AUTH_JWKS_URL`, `NEON_AUTH_ISSUER`, `NEON_AUTH_AUDIENCE` | Explicit overrides. The audience is only checked when it is set; with `NEON_AUTH_BASE_URL` alone no `aud` claim is required. |

`GET /health` reports `auth_configured`, `ai_configured` and
`rate_limit_configured` as booleans without exposing any host or key.

Two policy bugs used to make every call fail and are now covered by tests:

- the tutor required the Neon organisation claim `o.role === "owner"`, which no
  learner token carries → every request was `403 student_session_required`
  (guardians, whose role is `member`, are now deliberately rejected instead);
- an empty `AI_ALLOWED_ORIGINS` with `APP_ENV=production` rejected every request
  that carried an `Origin` header, i.e. the entire web app → `403 origin_not_allowed`.
  The list is now enforced only when it is non-empty.
