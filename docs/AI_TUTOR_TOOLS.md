# AI tutor tools and learner context

The tutor supports an offline-first flow and an optional online tool gateway.
Offline mode never sends learner data or screenshots anywhere. When
`SB_AI_TUTOR_BASE_URL` is configured, the app enables two explicit server
endpoints:

- `POST /v1/tutor/tools/web-lookup` with `{ "query": "..." }`
- `POST /v1/tutor/tools/screenshot` with `{ "attachment": { "name", "mimeType", "base64" }, "studentContext": { ... } }`

Both endpoints should return `{ "text": "...", "sources": ["https://..."] }`.
The web tool must return citations and should use an allowlisted search provider.
The screenshot tool should inspect code screenshots, tracebacks, diagrams, or
lesson work and return a student-friendly explanation rather than a grade.

## Context sent to the tutor

Only the active learner's tutoring context is allowed:

- display name
- server-authoritative total points
- completed and total challenges
- weak course steps and latest scores

The app does **not** send auth tokens, email addresses, guardian records, raw
submission history, or unrelated learners to the tutor tools. The student name
and progress are loaded from the authenticated learner session and LMS progress;
weak points are derived from the learner's own course attempts.

## Teaching behavior

Remote tutor implementations should use the `TutorTeachingStyle` contract:

- explain in small steps
- show short worked Python examples
- ask a Socratic follow-up question
- encourage effort without inventing or changing points
- adapt the next exercise to weak points

A safe production backend should additionally enforce authentication, rate
limits, content moderation, prompt-injection resistance for web pages, source
citations, retention limits, and guardian-consent rules for under-13 learners.

## Example build configuration

```powershell
flutter run `
  --dart-define=SB_AI_TUTOR_BASE_URL=https://api.example.com `
  --dart-define=SB_AI_TUTOR_TOKEN=<short-lived-token>
```

Do not commit real tokens. Prefer a short-lived authenticated session token
issued by the LMS rather than a permanent API key embedded in the app.
