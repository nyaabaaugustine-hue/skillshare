# Error report — 2026-10-19

Project: `sepnet_lms`  
Scope: Flutter/Dart app plus `lms_ui` web app.

## Executive summary

The project cannot currently be validated end-to-end because required dependencies are unavailable locally and dependency downloads failed. `dart analyze lib` completed with **100 library issues**; the full `dart analyze` run reported **369 issues** across application and tests. Most are cascading diagnostics caused by unresolved packages. There is also one independent source error and three independent warnings.

## Independent source error

- `lib/features/quizzes/quiz.dart:4:9` — `const_constructor_with_non_final_field`: `Quiz` declares a `const` constructor, but `_correctIndex` at line 22 is mutable. Make the field `final`/initialize it through the constructor, or remove `const` from the constructor.

## Independent warnings

- `lib/features/course/course_lesson_screen.dart:5:8` — unused import: `shared/widgets/chunky_button.dart`.
- `lib/features/home/home_screen.dart:7:8` — unused import: `features/course/course_content.dart`.
- `lib/features/lms/lms_hub_screen.dart:767:7` — `_LessonJourney` is declared but never referenced.

## Dependency-resolution errors

The local Pub cache has none of the declared packages checked by the diagnostic run. The following imports fail with `uri_does_not_exist`:

- `provider`: `lib/app/app.dart`, `lib/features/achievements/achievements_screen.dart`, `lib/features/editor/editor_screen.dart`, `lib/features/exercises/exercise_details_screen.dart`, `lib/features/home/home_screen.dart`, `lib/features/lms/learning_path.dart`, `lib/features/lms/lms_hub_screen.dart`, `lib/features/settings/settings_screen.dart`, and `lib/main.dart`.
- `path`: `lib/core/storage/app_database.dart`, `lib/features/python_runtime/process_python_runtime.dart`.
- `sqflite`: `lib/core/storage/app_database.dart`, `database_factory_io_impl.dart`, `database_factory_web.dart`, `draft_repository.dart`, `exercise_repository.dart`, `schema_migrations.dart`, and `submission_repository.dart`.
- `sqflite_common_ffi`: `lib/core/storage/database_factory_io_impl.dart`.
- `sqflite_common_ffi_web`: `lib/core/storage/database_factory_web.dart`.
- `shared_preferences`: `lib/core/storage/settings_repository.dart`, `lib/features/course/course_progress_repository.dart`.
- `video_player`: `lib/features/lms/cloudinary_video_screen.dart`.
- `connectivity_plus`: `lib/features/offline_sync/connectivity_service.dart`.
- `http`: `lib/features/python_runtime/serious_python_runtime.dart`, `lib/integrations/lms/http_lms_client.dart`.
- `serious_python`: `lib/features/python_runtime/serious_python_runtime.dart`.

These missing imports produce the cascading undefined `Database`, `DatabaseFactory`, `DatabaseExecutor`, `SharedPreferences`, Provider extensions (`read`/`watch`), video-player symbols, connectivity symbols, `SeriousPython`, and related diagnostics reported by the analyzer.

## Analyzer configuration error

- `analysis_options.yaml:10:10` — `package:flutter_lints/flutter.yaml` cannot be resolved because `flutter_lints` is not available in the local package configuration.

## Tests and web checks

- `flutter analyze --no-pub` and `flutter test --no-pub` could not start because Flutter attempted to resolve package `test` and failed to reach `https://pub.dev`.
- Direct `dart analyze` was able to run against the incomplete package configuration, but it is not a clean dependency-complete validation.
- The `lms_ui` package has no `node_modules`; `npm install` failed while fetching `undici-types` with OS error `EACCES`. Therefore `npm run typecheck` and `npm run build` were not executable.

## Additional Flutter Web runtime error from the attached trace

The browser trace contains repeated runtime exceptions during widget rebuilds:

`Another exception was thrown: Assertion failed: file:///C:/src/flutter/packages/flutter/lib/src/widgets/framework.dart:2170:12`

The stack repeatedly passes through `text_form_field_row.dart.lib.js` (`performRebuild`, `rebuild`, `updateChild`) and Provider/nested widget mounts. This indicates a widget-tree/state lifecycle assertion during a `TextFormFieldRow` rebuild, not a compile-time error. The pasted trace does not include the assertion's source condition or the application Dart frame that created the offending row, so the exact application file cannot be identified from this trace alone. The repeated assertion should be debugged by checking `TextFormFieldRow`/text-field lifecycle code for state mutation or tree changes during build, and by reproducing with Flutter Web debug assertions enabled.

