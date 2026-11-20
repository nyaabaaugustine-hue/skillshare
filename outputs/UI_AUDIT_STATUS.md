# UI/UX audit — implementation status

Updated 14 November 2026, after the first implementation pass.

## Important correction to the audit

The website loads **`app/theme.css`** after `globals.css`, which flips the whole
site to a **light theme** (`--bg: #f5f8fd`, ink `#0f1b2d`, blue `#1f6fe0`). The
audit was written against `globals.css` alone, so four of its findings are not
real problems on the rendered site:

| Item | Audit claim | Reality |
| --- | --- | --- |
| **W5** | `.curriculum-overview` is a near-white panel on a dark page | Correct hex, wrong context: the page is light. `--muted` on that panel is ~5:1. **No change needed.** |
| **W9** | `themeColor: "#F5F8FD"` clashes with a dark site | It matches the light theme. **No change.** |
| **W10** | Skip link points at a missing `#main-content` | `app/layout.tsx` renders `<div id="main-content">`. **Works already.** |
| **W67** | Phone bezel on mobile | `theme.css` already removes the bezel and its shadow at ≤520 px. **Already done.** |

Two app findings were also already resolved before this pass: the demo login
chips (**A2**) are no longer rendered on the login screen at all, and sign-out
already asks for confirmation (**A76**).

## Implemented in this pass

### Website

- **W2** — `.btn-primary` gradient darkened to `#2a6fd6 → #1553a8`; white label now 4.8:1 at the top step (was 3.5:1).
- **W3** — `.btn { min-height: 44px }`, `.btn-sm` raised from 42 px to 44 px.
- **W4** (partial) — meta type floor raised: `.eyebrow` 11.5→12, `.lesson-kind` 9.5→11.5, `.lesson-step` 10→12, `.lesson-duration` 10→12, `.curriculum-label` 10→12, `.kicker` 10.5→12, `.journey-number` 11→12, `.metrics-band span` 11.5→12.5.
- **W21** — every lesson card is now a real link (`<a class="lesson-card-link" href="/learn">`) with a focus ring and hover arrow. Previously the card said "Open lesson" and did nothing.
- **W22** — lesson duration slot now carries real estimates ("4 min video", "10 min practice") instead of "Beginner friendly" four times.
- **W36** — metrics band is 2×2 on mobile instead of a four-row stack.
- **W44** — three-step install guidance replaces the single "you may need to allow installs" sentence.
- **W48** — closing CTA now offers "Already learning? Log in" alongside starting.
- **W50** — `FAQPage` JSON-LD generated from the same `faqs` array.
- **W53** (partial) — mobile sheet now has `aria-modal="true"`, closes on Escape and moves focus to its first link. A full focus trap and focus restore are still open.
- **W54** — menu button label switches between "Open menu" and "Close menu".
- **W60** (partial) — footer now states the web and APK versions and links Terms (previously unreachable). Still no support email.
- **W63 / W64** — `/learn` shows a spinner + "first visit downloads the Python runtime" state, and after 20 s offers "open the app in its own tab"; the overlay clears on `iframe` `onLoad`.
- **W66** — the download notice now precedes the module list rather than trailing it.
- **W79** — `/learn` has its own title and description via `app/learn/layout.tsx`.

### App

- **A39** — filled buttons now use `primaryDeep` (#0B67E0, 5.2:1 with white) instead of #2B95FF (3.1:1).
- **A39 (premium CTA)** — `PremiumButton` gradient is `#2270D6 → #0A57B8`, so the white label clears AA (the old top step was 3.4:1).
- **A36** (partial) — theme `labelMedium` 12→12.5 and `labelSmall` 11→12.
- **A5 / A6** — the login form autofocuses its first field on each mode, and every field forwards "Next" to the following field (`FocusScope.nextFocus()`), including before the guardian email.

## Still open (the significant ones)

Grouped, highest impact first. None of these were started in this pass.

1. **Auth completeness (app):** password reset (A9), email verification (A10), Terms consent at signup (A16), inline field errors (A18), guardian credential recovery (A14).
2. **Editor and lesson:** indentation/undo affordances (A58), Pyodide start feedback (A59), timeout explanation (A60), expected-vs-actual diff (A62), lesson subtitles/transcripts (A49), resume playback (A51), next-step footer (A56).
3. **Login hierarchy (A1, A3):** the role picker + mode toggle still put two decisions before the form; the role selector is redundant now that accounts carry a role.
4. **App accessibility:** large-text pass (A83), `MergeSemantics` on cards (A85), semantics on path nodes (A43/A44), image decode sizing (A86).
5. **Site IA:** the three repeated card sections (W33) and four parent-report mentions (W34) still stand; `/curriculum` detail page (W27) does not exist.
6. **Forms (web):** inline validation with `aria-invalid` (W72), per-field error association (W73), confirm password (W74), `?next=` preserved across mode switches (W77).
7. **Trust content (W40):** no team, contact address or organisation detail anywhere.
8. **Audit-doc items A1–A90 / W1–W80 not listed above** remain as written, except the four stale web findings corrected at the top of this file.

## Verification

- `next build` — compiles clean, route table unchanged apart from `/learn` gaining a layout.
- `flutter build web --release` — compiles clean with the theme, button and login changes.
- No screenshot or click-through pass was performed for either surface.
