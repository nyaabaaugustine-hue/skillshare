import 'dart:typed_data';

// `dart.library.io` is true on every native target and false on web, so each
// build resolves to its own saver. The browser has no file system to write to,
// and `dart:js_interop` means nothing natively; importing the wrong one is a
// compile error rather than a runtime one. Same split the Python runtimes use
// (see features/python_runtime/python_runtime_factory.dart).
import 'handout_saver_web.dart' if (dart.library.io) 'handout_saver_io.dart'
    as saver;

/// Hands a bundled handout to the learner.
///
/// [bytes] is the file itself and [fileName] is what it should be called on
/// disk. Returns a short, already-worded sentence for the snackbar saying where
/// the file went, because that differs per platform: the browser owns the
/// download folder, while the native builds write into the app's documents.
Future<String> saveHandout({
  required Uint8List bytes,
  required String fileName,
}) {
  return saver.saveHandout(bytes: bytes, fileName: fileName);
}
