/// Web implementation of the runtime factory.
///
/// A browser can spawn no subprocess (`dart:io`) and load no native library
/// (`dart:ffi`), so the two native runtimes are refused loudly rather than
/// silently falling back to something fake. What a browser *can* host is
/// CPython compiled to WebAssembly, which is what [createPyodideRuntime]
/// builds; `AppConfig` selects it whenever `SB_PYTHON_RUNTIME` is unset, so
/// `SB_PYTHON_RUNTIME=process` (or `serious`) on web is a build mistake and
/// gets an error that says exactly that.
library;

import 'pyodide_python_runtime.dart';
import 'python_runtime.dart';

/// Real CPython (Pyodide, WebAssembly) running in a Web Worker.
PythonRuntime createPyodideRuntime({
  required Duration defaultTimeout,
  required int defaultMaxOutputChars,
}) {
  return PyodidePythonRuntime(
    defaultTimeout: defaultTimeout,
    defaultMaxOutputChars: defaultMaxOutputChars,
  );
}

/// Refused: the web build has no embedded interpreter.
PythonRuntime createSeriousPythonRuntime({
  required Duration defaultTimeout,
  required int defaultMaxOutputChars,
}) {
  throw UnsupportedError(
    'The embedded Python runtime is not available on the web: it needs '
    'dart:ffi, which browsers do not provide. Leave SB_PYTHON_RUNTIME unset '
    'to use Pyodide, or set SB_PYTHON_RUNTIME=pyodide.',
  );
}

/// Refused: the web build cannot spawn a subprocess.
PythonRuntime createProcessPythonRuntime({
  required String pythonExecutable,
  required Duration defaultTimeout,
  required int defaultMaxOutputChars,
}) {
  throw UnsupportedError(
    'The host-process Python runtime is not available on the web: it needs '
    'dart:io, which browsers do not provide. Leave SB_PYTHON_RUNTIME unset '
    'to use Pyodide, or set SB_PYTHON_RUNTIME=pyodide.',
  );
}
