# SkillsBridge Academy — UI/UX audit and 170 improvements

**Scope:** the Flutter app (`sepnet_lms/`, 17 screens, `lib/app/theme.dart`) and the
website (`website/`, 9 routes, `app/globals.css`, 8 components).
**Method:** static UI audit of the real source — design tokens, type scale, colour
pairs, spacing, component inventory, ARIA/semantics usage, state handling.
**Date:** 14 November 2026.

> **Status:** a first implementation pass is recorded in
> [`UI_AUDIT_STATUS.md`](./UI_AUDIT_STATUS.md). It also corrects four findings
> (W5, W9, W10, W67) that no longer apply because the site now renders with the
> light `theme.css` overrides.

**What this is not:** I did not run the app on a device or click through the site, so
every item below is a code-level finding, not a runtime observation. Contrast figures
are computed from the hex values in the source and should be re-checked on device with
a colour picker. No items here claim measured performance numbers.

**Legend** — Severity: **P0** blocks trust/access, **P1** hurts the core task,
**P2** polish. Effort: **S** ≤ half a day, **M** 1–3 days, **L** > 3 days.

---

## Executive summary

The product has a strong, coherent visual identity (deep ink navy, electric blue,
gold accents, editorial headings) and unusually honest copy. The problems are not
taste problems — they are **density, consistency and parity** problems:

1. **Two design systems, drifting.** App tokens (`SkillBridgeColors`) and web tokens
   (`--bg`, `--blue`, `--gold`) already disagree: app primary `#2B95FF` vs web `#3B94FF`;
   app accent `#FFC857` vs web `#F5B02B`; app dark base `#080D15` vs web `#050B15`.
2. **Small text is doing work it cannot do.** The app has 41 uses of 12 px and 28 of
   11 px; the site ships 9.5 px, 10 px and 10.5 px labels. On a 360 dp phone in a
   classroom, and on a 1366×768 laptop, this is the single biggest legibility risk.
3. **Login carries six competing entry points** (role picker, mode toggle, demo
   chips, form, Facebook, guest) — the highest-stakes screen is the busiest.
4. **Learn and accounts now exist in both places but do not look related.** The web
   `/learn` page frames the app in a phone mock; the site's own auth pages use a
   different component language (`.auth-card` vs `.learn-stage`).
5. **Accessibility is decorative rather than structural.** 15 `Semantics` nodes across
   17 app screens, 11 ripple-less `GestureDetector`s, no skip link on the site, a
   mobile nav sheet with `role="dialog"` but no focus trap.

---

## Do these twelve first

| # | Item | Why now |
| --- | --- | --- |
| 1 | A39 + W2 · Fix white-on-blue button contrast (≈3.1:1 app, ≈2.7:1 web) | WCAG AA failure on the primary action of both surfaces |
| 2 | W24 · Fix `.curriculum-overview` near-white gradient on the dark page | Panel is unreadable in dark mode |
| 3 | A36 · Raise the app's 11–12 px labels to a 12.5 px floor | 69 declarations below legible body size |
| 4 | A1 + A2 · Strip demo logins and reduce login to one primary path | Real users see "demo logins — no signup needed" |
| 5 | A83 · Verify 200% text scaling on the 56 px buttons and 76 px nav | Fixed heights clip at large system font |
| 6 | W53 · Mobile nav sheet: focus trap, Escape, `aria-modal` | Keyboard and screen-reader users get stuck |
| 7 | A43/A44 · Give every tappable card semantics + ripple | 11 silent tap targets |
| 8 | W21 · Lesson cards are not links ("Open lesson" is a `<span>`) | Looks interactive, does nothing |
| 9 | A9/A16 · Password reset + Terms consent in the app | Legal and parity gap against the web |
| 10 | A21 · Decide session persistence once (app clears, web restores) | Accounts are now shared; behaviour must match |
| 11 | W63 · `/learn` needs a loading state and an "open in new tab" fallback | 45 MB boot inside an iframe on a weak connection |
| 12 | A28 · Empty state for a brand-new learner | First screen after signup is a blank path |

---

# Part 1 — Flutter app (A1–A90)

## Authentication (A1–A22)

- **A1 · Login · P1 · M** — Six competing entry points on one screen (role cards, mode
  toggle, demo chips, form, Facebook, guest) fragment attention. → One primary form,
  one secondary "guest" link, role chosen during signup only.
- **A2 · Login · P0 · S** — "Built-in demo logins — no signup needed" is shown to every
  user, including on the shared web build. → Gate demo chips behind
  `AppConfig.environment != 'production'`.