## Concrete Flutter Web TypeError from the second attached trace

The second trace provides the direct application-level failure:

`TypeError: null: type 'Null' is not a subtype of type 'Map<String, String>'`

The relevant widget is `_InheritedProviderScope<ConnectivityController?>`, but the actual failing application frame is `lib/app/router.dart:76:41`, inside `AppRouter.onGenerateRoute` for the `/lms-video` route:

```dart
final args = settings.arguments as Map<String, String>;
```

The route was opened without arguments, so `settings.arguments` is null and the cast fails while Flutter is generating/restoring the initial route. This is the confirmed root cause of that startup error. The route should validate or default missing arguments before casting, or the caller should always pass the required map. The same file contains other unsafe route casts that can produce similar runtime failures when arguments are missing: `editor` at line 34, `exercise` at line 40, and `courseLesson` at line 86.

The third attached trace is a duplicate of this same failure: it reports the identical null-to-`Map<String, String>` TypeError, the same `_InheritedProviderScope<ConnectivityController?>`, and the same `lib/app/router.dart:76:41` stack frame. It adds no new distinct error.

## Latest dependency-complete run

The fourth attachment shows that `flutter pub get` now succeeds, so the earlier missing-package cascade is superseded by a clean dependency-aware result. `flutter analyze` reports **12 issues**:

- `lib/app/theme.dart:100:29` and `:101:31` — `CupertinoPageTransitionsBuilder` is not defined. This also causes `invalid_constant` and `non_constant_map_value` at those entries. The file imports only `package:flutter/material.dart`; add the Cupertino import or use a transition builder available from the current Flutter API.
- `lib/features/home/guardian_home_screen.dart:452:31` — `CourseStepKind.label` is not visible. The extension exists in `features/course/course_models.dart`, but `guardian_home_screen.dart` does not directly import that library; add the import or expose the extension through an existing public import.
- `lib/features/lms/lms_hub_screen.dart:767:7` — unused `_LessonJourney` declaration.
- `test/all_units_smoke_test.dart:6:8` — unused `exercise.dart` import.
- Four informational lints were also reported: unnecessary underscores at `lib/features/ai/ai_tutor_screen.dart:879:31` and `lib/features/lms/lms_hub_screen.dart:151:31`, a null-aware-elements suggestion at `lib/features/lessons/lesson_player_screen.dart:132:47`, and a function-declaration suggestion at `lib/features/quizzes/quiz_screen.dart:40:13`.

`flutter test` completed with **7 failed test loads**, all caused by the same `CupertinoPageTransitionsBuilder` compile error in `lib/app/theme.dart:100-101`; the affected test files shown in the trace include `ai_tutor_test.dart`, `all_units_smoke_test.dart`, `auth_flow_test.dart`, `course_path_test.dart`, `editor_real_runtime_test.dart`, `lesson_screen_test.dart`, and `widget_test.dart`. The migration test logs `SqfliteFfiException` for `THIS IS NOT SQL` while exercising its rollback guard-rail case; the test name continues without an additional failure count, indicating this is the intentionally injected exception being tested rather than a separate failure.

The release APK build fails before compilation because `serious_python_android-5.0.0` requires `SERIOUS_PYTHON_SITE_PACKAGES`:

`C:\Users\TGNE\AppData\Local\Pub\Cache\hosted\pub.dev\serious_python_android-5.0.0\android\build.gradle.kts:229 — SERIOUS_PYTHON_SITE_PACKAGES environment variable is not set.`

Device installation was not attempted successfully because `adb` is not available on PATH; both `adb devices` and `adb install -r ...` return `CommandNotFoundException`.

## Recommended order of repair

1. Restore network/package-cache access and run `flutter pub get` in `sepnet_lms`.
2. Re-run `flutter analyze` and `flutter test`; discard the dependency-cascade diagnostics that disappear after package resolution.
3. Fix the independent `Quiz` constructor/field mismatch.
4. Fix the missing Cupertino and CourseStepKind imports, then rerun analysis/tests.
5. Set `SERIOUS_PYTHON_SITE_PACKAGES` according to the serious_python Android setup and rerun the release APK build.
6. Add Android SDK platform-tools to PATH or use the full `adb.exe` path before device installation.
7. Remove or use the unused declarations/imports.
8. Install `lms_ui` dependencies successfully, then run `npm run typecheck` and `npm run build`.

## Raw diagnostic artifacts

- Library analyzer output: `.work/dart-analyze-lib.txt`.
- The full-project analyzer output was captured in the session runtime while producing this report; the summarized counts above preserve the actionable findings even though dependency failures dominate the raw output.
