import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;

import 'package:skillbridge_python_lab/core/errors/app_exception.dart';

import 'execution_result.dart';
import 'python_runtime.dart';

/// Default location of the Pyodide distribution (CPython compiled to
/// WebAssembly) on the public CDN.
///
/// Override per build with `--dart-define=SB_PYODIDE_INDEX_URL=...` when the
/// distribution is vendored next to the app.
const String defaultPyodideIndexURL = String.fromEnvironment(
  'SB_PYODIDE_INDEX_URL',
  defaultValue: 'https://cdn.jsdelivr.net/pyodide/v0.26.4/full/',
);

/// Executes learner code with a **real** CPython interpreter compiled to
/// WebAssembly (Pyodide), running inside a dedicated Web Worker.
///
/// Why a worker:
///  * A browser has neither `dart:io` (no subprocess) nor `dart:ffi` (no
///    embedded interpreter), so Pyodide is the only way to get real Python
///    onto the web build.
///  * Running the interpreter blocks the thread it runs on. A runaway
///    `while True:` inside a worker only freezes the worker, so the timeout and
///    the Stop button keep working: both terminate the worker and a fresh one
///    is spawned on demand.
///
/// The executor itself is **not** reimplemented here: the worker loads the same
/// `python_app/skillbridge_exec.py` that drives the host-process runtime and
/// the on-device HTTP server, so every target shares one code path.
@JS('Worker')
extension type _WorkerJS._(JSObject _) implements JSObject {
  external factory _WorkerJS(JSString url);
  external void postMessage(JSAny? message);
  external void terminate();
  external void addEventListener(JSString type, JSFunction listener);
}

@JS('MessageEvent')
extension type _MessageEventJS(JSObject _) implements JSObject {
  external JSAny? get data;
}

@JS('ErrorEvent')
extension type _ErrorEventJS(JSObject _) implements JSObject {
  external JSAny? get message;
}

class PyodidePythonRuntime implements PythonRuntime {
  PyodidePythonRuntime({
    String? workerURL,
    String? indexURL,
    this.defaultTimeout = const Duration(seconds: 10),
    this.defaultMaxOutputChars = 200000,
    this.initTimeout = const Duration(minutes: 3),
  }) : workerURL = workerURL ?? _resolveWorkerURL(),
       indexURL = indexURL ?? defaultPyodideIndexURL;

  /// URL of the worker script, resolved against the app's base URL.
  final String workerURL;

  /// Base URL of the Pyodide distribution.
  final String indexURL;

  final Duration defaultTimeout;
  final int defaultMaxOutputChars;

  /// How long the interpreter may take to load (the first run downloads it).
  final Duration initTimeout;

  _WorkerJS? _worker;
  Future<void>? _initFuture;
  Completer<void>? _initCompleter;
  Completer<ExecutionResult>? _pending;
  Timer? _initTimer;
  Timer? _runTimer;
  String _pythonVersion = '';
  int _sequence = 0;
  bool _ready = false;
  bool _disposed = false;

  static String _resolveWorkerURL() =>
      Uri.base.resolve('pyodide_worker.js').toString();

  @override
  String get displayName => _pythonVersion.isEmpty
      ? 'Pyodide (CPython, WebAssembly)'
      : 'Pyodide CPython ($_pythonVersion)';

  @override
  bool get isReady => _ready;

  @override
  Future<void> prepare() async {
    if (_disposed || _ready) return;

    final existing = _initFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final pending = _start();
    _initFuture = pending;
    try {
      await pending;
    } catch (_) {
      // Drop the failed future so the editor's retry button really retries.
      if (identical(_initFuture, pending)) _initFuture = null;
      rethrow;
    }
  }

  Future<void> _start() {
    final completer = Completer<void>();
    _initCompleter = completer;

    _initTimer?.cancel();
    _initTimer = Timer(initTimeout, () {
      if (!identical(_initCompleter, completer)) return;
      _initCompleter = null;
      _terminateWorker();
      if (!completer.isCompleted) {
        completer.completeError(
          const RuntimeException(
            'Downloading the Python interpreter took too long. '
            'Check your connection and try again.',
          ),
        );
      }
    });

    _spawn();
    unawaited(_sendInit());
    return completer.future;
  }

  /// Sends the init message together with the executor source.
  ///
  /// The source is read through Flutter's own asset bundle, the same channel
  /// that loads the rest of the app, so the runner no longer depends on the
  /// host exposing `assets/...` or a loose `.py` file to the worker. The worker
  /// only falls back to fetching it when this read fails.
  Future<void> _sendInit() async {
    String? source;
    try {
      source = await rootBundle.loadString('python_app/skillbridge_exec.py');
    } catch (_) {
      source = null;
    }
    if (_disposed || _worker == null) return;
    _post({'type': 'init', 'indexURL': indexURL, 'executorSource': source});
  }

