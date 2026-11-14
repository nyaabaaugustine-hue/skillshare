import 'package:skillbridge_python_lab/core/config/app_config.dart';
import 'fake_python_runtime.dart';
import 'python_runtime.dart';
// `dart.library.io` is true on every native target and false on web (dart2js
// and wasm). The legacy `dart.library.html` guard is not set by modern Flutter
// web, so keying off it pulled the `dart:ffi`-based native factory into the
// browser build and broke startup.
import 'python_runtime_factory_web.dart'
    if (dart.library.io) 'python_runtime_factory_io.dart';

/// Constructs the runtime selected by [AppConfig.runtimeKind].
///
/// This is the single place that knows about concrete runtimes, keeping the
/// rest of the app dependent only on the [PythonRuntime] interface.
///
/// The concrete runtimes live behind a conditional import: the embedded
/// runtime (`dart:ffi`) and the host-process runtime (`dart:io`) cannot exist
/// in a browser and the Pyodide runtime (`dart:js_interop`) has no meaning on
/// a native platform, and merely importing the wrong one is a *compile* error
/// rather than a runtime one. Splitting the implementation lets each build
/// resolve to its own factories, with the unsupported kinds refusing loudly.
PythonRuntime createPythonRuntime(AppConfig config) {
  switch (config.runtimeKind) {
    case PythonRuntimeKind.seriousPython:
      return createSeriousPythonRuntime(
        defaultTimeout: config.executionTimeout,
        defaultMaxOutputChars: config.maxOutputChars,
      );
    case PythonRuntimeKind.process:
      return createProcessPythonRuntime(
        pythonExecutable: config.pythonExecutable,
        defaultTimeout: config.executionTimeout,
        defaultMaxOutputChars: config.maxOutputChars,
      );
    case PythonRuntimeKind.pyodide:
      return createPyodideRuntime(
        defaultTimeout: config.executionTimeout,
        defaultMaxOutputChars: config.maxOutputChars,
      );
    case PythonRuntimeKind.fake:
      return FakePythonRuntime();
  }
}
