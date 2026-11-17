# AI tutor and learner context

The tutor works offline for everyone. Only a signed-in learner account can use
the Cloudflare AI routes; guests and guardian accounts stay on the offline
tutor. The Worker validates the Supabase access token, requires the
server-managed `app_metadata.role = student` claim, and rate-limits requests
by user.

## Worker routes

- `POST /v1/tutor/chat` returns a short explanation and allowlisted Python
  documentation sources.
- `POST /v1/tutor/chat/stream` streams the answer as server-sent events.
- `POST /v1/tutor/vision` analyzes a learner-selected screenshot after an
  in-app preview and send confirmation.
- `POST /v1/tutor/resources` returns short videos only when the learner asks
  after receiving an explanation. Results are restricted to configured,
  trusted YouTube channels and videos with captions.

The Worker does not persist chat history. The app sends only recent turns for
conversation context, along with the active learner's minimum tutoring
context. Screenshots are sent only after the learner confirms the preview.

## Context sent to the tutor

Only the active learner's tutoring context is allowed:

- display name
- server-authoritative total points
- completed and total challenges
- weak course steps and latest scores

The app does **not** send auth tokens as prompt content, email addresses,
guardian records, raw submission history, or unrelated learners. The access
token is sent only in the HTTPS authorization header so the Worker can validate
the session with Supabase Auth.

Remote tutor implementations should explain in small steps, show short worked
Python examples, ask a useful follow-up question, encourage effort without
inventing scores, and adapt practice to weak points.

## Configuration

Configure these values through the normal build environment:

```powershell
flutter run `
  --dart-define=SB_AI_TUTOR_BASE_URL=https://<worker> `
  --dart-define=SB_SUPABASE_URL=https://<project>.supabase.co `
  --dart-define=SB_SUPABASE_ANON_KEY=<publishable-key>
```

The Supabase publishable key is not a service-role secret. The short-lived
Supabase access token comes from the signed-in session and is never compiled
into the app. The Worker needs its own `SUPABASE_URL` and
`SUPABASE_ANON_KEY` configuration, Workers AI binding, and production Durable
Object rate limiter. Configure exact `AI_ALLOWED_ORIGINS` values for web
builds; native apps do not send an Origin header.

Before deploying the Worker, apply
`supabase/migrations/20261117000100_tutor_account_role.sql` to the Supabase
project. It sets a server-managed account role on new users and backfills
existing accounts from the role selected at signup. The Worker fails closed
for accounts without a trusted student role.

`SB_AI_TUTOR_TOKEN` is obsolete and must not be used. Rotate any credentials
that were previously exposed before deploying. Do not place service-role keys,
Cloudflare API tokens, or provider secrets in Flutter build arguments.

Video lookup stays disabled until both `YOUTUBE_API_KEY` and
`YOUTUBE_ALLOWED_CHANNEL_IDS` are configured on the Worker. Only curated
channel IDs should be allowed.
