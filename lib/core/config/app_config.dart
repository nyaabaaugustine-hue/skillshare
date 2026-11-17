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
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
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

  /// Shared-account backend (see `docs/SHARED_ACCOUNTS.md`). When both values
  /// are present the app signs in against the same Supabase project from
  /// Android and from the web build, so one account works on both. Development
  /// and tests may use offline auth when these values are empty; release or
  /// production-environment builds reject local mock sign-in.
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get cloudAuthEnabled =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Base URL of the website that serves `/api/leaderboard` (see
  /// `docs/LEADERBOARD.md`). Empty disables the leaderboard screen rather than
  /// pointing it at nothing.
  final String leaderboardUrl;

  bool get leaderboardEnabled => leaderboardUrl.trim().isNotEmpty;

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
  static const String _supabaseUrl = String.fromEnvironment('SB_SUPABASE_URL');
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SB_SUPABASE_ANON_KEY',
  );
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
      supabaseUrl: _supabaseUrl,
      supabaseAnonKey: _supabaseAnonKey,
      // One server address is enough: the site serves the ranking API.
      leaderboardUrl: _leaderboardUrl.isNotEmpty
          ? _leaderboardUrl
          : _lmsBaseUrl,
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

  static String _defaultPythonExecutable() {
    if (kIsWeb) return 'python';
    return isWindows ? 'python' : 'python3';
  }
}
