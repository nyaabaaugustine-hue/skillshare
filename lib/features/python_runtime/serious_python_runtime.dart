import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serious_python/serious_python.dart';

import 'package:skillbridge_python_lab/core/errors/app_exception.dart';
import 'execution_result.dart';
import 'python_runtime.dart';

/// Executes Python using the *embedded* CPython runtime provided by the
/// `serious_python` plugin, as required for on-device (Android/iOS) execution.
///
/// Serious Python does not expose a "call this Python function" API. Instead it
/// runs a Python *program* and the two sides communicate over an API the
/// program provides. We package `python_app/main.py`, which starts a
/// loopback-only HTTP server exposing `/health` and `/execute`; this class
/// drives that server over `http://127.0.0.1`.
///
/// Packaging (run once before a device build) — see `docs/BUILD_AND_RELEASE.md`.
/// `serious_python` 5.0.0 stages the processed app into `SERIOUS_PYTHON_APP`,
/// which the platform build then copies into the bundle, so the variable has to
/// be set for both the package command and `flutter build`:
///
/// ```
/// $env:SERIOUS_PYTHON_APP           = "$PWD/build/python-app"
/// $env:SERIOUS_PYTHON_SITE_PACKAGES = "$PWD/build/python-site-packages"
/// dart run serious_python:main package python_app -p Android
/// dart run serious_python:main package python_app -p iOS
/// ```
class SeriousPythonRuntime implements PythonRuntime {
  SeriousPythonRuntime({
    this.port = 8791,
    this.defaultTimeout = const Duration(seconds: 10),
    this.defaultMaxOutputChars = 200000,
    http.Client? httpClient,
    Future<void> Function()? startHook,
  })  : _http = httpClient ?? http.Client(),
        _startHookOverride = startHook;

  final int port;
  final Duration defaultTimeout;
  final int defaultMaxOutputChars;
  final http.Client _http;

  /// Overrides the startup sequence in tests. When null, the default
  /// [_startWithDiagnostics] is used.
  final Future<void> Function()? _startHookOverride;
  bool _ready = false;
  bool _started = false;

  /// Non-null once [SeriousPython.run] has resolved. On success it is `null`
  /// (the program is a long-lived server); on failure it carries the message
  /// the plugin returned (e.g. `Python exited with code 1`). Recorded so that a
  /// health-poll timeout can explain *why* the runtime never came up instead of
  /// reporting an opaque timeout.
  String? _runResult;
  Object? _runError;
  bool _runDone = false;

  Uri get _base => Uri.parse('http://127.0.0.1:$port');

  @override
  String get displayName => 'Embedded CPython (Serious Python)';

  @override
  bool get isReady => _ready;

  /// Explicitly materializes the packaged app on disk and starts the program,
  /// capturing any startup error. Mirrors [SeriousPython.run] but keeps the
  /// failure visible instead of discarding the result.
  Future<void> _startWithDiagnostics() async {
    // Unpacking (Android `app.zip` -> writable dir) is where a stale or missing
    // package fails first; surface it rather than waiting for a blind timeout.
    try {
      await SeriousPython.prepareApp();
    } catch (e) {
      throw RuntimeException(
        'The embedded Python runtime could not be unpacked on this device. '
        'This usually means the app was built without packaging python_app.',
        cause: e,
      );
    }

    // Launch the program and record how (and whether) it resolves. A server
    // program never completes, so `_runDone` stays false on success.
    unawaited(
      SeriousPython.run(
        appFileName: 'main.py',
        environmentVariables: {'SKILLBRIDGE_PORT': '$port'},
      ).then((result) {
        _runResult = result;
        _runDone = true;
      }).catchError((Object e) {
        _runError = e;
        _runDone = true;
      }),
    );
  }

  /// The most useful explanation available for a failed startup.
  String _failureDetail() {
    if (_runError != null) {
      return 'The runtime reported an error: $_runError';
    }
    if (_runDone && _runResult != null) {
      return 'The runtime process reported: $_runResult';
    }
    if (_runDone) {
      return 'The runtime process exited before the server responded.';
    }
    return 'The runtime process is still starting but the server never '
        'answered on 127.0.0.1:$port.';
  }

  @override
  Future<void> prepare() async {
    if (_ready) return;
    if (!_started) {
      _started = true;
      try {
        // `_startHookOverride` is injectable for tests; the default starts with
        // full diagnostics instead of a fire-and-forget call.
        await (_startHookOverride ?? _startWithDiagnostics)();
      } catch (e) {
        throw RuntimeException('Could not start the embedded Python runtime.', cause: e);
      }
    }

    // Poll the health endpoint until the interpreter is accepting requests.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _http
            .get(_base.replace(path: '/health'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['ok'] == true) {
            _ready = true;
            return;
          }
        }
      } catch (_) {
        // Not up yet; keep polling.
      }
      // Fail fast when the program has already terminated: polling a dead
      // process for the full 30 s only delays a clear error.
      if (_runDone) {
        throw RuntimeException(
          'The embedded Python runtime stopped before it was ready. '
          '${_failureDetail()}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw RuntimeException(
      'The embedded Python runtime did not start in time. ${_failureDetail()}',
    );
  }

  @override
  Future<ExecutionResult> execute(ExecutionRequest request) async {
    if (!_ready) {
      await prepare();
    }
    final timeout = request.timeout ?? defaultTimeout;
    final maxChars = request.maxOutputChars ?? defaultMaxOutputChars;

    try {
      final response = await _http
          .post(
            _base.replace(path: '/execute'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': request.code,
              'stdin': request.stdinLines,
              'maxOutputChars': maxChars,
            }),
          )
          // A little grace beyond the in-Python alarm so the result can travel back.
          .timeout(timeout + const Duration(seconds: 2));

      if (response.statusCode != 200) {
        return ExecutionResult.runtimeFailure(
          'The Python runtime returned status ${response.statusCode}.',
        );
      }
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return ExecutionResult.fromJson(map);
    } on TimeoutException {
      // The in-interpreter SIGALRM should fire first on POSIX; this is a fallback.
      return ExecutionResult.timedOut(timeout);
    } catch (e) {
      return ExecutionResult.runtimeFailure('Python execution failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    // The embedded runtime owns the interpreter thread and exposes no kill
    // primitive. Cancellation is therefore best-effort: the on-device
    // SIGALRM/host timeout stops runaway programs. Documented as a limitation.
  }

  @override
  Future<void> dispose() async {
    _http.close();
    _ready = false;
  }
}
