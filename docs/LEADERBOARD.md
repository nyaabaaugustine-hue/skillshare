# Shared leaderboard (app + web)

One ranking, two clients. The Android app and the website read and write the same
`/api/leaderboard` endpoint, so a learner on a phone and a learner in a browser
appear in the same list, ordered by score.

## How ranking works

- **Score** = the sum of the per-step scores (each step is 0–100), so finishing
  more steps **and** scoring higher both move a learner up.
- **Ties** are broken by steps completed, then by whoever updated first.
- The board shows, per learner: rank, profile photo (or initials), name,
  source (`Android app` / `Browser`), steps completed, hands-on **practice**
  completed, average score and total points.
- The server clamps input: at most **12** steps, **4** practices and
  `steps × 100` points, so a modified client cannot post an impossible score.

## Where the data lives

| Piece | Path |
| --- | --- |
| Table + queries | `website/lib/server/leaderboard.ts` (Neon Postgres, `leaderboard_entries`) |
| Read / write API | `website/app/api/leaderboard/route.ts` |
| Profile photo bytes | `website/app/api/leaderboard/avatar/[id]/route.ts` |
| Website page | `website/app/leaderboard/page.tsx` |
| App client / models | `sepnet_lms/lib/features/leaderboard/leaderboard_client.dart`, `leaderboard_models.dart` |
| App screen | `sepnet_lms/lib/features/leaderboard/leaderboard_screen.dart` |
| App auto-publish | `sepnet_lms/lib/features/leaderboard/leaderboard_sync.dart` |

The website's Neon role cannot create tables in `public` (the schema is owned by
`pg_database_owner`), so the table is installed once from
`website/db/001_leaderboard.sql`. Run that file in the Neon SQL editor, or as the
owner:

```bash
psql "$DATABASE_URL" -f website/db/001_leaderboard.sql
```

It creates the table, its ranking index, and grants `SELECT, INSERT, UPDATE` to
the website role. Until it has run, the API answers `503` with that instruction
and both clients show it — nothing fails silently.

## Identity

- **Browser:** a signed-in Neon Auth user becomes `web:<user id>`, and the name
  comes from the account. The session is verified server-side.
- **App:** the device learner reference becomes `app:<learner ref>`. It is stable
  per install and per learner (`settings.learnerRef`), which is what lets the app
  publish without a browser session.

Because the app has no server-verified identity yet, its writes are bounded by the
clamping above rather than by an account. When the app starts signing in against a
shared backend, switch the app branch to that identity and drop `ref` from the
request.

## Enabling it in the app

The app publishes to the same API as the website leaderboard at
`https://academy-skillshare.vercel.app/leaderboard`. Configure the app with the
site origin (not the `/leaderboard` page path):

```bash
flutter build appbundle --release \
  --dart-define=SB_LEADERBOARD_URL=https://academy-skillshare.vercel.app
```

`SB_LEADERBOARD_URL` falls back to `SB_LMS_BASE_URL`, so one server address can
serve both. With neither set, the trophy button still opens the screen but it
explains that the leaderboard is not connected instead of showing an empty list.
The Android APK helper uses this production origin by default; override it with
the `SB_LEADERBOARD_URL` environment variable for local or staging builds.

Local development:

```bash
cd website && npm run dev          # serves /api/leaderboard on :3001
cd sepnet_lms && flutter run -d chrome \
  --dart-define=SB_LEADERBOARD_URL=http://localhost:3001
```

## Profile photos

- The app picks a photo with **image_picker** (gallery), downscaled to 256 px and
  re-encoded at quality 70. Anything over 60 KB is rejected with a message.
- The photo is sent as a data URL, validated and stored with the row; the avatar
  route serves it back as `image/jpeg|png|webp` with a 5-minute cache.
- Learners without a photo get initials, so the board never shows a broken image.
- Photos on this board are **public** — the page says so, next to the upload
  action.

## Publishing

- The app pushes after every completed step (background, best effort) and again
  when the leaderboard screen opens, so an offline session appears on the board
  the next time it can reach the server.
- The website page is `force-dynamic`; it always reads the current table.

## When the site cannot create the table

The website connects as `skillsbridge_website`, which owns nothing in `public`,
so neither the API nor the site can create the table (Postgres error `42501`).
The page now shows a **Copy SQL** panel for exactly this case, and there are two
ways to install it:

1. Paste the panel's SQL into the Neon SQL editor and run it as the project
   owner (fastest, no local tooling).
2. Add the owner connection string to `website/.env.local` and run the installer:

   ```
   NEON_OWNER_DATABASE_URL=postgresql://<owner>:<password>@<host>/neondb?sslmode=require
   cd website && npm run db:install
   ```

`npm run db:install` splits `db/001_leaderboard.sql` into single statements,
reports each one, and prints the exact remedy if the role is wrong. Reload
`/leaderboard` afterwards; the API returns `ready: true` from then on.

Prefer to hand the app role the ability to install it itself?

```sql
GRANT CREATE ON SCHEMA public TO skillsbridge_website;
```

That has to be run once by the owner as well.
