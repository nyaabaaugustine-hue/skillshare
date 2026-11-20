# AI tutor and learner context

The tutor works offline for everyone. Signed-in learners may also use the
Cloudflare AI routes. The Worker verifies a signed Neon JWT against the
configured JWKS and issuer, enforces a student-only policy, and rate-limits
requests by verified subject.

## Worker routes

- `POST /v1/tutor/chat` returns a short explanation and, only when the question
  matches a topic, official Python documentation sources.
- `POST /v1/tutor/chat/stream` streams the answer as server-sent events.
- `POST /v1/tutor/vision` analyzes a learner-selected screenshot after an
  in-app preview and send confirmation. The learner's own question is sent with
  it.
- `POST /v1/tutor/resources` returns short videos only when the learner asks
  after receiving an explanation. Results are restricted to configured,
  trusted YouTube channels and videos with captions.

The Worker does not persist chat history. The app sends recent turns for
conversation context, along with the active learner's minimum tutoring
context. The Worker rebuilds the conversation server-side, accepting only a
strict user/assistant alternation, so a client cannot inject a fake assistant
turn. Screenshots are sent only after the learner confirms the preview.

## Safety

- Input is checked against a small high-signal pattern set before the model is
  called, and the same check runs on the answer; contact details are redacted
  from replies. This is a floor, not a moderation system.
- The system prompt limits the tutor to Python and computing topics and tells
  the model to treat learner text as data.
- A guardian session (`o.role === "member"`) is rejected with 403. The app
  hides the online tutor from guardians, but the Worker enforces it.
- Rate-limit budget is only spent after the payload validates, so malformed
  requests cannot lock a learner out.

## Context sent to the tutor

Only the active learner's tutoring context is allowed:

- display name
- server-authoritative total points (omitted when the app is running against
  the mock LMS, whose points reset every launch)
- completed and total challenges
- weak course steps and latest scores

The app does **not** send auth tokens as prompt content, email addresses,
guardian records, raw submission history, or unrelated learners. A device's
progress is only shared when the local learner id is still scoped to the
signed-in account, so a shared phone or browser cannot leak context between
learners. The access token is sent only in the HTTPS authorization header so
the Worker can verify the session against Neon Auth signing keys.

Remote tutor implementations should explain in small steps, show short worked
Python examples, ask a useful follow-up question, encourage effort without
inventing scores, and adapt practice to weak points.

## Configuration

Configure the Worker with `NEON_AUTH_BASE_URL` (the same value the website
uses) or the explicit `NEON_AUTH_JWKS_URL` / `NEON_AUTH_ISSUER` pair.
`NEON_AUTH_AUDIENCE` is optional: when it is unset, no `aud` claim is required,
because Better Auth does not always emit one.

Also configure the Workers AI binding, the `TUTOR_RATE_LIMITER` Durable Object
(required in production), and `AI_ALLOWED_ORIGINS` for web builds (native apps
do not send an Origin header). `CF_AI_FALLBACK_MODEL` is an optional second
model tried once if the primary fails, so a retired model degrades instead of
taking the tutor offline.

`SB_AI_TUTOR_TOKEN` is obsolete and must not be used. Do not place service-role
keys, Cloudflare API tokens, or provider secrets in Flutter build arguments.

Video lookup stays disabled until both `YOUTUBE_API_KEY` and
`YOUTUBE_ALLOWED_CHANNEL_IDS` are configured on the Worker. Only curated
channel IDs should be allowed.

## Client fallbacks

The app prefers the online tutor only when `SB_API_BASE_URL` (or
`SB_AI_TUTOR_BASE_URL`) is set and the learner has a token. On 401 it refreshes
the JWT, then retries once. If the call still fails it answers offline, labels
the reply as an offline fallback and shows the reason (expired session,
rate limit, outage or no connection). Guests and guardians stay on the offline
tutor.