  @override
  Future<ExecutionResult> execute(ExecutionRequest request) async {
    if (!_ready) await prepare();

    final worker = _worker;
    if (worker == null) {
      return ExecutionResult.runtimeFailure(
        'The Python runner is not available in this build.',
      );
    }

    final timeout = request.timeout ?? defaultTimeout;
    final maxChars = request.maxOutputChars ?? defaultMaxOutputChars;
    final completer = Completer<ExecutionResult>();
    _pending = completer;
    final id = ++_sequence;

    _runTimer?.cancel();
    _runTimer = Timer(timeout, () {
      if (!identical(_pending, completer)) return;
      // Terminating the worker is the only hard stop a browser offers for an
      // in-flight WebAssembly program.
      _stopWorker();
      _completePending(ExecutionResult.timedOut(timeout));
      _restartQuietly();
    });

    _post({
      'type': 'run',
      'id': id,
      'job': {
        'code': request.code,
        'stdin': request.stdinLines,
        'maxOutputChars': maxChars,
        // No cpuSeconds: Pyodide has no SIGALRM, and the worker termination
        // driven by [timeout] is the authoritative stop.
      },
    });

    try {
      return await completer.future;
    } finally {
      _runTimer?.cancel();
      _runTimer = null;
      if (identical(_pending, completer)) _pending = null;
    }
  }

  @override
  Future<void> cancel() async {
    if (_disposed || _pending == null) return;
    _runTimer?.cancel();
    _runTimer = null;
    _stopWorker();
    _completePending(ExecutionResult.cancelled());
    _restartQuietly();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initTimer?.cancel();
    _initTimer = null;
    _runTimer?.cancel();
    _runTimer = null;
    final init = _initCompleter;
    _initCompleter = null;
    if (init != null && !init.isCompleted) {
      init.completeError(const RuntimeException('The Python runner stopped.'));
    }
    _terminateWorker();
    _completePending(ExecutionResult.cancelled());
    _initFuture = null;
    _ready = false;
  }

  /// Starts a replacement worker without blocking the caller. A failure here is
  /// surfaced by the next explicit [prepare].
  void _restartQuietly() {
    if (_disposed) return;
    scheduleMicrotask(() {
      if (_disposed || _ready) return;
      prepare().catchError((Object _) => null);
    });
  }

  void _spawn() {
    _terminateWorker();
    final worker = _WorkerJS(workerURL.toJS);
    _worker = worker;
    worker.addEventListener('message'.toJS, _onMessage.toJS);
    worker.addEventListener('error'.toJS, _onWorkerError.toJS);
  }

  void _post(Map<String, Object?> payload) {
    final worker = _worker;
    if (worker == null) return;
    worker.postMessage(jsonEncode(payload).toJS);
  }

  void _onMessage(JSObject event) {
    final decoded = _MessageEventJS(event).data?.dartify();
    if (decoded is! String) return;

    final Map<String, dynamic> message;
    try {
      message = jsonDecode(decoded) as Map<String, dynamic>;
    } on FormatException {
      return;
    }

    switch (message['type']) {
      case 'ready':
        _pythonVersion = message['pythonVersion']?.toString() ?? '';
        _ready = true;
        _initTimer?.cancel();
        final ready = _initCompleter;
        _initCompleter = null;
        if (ready != null && !ready.isCompleted) ready.complete();
      case 'result':
        final result = message['result'];
        if (result is Map) {
          _completePending(
            ExecutionResult.fromJson(Map<String, dynamic>.from(result)),
          );
        }
      case 'run-error':
        _completePending(
          ExecutionResult.runtimeFailure(
            message['message']?.toString() ?? 'The Python runner stopped.',
          ),
        );
      case 'init-error':
        _initTimer?.cancel();
        _terminateWorker();
        _ready = false;
        _failInit(
          RuntimeException(
            message['message']?.toString().trim().isNotEmpty == true
                ? 'The Python interpreter could not start: '
                      '${message['message']}'
                : 'The Python interpreter could not start.',
          ),
        );
    }
  }

  void _onWorkerError(JSObject event) {
    final detail = _ErrorEventJS(event).message?.dartify();
    final text = detail is String && detail.isNotEmpty
        ? detail
        : 'unknown error';

    if (_initCompleter != null) {
      _initTimer?.cancel();
      _terminateWorker();
      _ready = false;
      _failInit(
        RuntimeException(
          'The Python interpreter could not be loaded ($text). The web build '
          'downloads CPython (WebAssembly) on its first run, so it needs a '
          'connection or a vendored copy of Pyodide.',
        ),
      );
      return;
    }

    _runTimer?.cancel();
    _runTimer = null;
    _terminateWorker();
    _ready = false;
    _completePending(
      ExecutionResult.runtimeFailure('The Python runner stopped: $text'),
    );
  }

  /// Fails the in-flight [prepare] with [error], if any is waiting.
  void _failInit(RuntimeException error) {
    final init = _initCompleter;
    _initCompleter = null;
    if (init != null && !init.isCompleted) init.completeError(error);
  }

  /// Settles the in-flight [execute], if any.
  void _completePending(ExecutionResult result) {
    final pending = _pending;
    _pending = null;
    if (pending == null || pending.isCompleted) return;
    _runTimer?.cancel();
    _runTimer = null;
    pending.complete(result);
  }

  void _stopWorker() {
    _terminateWorker();
    _ready = false;
  }

  void _terminateWorker() {
    _worker?.terminate();
    _worker = null;
    // The worker is gone, so any recorded prepare no longer describes reality:
    // the next prepare must spawn a fresh one.
    _initFuture = null;
  }
}
