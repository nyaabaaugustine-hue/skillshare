import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands a bundled handout to the browser's own downloader.
///
/// Nothing in the DOM is shown: we build a `Blob` from the bytes, point a
/// throwaway `<a download>` at an object URL for it, and click it. That click
/// is the gesture browsers accept as a download, so the file lands in the
/// user's Downloads folder without navigating away from the app.
///
/// A page cannot choose the destination, so the returned sentence names the
/// folder rather than a path.
Future<String> saveHandout({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return 'Downloaded $fileName to your Downloads folder.';
}
