# SkillsBridge UI Redesign Plan

## Design read

This is a redesign of an access-first learning product for learners and families, with a premium-consumer / Apple-inspired language leaning toward calm dark surfaces, a restrained blue action accent, generous spacing, and clear progress states.

## Design system

- **Design movement:** calm dark editorial product UI with premium-consumer restraint.
- **Core principles:** one clear action per surface; progress is visible without feeling gamified; readable type and touch targets; motion is subtle and optional.
- **Color philosophy:** deep ink surfaces create focus, blue is reserved for actions and focus, amber is reserved for achievement/progress, and muted text stays high contrast.
- **Layout paradigm:** responsive grid for page skeletons, intrinsic sizing for cards, and bounded reading columns; avoid fixed-height viewport traps.
- **Signature elements:** progress rails, soft outlined cards, and compact status pills that carry meaning rather than decoration.
- **Interaction philosophy:** controls explain their state, preserve native semantics, and keep the learner’s next action obvious.
- **Animation:** short transform/opacity transitions only, with a reduced-motion path that removes non-essential motion without hiding content.
- **Typography:** existing display/body fonts remain in use; headings are tight and confident, body copy is spacious, and code stays monospace.
- **Brand essence:** practical Python learning for the phone a learner already has; accessible, honest, and quietly ambitious.

## Implementation scope

1. Refine website tokens, focus states, responsive grid behavior, media stability, and reduced-motion handling without changing the hero video requirement.
2. Improve `/learn` as a clear framed web-app shell with a responsive stage, stable iframe sizing, explicit loading states, and accessible controls.
3. Refine Flutter theme tokens and navigation surfaces for a shared calm visual language across Android and Flutter web.
4. Improve the course path and editor presentation only through layout/theme-safe changes; preserve offline storage, CPython execution, grading, submissions, and route behavior.

## Project structure

- `website/app/page.tsx`: marketing homepage semantics and media.
- `website/app/globals.css`: website tokens, layout, media, responsive and accessibility rules.
- `website/app/learn/page.tsx` and `learn.css`: web-app shell around the Flutter web build.
- `sepnet_lms/lib/app/theme.dart`: shared Flutter Material 3 tokens.
- `sepnet_lms/lib/features/course/course_path_screen.dart`: learner path and progress surface.
- `sepnet_lms/lib/features/editor/editor_screen.dart`: Python practice interaction.

## Acceptance outcomes

- Website and `/learn` remain buildable and preserve existing links, supplied Cloudinary assets, and the full-opacity hero video.
- Keyboard focus remains visible, reduced-motion users do not lose meaningful content, media reserves layout space, and responsive layouts do not require overflow masking.
- Flutter Android and Flutter web share the refined theme while preserving offline-first behavior, real Python execution, grading, progress persistence, and existing routes.
- Validation includes website production build, Flutter formatting/analyzer, targeted UI tests, and a release APK rebuild only as an internal artifact until signing and known editor failures are resolved.


## Superseding implementation direction (approved)

The browser LMS is being implemented as native Next.js routes, not a Flutter iframe. Keep Flutter as the separate mobile client and preserve the current local Next.js/Neon setup.

- `/learn` is a native browser learner dashboard and `/learn/[stepId]` is its shareable lesson workspace.
- Reuse the actual Python Kickstart manifest (14 steps: eight videos and six code practices) and the existing Pyodide `CodeRunner`.
- Guest progress and code drafts remain local to the browser. Signed-in course completion uses the current authenticated progress API and transmits only event metadata, never code.
- Preserve SkillBridge's blue/navy/gold identity and responsive behavior. Do not represent teacher/admin dashboards, exams, assignments, certificates, or subscriptions as implemented where the source does not contain them.
- The earlier iframe-shell scope above is superseded for the website; no Flutter bundle is embedded in `/learn`.
