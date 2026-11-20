# Learning-value roadmap

Status of the 19 improvements proposed on 16 November 2026. "Shipped" means it
is in the app and covered by a check; everything else states exactly what
blocks it, so nothing looks finished that is not.

## Shipped in this pass

### 1. Randomised practice values + anti-cheat grading

`course_models.dart` gained `CodeBlock.forbiddenLiterals`; `practice_checks.dart`
fails a step when the expected answer appears anywhere in the learner's source
(comments already stripped). `python_course_content.dart` now builds the course
through `_buildCourse()` with `_PracticeValues.pick()`: the "Storing Data"
practice draws `price` 11–19 and `quantity` 3–7 on every launch, so the total the
learner must print changes and cannot be copied from the brief, a previous
session, or the worked example.

Scope note: this is applied to the one practice with a computed answer. The other
three practices (print, setup, types) have no numeric answer to randomise; their
hidden-check upgrade needs the generated-case work in item 8 below.

### 2. Expected-vs-actual feedback

`PracticeVerdict.diff` (built by `practiceDiff`) shows "Missing from your output
/ You printed" (or "Expected / You printed" when a step has `expectedOutput`) in
the checklist panel under the console, capped at six lines each side.

### 3. Daily review queue

`features/home/review_plan.dart` + `_ReviewCard` on the course path: up to three
items, weakest finished steps first ("Last try: 55%"), then the next unfinished
step ("Next up"). Uses only scores the learner actually earned; hidden for brand
new accounts.

## Staged, in the order I would build them

| # | Item | Needs | Rough size |
|---|---|---|---|
| 4 | Real AI tutor with learner code + failing check attached | An LLM key held server-side; `TutorService.ask()` already accepts context, so the app side is a new provider implementing the same call with the local brain as fallback | 4–6 days |
| 5 | Weekly guardian digest email | `RESEND_API_KEY` set on the mailer Worker + a scheduled trigger; report data already exists | 2 days |
| 6 | Portfolio project + verifiable certificate | New project content, a certificate ID, and a `/verify/<id>` route on the website | 5–8 days |
| 7 | "Fix the bug" exercises | New block type (broken code + failing check) and 2 lessons of content | 2–3 days |
| 8 | Generated practice cases (multiple hidden runs) | Runtime call per case at finish time; extends item 1 to every practice | 3–5 days |
| 9 | Skip-ahead on a first-try 100 | Small change in `CourseController` unlock rules | 0.5 day |
| 10 | Mastery streak + weekly goal | `CourseProgressRepository.recordActivity` exists; needs a goal model and a Home chip | 1–2 days |
| 11 | Progressive hint cost | Hint reveal already exists in `_InstructionsPanel`; needs scoring plus a "hint used" record | 1 day |
| 12 | Offline lesson video download | Cache Cloudinary streams to app storage and play from file | 3–4 days |
| 13 | Lesson transcripts + recap cards | 12 transcripts of content writing | 2–3 days content |
| 14 | Keyboard shortcuts (Cmd/Ctrl+Enter run, Tab indent block) | Only `CallbackShortcuts` in the tutor today; editor needs a shortcut host | 0.5 day |
| 15 | Assessment mode (timed, no hints) | Mode flag through the lesson runner + result release | 3–4 days |
| 16 | Teacher / class dashboard | `GuardianReport` generalised; needs accounts, a class model and the leaderboard DB (still blocked on the missing table) | 1–2 weeks |
| 17 | Cohort leaderboards + study-buddy pairs | Requires server-verified identity (the app still posts a device `learnerRef`) and the same DB table | 1 week |
| 18 | Exercise depth: 5 per lesson (60 total) | Content writing against the existing `CodeBlock` model | 2–3 weeks content |
| 19 | Localisation (Twi/Ga) for the first three lessons | Translation + audio recording | 1 week + recording |

## Verification for this pass

- `flutter test test/review_plan_test.dart test/practice_checks_test.dart test/guardian_report_test.dart` — 18 tests across the three files. The first run had one failure (a brand-new account still got a "Next up" card); the fix keeps the card hidden until a step is finished, and the review + practice files were re-run green (11/11). The guardian file was untouched by that fix and passed in the first run.
- `flutter build web --release` — EXIT 0, which compiles the diffs in `editor_screen.dart` and `course_path_screen.dart`.
- Not verified: no click-through of the review card or the diff panel in a running app, so their visual result is unchecked.

## Honest state of the dependencies

- **Leaderboard DB table** is still not installed (`42501`): the site role cannot
  create tables. `/leaderboard` now shows a copyable `CREATE TABLE` panel and
  `npm run db:install` exists for an owner connection string.
- **AI tutor** has no key in the project. Until one is provided, the offline
  brain remains the only tutor; nothing in this pass pretends otherwise.
- **Guardian email** is implemented but cannot send: the Worker has no Resend
  key and is not deployed.
- **Instrumentation** (first-try pass rate, day-7 return) is not built. Without
  it, the effect of items 1–3 is not measurable beyond the tests.