- **A3 · Login · P1 · S** — Role is selected *before* the form and later overwritten by
  the role in account metadata, so the choice can silently disagree with the session. →
  Remove the pre-form role picker; show "Student / Parent" only on signup.
- **A4 · Login · P1 · S** — `_submit()` re-runs `form.validate()` after a failed
  request while `auth.error` also renders a banner, double-reporting one failure. → One
  channel: field errors for fields, banner only for server/network errors.
- **A5 · Login · P1 · S** — No autofocus on the first field, so every visit starts with
  an extra tap. → `autofocus: true` on identifier/name, `FocusScope` on return.
- **A6 · Login · P1 · S** — `textInputAction: TextInputAction.next` is set but no
  `onFieldSubmitted` or `FocusNode` chain exists, so Next does nothing. → Wire
  `FocusNode.nextFocus()` per field; submit on the last.
- **A7 · Signup · P1 · S** — Password rules appear only after a failed submit. → Live
  helper row with a checkmark, matching the web `.password-hints`.
- **A8 · Login · P2 · S** — No caps-lock hint on the password field. → Detect caps via
  `HardwareKeyboard` and show an inline hint.
- **A9 · Login · P0 · M** — The app has no "Forgot password" path while the site has
  `/forgot-password`. → Cloud reset flow (`resetPasswordForEmail`) reachable from login.
- **A10 · Signup · P1 · M** — No email-verification step in the app, so a typo'd address
  is unrecoverable. → Mirror the web 6-digit verification state.
- **A11 · Login · P1 · S** — When cloud auth is off the Facebook button simply does not
  exist; testers think it is broken. → Show a disabled row with "Not configured in this
  build" during development only.
- **A12 · Login · P1 · S** — Returning from Facebook shows the login screen again with
  no "finishing sign-in…" state until the session arrives. → Keep `busy` true with a
  "Finishing sign-in" label while awaiting the session event.
- **A13 · Login · P2 · S** — Footer copy says "Create an account to connect it to the
  LMS", which predates shared accounts. → Reword to "Use the same account on your phone
  and in the browser."
- **A14 · Signup · P1 · M** — The generated guardian password is shown once in a bottom
  sheet and is unrecoverable afterwards (only a reset exists). → Add "View again for 24h"
  or an explicit "I've saved it" confirmation with a copy action.
- **A15 · Signup · P2 · S** — No share action for guardian credentials. → `share_plus`
  sheet with WhatsApp/SMS/copy, plus "never share by email".
- **A16 · Signup · P0 · S** — The app collects a guardian email and creates accounts with
  no Terms/Privacy acceptance, while the web requires it. → Add a required checkbox
  linking to `/terms` and `/privacy`.
- **A17 · Login · P1 · S** — No privacy link anywhere in the auth screen. → Footer link
  to the web policy with an in-app webview.
- **A18 · Login · P1 · S** — All errors render in a banner at the bottom of the form,
  visually detached from the failing field. → Inline `errorText` via the form field.
- **A19 · Signup · P1 · S** — An existing email yields a raw server message; the web
  already says "Sign in instead". → Reuse the `_messageFor` mapping and add a switch-mode
  action button.
- **A20 · Auth · P2 · S** — Busy state shows a spinner *below* the button, pushing the
  layout down. → `PremiumButton(loading: true)` with a fixed-size inline spinner.
- **A21 · Auth · P1 · M** — The app clears the session on every launch while the web
  restores it, so shared accounts behave differently per surface. → Adopt "stay signed
  in" in cloud mode, keep sign-out-every-launch for the offline mock.
- **A22 · Auth · P2 · S** — No password visibility state memory; the eye toggles reset on
  mode switch. → Persist per-session in the state, not in the widget.

## Splash and onboarding (A23–A27)

- **A23 · Splash · P2 · S** — The splash holds the UI while dependencies load and cannot
  be skipped. → Tap-anywhere to continue once ready; cap the hold at 1.2 s.
- **A24 · Splash · P2 · S** — No "working offline" state when the LMS/cloud is
  unreachable; it looks like a hang. → Status line under the logo.
- **A25 · Welcome video · P1 · S** — The dialog is re-shown 380 ms after *every*
  sign-in, including the third time that day. → First-run-only flag in preferences.
- **A26 · Welcome video · P2 · S** — Once dismissed there is no way to watch it again. →
  "Replay intro" in Settings.
- **A27 · Welcome video · P2 · M** — Language choice (English/Twi) is not remembered or
  surfaced elsewhere in the UI. → Persist, and show the current language in Settings.

## Home and shell (A28–A40)

- **A28 · Home · P1 · M** — A brand-new learner lands on a path with no empty state, no
  "start here" emphasis and no explanation of XP/streak. → First-run card with one CTA.
