import 'package:flutter/foundation.dart';

import 'platform.dart';

/// Which concrete [PythonRuntime] implementation the app should build.
enum PythonRuntimeKind {
  /// Real embedded CPython via the `serious_python` plugin. On-device default.
  seriousPython,

  /// Spawns a host CPython child process. Development/test default.
  process,

  /// Real CPython compiled to WebAssembly (Pyodide), executed inside a Web
  /// Worker. The only real runtime a browser can host: it needs neither
  /// `dart:io` nor `dart:ffi`, and the worker keeps learner code off the UI
  /// thread so infinite loops can be terminated.
  pyodide,

  /// In-process fake that returns canned results. Used by widget tests that do
  /// not care about real execution.
  fake,
}

/// Central, compile-time/`--dart-define`-driven configuration.
///
/// Nothing here contains secrets. Anything environment specific (LMS base URL,
/// auth provider) is injected at build time via `--dart-define` and validated
/// at startup. See `docs/LMS_INTEGRATION.md`.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.lmsBaseUrl,
    required this.lmsClientId,
    required this.runtimeKind,
    required this.pythonExecutable,
    required this.executionTimeout,
    required this.maxOutputChars,
    this.aiTutorBaseUrl = '',
    this.guardianReportUrl = '',
    this.sharedApiBaseUrl = '',
    this.leaderboardUrl = '',
  });

  final String environment;
  final String lmsBaseUrl;
  final String lmsClientId;

  /// True when no real LMS URL was supplied and the mock must be used.
  bool get useMockLms => lmsBaseUrl.isEmpty;

  final PythonRuntimeKind runtimeKind;
  final String pythonExecutable;
  final Duration executionTimeout;
  final int maxOutputChars;
  final String aiTutorBaseUrl;

  /// Endpoint that emails a Parent / Guardian progress report through Resend
  /// (see `guardian_mailer/README.md`). Empty disables progress emails, which
  /// is the default for development and the offline mock.
  final String guardianReportUrl;

  /// Public origin of the website hosting `/api/auth` and shared API routes.
  /// This is an origin, not a Neon database URL or secret.
  ///
  /// On the web this is the origin the page itself was loaded from, because
  /// the bundle is always served by the same site that hosts `/api`. See
  /// [forCurrentPlatform].
  final String sharedApiBaseUrl;

  bool get cloudAuthEnabled => sharedApiBaseUrl.trim().isNotEmpty;

  /// Base URL of the website that serves `/api/leaderboard` (see
  /// `docs/LEADERBOARD.md`). Empty disables the leaderboard screen rather than
  /// pointing it at nothing.
  final String leaderboardUrl;

  bool get leaderboardEnabled => leaderboardUrl.trim().isNotEmpty;

  /// Base URL the tutor client should call.
  ///
  /// Falls back to the website's same-origin proxy (`/api/tutor`) when no Worker
  /// URL was compiled in. That is enough for the whole chain: the app already
  /// needs the site origin to sign in, the proxy forwards the bearer token, and
  /// the Worker still verifies it. Empty means "no cloud tutor" and the offline
  /// brain answers.
  String get aiTutorEndpoint {
    final explicit = aiTutorBaseUrl.trim();
    if (explicit.isNotEmpty) {
      return explicit.replaceFirst(RegExp(r'/+$'), '');
    }
    final shared = sharedApiBaseUrl.trim();
    if (shared.isEmpty) return '';
    return '${shared.replaceFirst(RegExp(r'/+$'), '')}/api/tutor';
  }

  bool get requiresCloudAuth =>
      kReleaseMode || environment.toLowerCase() == 'production';

  static const String _env = String.fromEnvironment(
    'SB_ENV',
    defaultValue: 'development',
  );
  static const String _lmsBaseUrl = String.fromEnvironment('SB_LMS_BASE_URL');
  static const String _lmsClientId = String.fromEnvironment('SB_LMS_CLIENT_ID');
  static const String _runtime = String.fromEnvironment('SB_PYTHON_RUNTIME');
  static const String _pythonExe = String.fromEnvironment(
    'SB_PYTHON_EXECUTABLE',
    defaultValue: '',
  );
  static const String _aiTutorBaseUrl = String.fromEnvironment(
    'SB_AI_TUTOR_BASE_URL',
  );
  static const String _guardianReportUrl = String.fromEnvironment(
    'SB_GUARDIAN_REPORT_URL',
  );
  static const String _sharedApiBaseUrl =
      String.fromEnvironment('SB_API_BASE_URL');
  static const String _leaderboardUrl = String.fromEnvironment(
    'SB_LEADERBOARD_URL',
  );

  /// Builds the configuration for the current platform.
  ///
  /// Runtime selection rules:
  ///  * Explicit `SB_PYTHON_RUNTIME` always wins.
  ///  * Otherwise mobile (Android/iOS) uses the embedded runtime and desktop
  ///    (dev/test) uses the host process, which is what makes automated
  ///    execution tests possible on a developer machine.
  factory AppConfig.forCurrentPlatform() {
    final kind = _resolveRuntimeKind();
    // The web bundle is served from `public/app` on the very site that hosts
    // `/api`, so the page's own origin is always the correct API base. Deriving
    // it here (rather than trusting a compiled-in origin) is what lets one
    // build work on the custom domain, its `www` host and any preview
    // deployment: the call stays same-origin, so the site's
    // `connect-src 'self'` CSP never blocks it. A compiled-in SB_API_BASE_URL
    // still wins off the web, where there is no document origin to read.
    final pageOrigin = _webOrigin();
    final sharedApi = pageOrigin.isNotEmpty ? pageOrigin : _sharedApiBaseUrl;
    return AppConfig(
      environment: _env,
      lmsBaseUrl: _lmsBaseUrl,
      lmsClientId: _lmsClientId,
      runtimeKind: kind,
      pythonExecutable: _pythonExe.isEmpty
          ? _defaultPythonExecutable()
          : _pythonExe,
      executionTimeout: const Duration(seconds: 10),
      maxOutputChars: 200000,
      aiTutorBaseUrl: _aiTutorBaseUrl,
      guardianReportUrl: _guardianReportUrl,
      sharedApiBaseUrl: sharedApi,
      // One server address is enough: the site serves the ranking API.
      leaderboardUrl: _leaderboardUrl.isNotEmpty
          ? _leaderboardUrl
          : (sharedApi.isNotEmpty ? sharedApi : _lmsBaseUrl),
    );
  }

  /// Configuration used by tests; the runtime kind is always injected.
  factory AppConfig.test({
    PythonRuntimeKind runtimeKind = PythonRuntimeKind.fake,
    String lmsBaseUrl = '',
  }) {
    return AppConfig(
      environment: 'test',
      lmsBaseUrl: lmsBaseUrl,
      lmsClientId: 'test-client',
      runtimeKind: runtimeKind,
      pythonExecutable: _defaultPythonExecutable(),
      executionTimeout: const Duration(seconds: 10),
      maxOutputChars: 200000,
    );
  }

  static PythonRuntimeKind _resolveRuntimeKind() {
    switch (_runtime) {
      case 'serious':
      case 'serious_python':
        return PythonRuntimeKind.seriousPython;
      case 'process':
        return PythonRuntimeKind.process;
      case 'pyodide':
        return PythonRuntimeKind.pyodide;
      case 'fake':
        return PythonRuntimeKind.fake;
    }
    if (kIsWeb) return PythonRuntimeKind.pyodide;
    if (isAndroid || isIOS) {
      return PythonRuntimeKind.seriousPython;
    }
    return PythonRuntimeKind.process;
  }

  /// Origin the bundle was loaded from, or `''` when there is no document
  /// origin (native builds, `file:`/opaque origins).
  ///
  /// `Uri.base` is the document base — `/app/index.html` under
  /// `<base href="/app/">` — and only the origin matters, so the served path
  /// is irrelevant. Returns `''` rather than an opaque `"null"` origin so the
  /// caller can fall back to a compiled-in URL.
  static String _webOrigin() {
    if (!kIsWeb) return '';
    final origin = Uri.base.origin;
    return origin.startsWith('http') ? origin : '';
  }

  static String _defaultPythonExecutable() {
    if (kIsWeb) return 'python';
    return isWindows ? 'python' : 'python3';
  }
}
