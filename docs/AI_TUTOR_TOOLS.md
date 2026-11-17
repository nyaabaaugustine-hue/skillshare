# AI tutor and learner context

The tutor works offline for everyone. Only a trusted student account can use
the Cloudflare AI routes; guests and guardian accounts stay on the offline
tutor. The Worker now verifies a signed Neon JWT against the configured JWKS,
issuer, and audience, requires the active organization claim `o.role = owner`,
and rate-limits requests by verified subject. This claim mapping is provisional
until confirmed with a real JWT issued by the production Neon Auth branch.

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
token is sent only in the HTTPS authorization header so the Worker can verify
the session locally against Neon Auth signing keys.

Remote tutor implementations should explain in small steps, show short worked
Python examples, ask a useful follow-up question, encourage effort without
inventing scores, and adapt practice to weak points.

## Configuration

**Not yet runnable:** Flutter still uses Supabase Auth; the Neon build define,
Flutter session adapter, and fresh Neon JWT retrieval are not implemented yet.
When completed, configure the Worker with `NEON_AUTH_JWKS_URL`,
`NEON_AUTH_ISSUER`, and `NEON_AUTH_AUDIENCE`, plus its Workers AI binding and
production Durable Object rate limiter. Configure exact `AI_ALLOWED_ORIGINS`
values for web builds; native apps do not send an Origin header.

Before deploying, verify Neon Auth's real signed-token format, JWKS URL,
issuer/audience, and active organization claim format against a real account.
The Worker fails closed for missing, expired, incorrectly signed, or
non-owner-role tokens. Synthetic tests do not prove Neon branch compatibility.

`SB_AI_TUTOR_TOKEN` is obsolete and must not be used. Rotate any credentials
that were previously exposed before deploying. Do not place service-role keys,
Cloudflare API tokens, or provider secrets in Flutter build arguments.

Video lookup stays disabled until both `YOUTUBE_API_KEY` and
`YOUTUBE_ALLOWED_CHANNEL_IDS` are configured on the Worker. Only curated
channel IDs should be allowed.