- **A29 · Home · P1 · M** — No resume-where-you-left-off block above the fold. → "Continue
  Step 05 · Loops" card driven by the last completed step.
- **A30 · Home · P1 · S** — XP, streak and coins are displayed with no rule text, so the
  numbers are decorative. → One-line explainer per metric, or a "How XP works" sheet.
- **A31 · Home · P1 · M** — `NavigationBarThemeData(height: 76)` with 11.5 px labels
  clips at large text sizes. → Drop the fixed height, let the bar size itself.
- **A32 · Home · P2 · S** — No badge for a new guardian report or a newly unlocked unit.
  → Dot badge on the relevant destination.
- **A33 · Home · P2 · S** — Greeting falls back to the raw email when no name exists
  ("ama@example.com"), which reads as debug output. → Use the local part, capitalised.
- **A34 · Home · P2 · M** — Card radii are 24, 20, 18 and 16 in the same scroll view. →
  Three tokens: 24 (surface), 16 (control), 999 (pill).
- **A35 · Cards · P2 · S** — Border **and** gradient **and** `cardShadow` are applied at
  once, flattening the hierarchy. → Border-only for static cards, shadow only on floating
  elements.
- **A36 · Type · P1 · M** — 41 declarations at 12 px, 28 at 11 px, 9 at 10.5 px. →
  Floor body/secondary text at 12.5 px and rely on colour, not size, for hierarchy.
- **A37 · Type · P2 · M** — 23 inline `fontSize:` overrides bypass the theme, so a global
  scale change never reaches them. → Replace with `Theme.of(context).textTheme.*`.
- **A38 · Type · P2 · S** — `headlineLarge` and `headlineMedium` are both 32 px/800 —
  a duplicate token nobody can distinguish. → Give them 32 and 26 with different weights.
- **A39 · Colour · P0 · S** — White on `#2B95FF` primary measures ≈3.1:1, below AA for
  16 px bold button text. → Ink-on-blue (`#03172E`, ≈6.9:1) or darken to `#0B67E0`.
- **A40 · Colour · P2 · M** — Nine `Color(0xFFC9A227)` and seven `Color(0xFFB8BAC6)`
  literals live in feature files, bypassing `SkillBridgeColors`. → Move to tokens or
  delete the duplicates.

## Course path (A41–A48)

- **A41 · Path · P1 · M** — The 12-step path has no per-step status text ("locked",
  "practice", "video") beyond iconography and colour. → Add a text label or badge per node.
- **A42 · Path · P0 · S** — Status is conveyed by colour alone (completed/locked/current)
  — unreadable to colour-blind learners and in bright sunlight. → Add shape/icon + label.
- **A43 · Path · P1 · S** — Tap targets are `GestureDetector`s (11 in the app) with no
  ripple or `Semantics(button: true)`. → `InkWell` + semantics label "Step 4, practice,
  locked".
- **A44 · Path · P1 · M** — Icons carry the meaning; only 15 `Semantics` nodes exist in
  the whole app. → Wrap each node in `Semantics` with label, hint and `button: true`.
- **A45 · Path · P2 · S** — Locked steps give no reason ("finish step 3 first"). → Snack
  or sheet explaining the unlock rule.
- **A46 · Path · P2 · S** — No "jump to current step" affordance when returning to a long
  path. → Auto-scroll once on open, plus a floating "Today" chip.
- **A47 · Path · P1 · S** — Progress header and the path disagree in wording ("0/12
  steps" vs "SECTION FOUNDATIONS"). → One vocabulary: step count + unit name in the same
  bar.
- **A48 · Path · P2 · S** — No celebration or state change when the unit completes. →
  Certificate/receipt moment with a shareable card.

## Lesson player and video (A49–A57)

- **A49 · Lesson · P1 · M** — The video step has no captions or transcript, which fails
  learners in noisy shared rooms and with hearing loss. → VTT captions + collapsible
  transcript from the Cloudinary asset.
- **A50 · Lesson · P1 · S** — No buffering/timeout state on `video_player`; a stalled
  video looks frozen. → Explicit loading, retry and "use less data" states.
- **A51 · Lesson · P1 · S** — No playback position memory, so a dropped connection
  restarts the video. → Persist `position` per lesson and resume with confirmation.
- **A52 · Lesson · P2 · S** — No speed control or 10-second skip, both expected on
  2-minute lesson clips. → Add a "1×/1.25×/1.5×" control and skip buttons.
- **A53 · Lesson · P2 · S** — Video controls are the platform default, which clashes with
  the dark custom chrome. → Custom control bar, or explicitly documented default.
- **A54 · Lesson · P1 · S** — No "mark as watched" fallback when the video cannot play
  (offline, data-saver). → Text summary + completion path that does not dead-end.
- **A55 · Lesson · P2 · M** — Long lesson bodies use one undifferentiated text block, no
  headings or anchors. → Structured headings + a progress-in-step indicator.
- **A56 · Lesson · P1 · S** — No explicit next-step button at the end of a block; users
  must go back to the path. → Sticky "Next: Step 06" footer.
- **A57 · Lesson · P2 · S** — Step completion has no local confirmation (only a path
  update behind them). → Inline success toast with the XP earned.

## Editor and execution (A58–A66)

- **A58 · Editor · P1 · L** — No visible indent/undo affordances on mobile; Python
  learners hit `IndentationError` first. → Soft-tab button, indent guide, one-tap undo.
- **A59 · Editor · P1 · M** — Running code gives no elapsed-time feedback; a slow Pyodide
  first run looks broken. → "Starting Python…" then a running timer after 500 ms.
- **A60 · Editor · P1 · S** — Timeout and output-cap events are not explained in the UI;
  the learner sees a truncated panel. → Plain-language banner: "Stopped after 10 s".
- **A61 · Editor · P2 · S** — Errors are rendered as raw Python tracebacks in places,
  contradicting the site's promise of beginner-worded feedback. → Map common exceptions
  to hints above the raw trace.
- **A62 · Editor · P1 · M** — No diff/hint between expected and actual output on a failed
  practice. → Side-by-side expected vs actual with the first differing line highlighted.
- **A63 · Editor · P2 · S** — The Run button has no disabled/again state while executing;
  double-taps queue runs. → Disable + "Running…" label.
- **A64 · Editor · P2 · S** — No keyboard toolbar (colon, quotes, parentheses) — expensive
  on mobile keyboards. → Accessory row above the keyboard.
- **A65 · Editor · P2 · M** — Font size in the editor is fixed; learners on small phones
  cannot enlarge code without OS zoom. → Settings: editor font size 12–20 with preview.
- **A66 · Editor · P2 · S** — The output panel and editor have similar visual weight, so
  it is unclear which is which at a glance. → Distinct header labels and a divider.

## Quiz and assessment (A67–A73)

- **A67 · Quiz · P1 · M** — No per-question progress ("Question 3 of 8") visible in the
  quiz chrome. → Progress row with dots and a count.
- **A68 · Quiz · P1 · S** — No review of which answers were wrong before submitting, and
  no post-submit explanation per question. → Answer review list with the correct option
  and a one-line why.
- **A69 · Quiz · P1 · S** — The 100/60/≥70% thresholds are implemented but never surfaced
  to the learner. → Show the pass mark up front and the result against it.
- **A70 · Quiz · P2 · S** — Leaving mid-quiz gives no warning; answers are lost. →
  Confirm-before-exit with a saved draft.
- **A71 · Quiz · P2 · S** — No time expectation ("about 3 minutes") before starting. →
  Duration estimate on the intro card.
- **A72 · Quiz · P2 · M** — Retakes look identical to first attempts; no sense of
  improvement. → Show "last attempt: 62%" and the delta.
- **A73 · Quiz · P2 · S** — Result screens use the same generic card as everything else,
  so success and failure read the same. → Distinct pass (gold) and retry (calm) states.

## Achievements, settings, guardian (A74–A82)

- **A74 · Achievements · P2 · M** — Badges are shown without earned/locked contrast or a
  date earned. → Locked state at 40% opacity + "Earned 12 Nov".
- **A75 · Achievements · P2 · S** — No empty state explaining how to earn the first badge.
  → "Finish step 1 to unlock your first badge."
- **A76 · Settings · P1 · S** — Sign-out has no confirmation and no explanation of what
  happens to local progress. → Confirm sheet: "Your device progress stays; you'll need to
  sign in again."
- **A77 · Settings · P1 · S** — Account deletion is absent, which blocks Play Store policy
  and user trust. → Delete-account flow with typed confirmation and email follow-up.
- **A78 · Settings · P2 · S** — No app version/build, privacy policy, or support contact
  rows. → "About" group with version, policy link and support email.
- **A79 · Settings · P2 · S** — Theme picker exists in the theme but the app is dark-only;
  check the row is either removed or honest about the limitation.
- **A80 · Guardian home · P1 · M** — The read-only report has no explicit empty state for
  a learner with zero attempts. → "No attempts yet — check back after the first lesson."
- **A81 · Guardian home · P1 · S** — Percentages are shown without a legend for what
  "needs support" means. → Threshold legend (below 70 = needs support).
- **A82 · Guardian · P2 · S** — No share/export of the report as a PDF or email resend. →
  "Email me this report" action tied to the existing mailer.

## Cross-cutting: accessibility, performance, platform (A83–A90)

- **A83 · A11y · P0 · M** — No large-text pass: fixed heights (56 px buttons, 76 px nav,
  46 px badges) will clip at 200% scaling. → Layout that grows; test at 1.0/1.5/2.0.
- **A84 · A11y · P1 · S** — Screen-reader order on the login screen follows the widget
  tree rather than the visual hierarchy (decorative CodeBuddy is announced as an image). →
  `ExcludeSemantics` on decoration, `Semantics` groups around logical blocks.
- **A85 · A11y · P1 · S** — `MergeSemantics` is never used, so cards announce as several
  fragments. → Wrap composite rows in `MergeSemantics`.
- **A86 · Performance · P1 · M** — 17 `Image.asset` calls with no `cacheWidth`; large PNGs
  are decoded at full size on low-end phones. → Size-aware decoding + `filterQuality`.
- **A87 · Performance · P2 · M** — No skeleton placeholders on list screens; every load is
  a spinner that replaces content (layout jump). → Skeletons matching final layout.
- **A88 · Platform · P1 · S** — Android predictive-back is not supported by the current
  `ZoomPageTransitionsBuilder` choice. → M3 predictive back + system back gesture test.
- **A89 · Platform · P2 · S** — No haptic feedback on step completion or failure. →
  `HapticFeedback.lightImpact()` on completion, `mediumImpact()` on pass/fail.
- **A90 · i18n · P2 · M** — English/Twi is offered once, then all copy is hard-coded
  English. → Extract strings now (ARB) even if translations come later.

---

# Part 2 — Website (W1–W80)

## Design tokens and global chrome (W1–W12)

- **W1 · Tokens · P1 · M** — The site's palette has already drifted from the app:
  `--blue #3B94FF` vs app `#2B95FF`, `--gold #F5B02B` vs `#FFC857`, `--bg #050B15` vs
  `#080D15`. → One exported palette shared by both codebases.
- **W2 · Contrast · P0 · S** — `.btn-primary` is white on a `#4aa0ff → #1b6ed8` gradient;
  the top of the gradient measures ≈2.7:1. → Darken the gradient top to `#1b6ed8`/`#1a66cc`
  or use ink text.
- **W3 · Touch · P1 · S** — `.btn-sm` is 42 px tall while only `min-width: 44px` is set, so
  the small buttons miss the 44×44 target. → `min-height: 44px` on all controls.
- **W4 · Type · P1 · M** — Kickers, step labels and lesson meta run at 9.5–11.5 px
  (`.lesson-kind` 9.5, `.lesson-step`/`.lesson-duration` 10, `.kicker` 10.5). → Floor
  meta text at 12 px with weight/colour carrying the hierarchy.
- **W5 · Colour · P0 · S** — `.curriculum-overview` paints
  `linear-gradient(105deg, rgba(31,111,224,.1), rgba(255,255,255,.78))`, a near-white panel
  on a dark page; `var(--muted)` body text on it is ≈1.5:1. → Replace with a blue-tinted
  dark panel.
- **W6 · Type · P2 · M** — The site uses eleven distinct font sizes between 9.5 and 14.5 px.
  → Six-step scale (12, 13.5, 15, 17, 20, clamp headings).
- **W7 · Layout · P2 · M** — Radii drift across 10, 12, 14, 18, 20, 22 and 24 px. → Three
  tokens: 999 (pill), 20 (card), 12 (control).
- **W8 · Layout · P2 · S** — `body { overflow-x: hidden }` masks horizontal overflow instead
  of fixing the offending element. → Remove it and fix the real overflow.
- **W9 · Chrome · P2 · S** — `themeColor: "#F5F8FD"` gives mobile browsers and the Android
  status bar a near-white tint over a `#050b15` site. → `#050B15`.
- **W10 · A11y · P0 · S** — The skip link in `layout.tsx` points at `#main-content`, but no
  page renders that id (home is `<main id="top">`, auth uses `<main class="auth-page">`). →
  Add `id="main-content"` to every `<main>`.
- **W11 · Colour · P2 · S** — `--line: rgba(255,255,255,.09)` makes card edges vanish on
  low-brightness screens. → Raise to `.12` and add a second stronger border token.
- **W12 · Motion · P2 · S** — Transitions mix 0.2/0.25/0.35/0.7 s with one easing curve;
  hover lifts and reveals feel like the same gesture. → Three durations (120/240/400 ms)
  with distinct enter/exit curves.

## Hero (W13–W20)

- **W13 · Performance · P1 · M** — The hero video loads a Cloudinary MP4 with
  `preload="auto"` and no poster, competing with the LCP image on 3G. → `preload="none"`
  + poster image + play only when visible.
- **W14 · Performance · P2 · S** — The muted looping video keeps decoding after the user
  scrolls past the hero. → Pause via IntersectionObserver.
- **W15 · Layout · P1 · S** — Three `<br>`-forced headline lines put the primary CTA below
  the fold at 360×640. → Break on phrase boundaries, not fixed `<br>`s; shorten on mobile.
- **W16 · Layout · P1 · S** — `.float-a` and `.float-c` are absolutely positioned over the
  phone mock and overlap it at ≤760 px. → Reposition inside safe insets or hide both.
- **W17 · Copy · P2 · S** — The `hero-meta` line ("Free in the browser · No install · Same
  lessons…") is the most important reassurance and set at the smallest weight. → Promote it
  to a proof row with icons.
- **W18 · Expectation · P1 · S** — "Start learning on web" opens `/learn`, where the app is
  a phone-sized frame; desktop users expect a full-width editor. → Make `/learn` default to
  full width on large screens and keep the phone frame as an option.
- **W19 · Trust · P2 · S** — The hero promises parent reports and offline learning with no
  link to the privacy policy or the honest "not a sandbox" disclaimer. → Add one inline
  trust link next to the proof row.
- **W20 · Visual · P2 · M** — The only above-the-fold product evidence is a decorative
  window mock; nothing shows real code or a real lesson. → Show a truncated real lesson
  step with output.

## Why it works and curriculum (W21–W32)

- **W21 · Interaction · P0 · S** — Lesson cards are `<article>`s whose "Open lesson" is a
  `<span>`: nothing is clickable or keyboard-reachable. → Wrap each card in an `<a>` to the
  lesson (or `/learn?step=n`).
- **W22 · Content · P1 · S** — The "duration" slot reads "Beginner friendly" for all four
  cards, so it conveys no information. → Real per-step minutes ("4 min video", "8 min
  practice").
- **W23 · Content · P1 · S** — Four of twelve steps are shown with no explanation of what
  the other eight contain beyond chips. → Either show all twelve compactly or add a
  "view full syllabus" disclosure.
- **W24 · Data honesty · P2 · S** — `.progress-track span` is hardcoded to `33.333%` while
  the copy says "4 / 12" and "Preview path". → Drive both from one value, labelled as a
  preview.
- **W25 · Semantics · P2 · S** — "Preview path 4 / 12" reads as the visitor's own progress.
  → "Sample path · 4 of 12 steps shown".
- **W26 · Consistency · P2 · S** — "Step 01" sits on a card whose eyebrow says "Video"/
  "Code", while the section calls them lessons. → Pick "step" and use it everywhere.
- **W27 · Interaction · P2 · M** — There is no curriculum detail page; cards cannot open a
  syllabus, so parents cannot inspect what is taught. → `/curriculum` with the 12 steps,
  objectives and pass marks.
- **W28 · Performance · P2 · S** — Cloudinary thumbnails are plain `<img>` with no
  `width`/`height`, relying on aspect-ratio for stability. → Add intrinsic dimensions and
  `sizes`.
- **W29 · A11y · P1 · S** — Lesson thumbnails use `alt=""`, so a screen reader hears a card
  with no image context, and the "Video"/"Code" tag is not associated. → `alt="Video
  thumbnail for Python quick start"` or mark the card's kind in text.
- **W30 · Content · P2 · S** — "One unit. Twelve steps. Real foundations." does not say
  what a learner can *do* afterwards. → Add one outcome line ("write a small program that
  takes input and reports results").
- **W31 · Layout · P2 · S** — `.lesson-rail` is a 2-column grid even for four cards, so on
  tablets the cards become very tall with 16/7.8 media. → 3-column at ≥1100 px.
- **W32 · Interaction · P2 · S** — No filter for video vs practice steps despite the site
  making the distinction. → Chip filter with counts.

## Family, journey, about (W33–W42)

- **W33 · IA · P1 · M** — Three consecutive sections (family, journey, about) all use a
  3-card grid with "01/02/03"-style kickers, so the page reads as the same section three
  times. → Vary the layout: process diagram, then editorial two-column.
- **W34 · Copy · P1 · M** — Parent reports are explained in four places (feature card,
  family card 02, journey card 03, parents section). → One canonical parents section; link
  to it from the feature card.
- **W35 · Type · P2 · S** — Family and about headlines are two full sentences in an `h2`,
  against a 760 px measure. → Lead with the short sentence, move the rest to `.lede`.
- **W36 · Layout · P2 · M** — `.metrics-band` is a 4-up grid that collapses to a single
  column on mobile, adding four full-width rows of scroll. → 2×2 on mobile, or a single
  inline stat strip.
- **W37 · Content · P2 · S** — The journey section never says how long the whole unit takes
  or what a parent receives at the end. → Add "≈2 weeks at 20 min/day" and the report
  cadence.
- **W38 · Content · P2 · S** — "Where we are today" has no date and no roadmap link, so it
  will read as stale within weeks. → Date it and link a changelog.
- **W39 · Navigation · P2 · S** — The About section claims browser parity but does not link
  to `/learn`. → Inline link in that paragraph.
- **W40 · Trust · P1 · M** — No team, organisation, address or contact detail anywhere on
  the site despite collecting children's guardian emails. → About block with who runs the
  academy and how to reach them.
- **W41 · A11y · P2 · S** — `.kicker` (10.5 px, 0.18em tracking, uppercase gold) is used for
  both numbering and category labels, so the two are indistinguishable. → Numbering gets a
  tabular figure style, categories get a chip.
- **W42 · Honesty · P2 · S** — The parents mock ("Ama's report") is HTML text styled as
  product UI with no "example" caption. → Add "Example report" to the card label.

## Download, CTA, FAQ (W43–W52)

- **W43 · Trust · P1 · S** — The APK link gives no size, version or checksum next to the
  button (the size is buried in a meta line). → Show `54 MB · 1.0.0-beta · SHA-256` under the
  button with a copy action.
- **W44 · Onboarding · P1 · S** — "You may need to allow installs from your browser" is the
  only install guidance. → Three numbered steps with the exact Android settings path.
- **W45 · Content · P2 · S** — No Play Store status beyond "coming", so the download path
  looks abandoned. → "Play release: in review" plus a notify-me action.
- **W46 · Access · P2 · S** — iOS and desktop visitors get a download card they cannot use
  with no alternative above it. → Detect platform and lead with `/learn`, keeping the APK
  secondary.
- **W47 · Copy · P2 · S** — The CTA headline restates the hero's thesis ("Built for the real
  device, not the ideal classroom"). → Make the CTA one concrete action ("Start step 1 in
  your browser — free").
- **W48 · Conversion · P1 · S** — The CTA offers "Start learning" and "Read privacy policy"
  but no sign-in for returning learners. → Add "Already learning? Log in".
- **W49 · Content · P2 · S** — FAQ answers run 40–60 words with no internal links. → Trim to
  two sentences each and link the policy/learn page.
- **W50 · SEO · P2 · S** — No `FAQPage` structured data for the six questions. → Emit JSON-LD
  from the same `faqs` array.
- **W51 · Interaction · P2 · S** — `<summary>` has no hover or expanded-state affordance
  beyond the rotating plus; the row is not obviously tappable. → Row hover, pointer cursor
  and a clear open state.
- **W52 · Support · P2 · S** — The FAQ ends with no way to ask a question. → "Still stuck?
  Email us" row with the support address.

## Navigation, footer, page shell (W53–W62)

- **W53 · A11y · P0 · M** — The mobile sheet is `role="dialog"` with no `aria-modal`, no
  focus trap and no Escape handler, so focus stays behind it. → Real dialog semantics with
  focus management, or a `<details>`-based disclosure.
- **W54 · A11y · P1 · S** — The menu button's label stays "Toggle menu" when open. → "Open
  menu" / "Close menu" with the existing `aria-expanded` and an icon swap.
- **W55 · A11y · P1 · S** — No `aria-current` on the active section or page link. → Scroll
  spy plus `aria-current="true"`.
- **W56 · Layout · P2 · S** — At ≤760 px `.nav-actions .btn-sm` hides Register but leaves the
  "Log in" text link, splitting a paired action. → Show both in the sheet, hide both in the
  bar.
- **W57 · IA · P1 · S** — Desktop section links omit the web app entirely; `/learn` is only
  reachable through CTAs. → Add "Web app" to the links, or a persistent secondary CTA.
- **W58 · Layout · P2 · S** — The mobile sheet mixes six anchors, a CTA and auth buttons in
  one undifferentiated list. → Group: sections / learning / account.
- **W59 · Layout · P2 · S** — The footer's seven links wrap into ragged rows with no
  grouping. → Three labelled columns (Learn, Family, Legal) or two tight rows.
- **W60 · Support · P1 · S** — The footer has no contact, support email, status or version. →
  Add a support address and the site build date.
- **W61 · Consistency · P2 · S** — Footer says "Web app", the sheet says "Start learning" and
  the hero says "Start learning on web" — three labels, one destination. → One label
  everywhere.
- **W62 · Navigation · P2 · S** — `/privacy`, `/terms` and the auth pages have no breadcrumb
  or back-to-home control besides the logo. → Add "← Back to site" on long documents.

## `/learn` (W63–W71)

- **W63 · Feedback · P0 · M** — The iframe has no loading skeleton, progress or timeout: on a
  weak connection the frame stays empty for 10–30 s. → Skeleton, "loading the app" state and
  a slow-connection hint.
- **W64 · Resilience · P1 · S** — If the app URL is misconfigured or blocks framing, the page
  shows a silent blank frame. → Detect load failure/timeout and show the direct link.
- **W65 · Compatibility · P1 · S** — Browsers that block third-party storage in an iframe
  (Safari private mode) lose progress with no warning. → Detect and prompt "Open in a new
  tab" when storage is unavailable.
- **W66 · Expectation · P1 · S** — The 45 MB first load is disclosed only as a footnote after
  the frame. → State the download next to the primary button.
- **W67 · Layout · P1 · S** — On a phone, the page shows a phone mock around the already
  phone-sized app: double chrome and nested scrolling. → Drop the bezel below 760 px.
- **W68 · Parity · P1 · S** — Nothing on the page says the same account works in the Android
  app, which is the main reason to use the web build. → Add one line with a sign-in hint.
- **W69 · Deep links · P2 · M** — No way to link a specific step (`/learn?step=5`) for a
  teacher or parent. → Pass a query param into the app and restore it.
- **W70 · Fallback · P2 · S** — No `<noscript>` or static explanation for script-blocked
  visitors. → Static paragraph inside the frame container.
- **W71 · A11y · P2 · S** — An iframe of a canvas app is opaque to screen readers; no
  external description of the app's controls is provided. → Keep the tip list as the
  accessible description and put "open full screen" first in tab order.

## Authentication pages (W72–W78)

- **W72 · Forms · P1 · S** — `noValidate` disables native checks and nothing replaces them, so
  `ama@` submits and only the server complains. → Inline validation on blur with
  `aria-invalid`.
- **W73 · Forms · P1 · S** — One `role="alert"` paragraph carries every error and inputs have
  no `aria-describedby`, so a screen-reader user cannot tell which field failed. → Per-field
  error nodes, focusing the first invalid field.
- **W74 · Forms · P1 · S** — No confirm-password field on registration; a typo creates an
  account nobody can log into. → Add one, with paste-friendly fields.
- **W75 · Forms · P2 · S** — `.password-hints` lists only "At least 8 characters" while the
  server may reject more. → Show the actual rule set the backend enforces.
- **W76 · Forms · P2 · S** — No autofocus and no `inputMode="email"`, so mobile keyboards open
  in text mode on email fields. → `autoFocus` on the first field, correct `inputMode`.
- **W77 · Flow · P1 · S** — The submit handler honours `?next=`, but the "Create an account" /
  "Log in" link drops it, so switching mode loses the destination. → Preserve `next` across
  mode switches.
- **W78 · Feedback · P2 · S** — "Copy email" only swaps its label; the change is not
  announced. → `aria-live="polite"` confirmation and selectable address text.

## Metadata and sharing (W79–W80)

- **W79 · SEO · P2 · S** — Only the root layout defines metadata; `/learn`, `/privacy`,
  `/terms` and the auth pages inherit the home title and description. → Per-page `metadata`
  exports.
- **W80 · Sharing · P2 · S** — No OpenGraph image, so shared links render as plain text. →
  Static 1200×630 brand card referenced from `openGraph.images`.

---

## How to use this list

1. **Week 1 — trust and legality:** A2, A9, A16, A39, A47, W2, W5, W10, W53, W63.
2. **Week 2 — login and the web app:** A1, A5, A6, A19, A21, W21, W64, W65, W68, W72.
3. **Week 3 — reading comfort:** A36, A37, W4, W6, W31, W36, W67.
4. **Then:** work top-down by severity inside each part. The P2 items are safe to batch into
   one design-system pass once the app and site share tokens.

## Limits of this audit

- No device or browser run: nothing here reports measured FPS, LCP, or contrast sampled from
  a screenshot. Contrast figures are computed from the hex values in the source.
- The app is roughly 40k lines of Dart. I audited `theme.dart`, the auth screen in full, the
  17-screen inventory, and cross-cutting greps (semantics, gesture handlers, font sizes,
  hard-coded colours) — not every widget on every screen.
- `website/lib/curriculum.ts`, `website/lib/web-progress.ts` and `components/CodeRunner.tsx`
  appear unused by the current routes and are excluded from the UI count.
