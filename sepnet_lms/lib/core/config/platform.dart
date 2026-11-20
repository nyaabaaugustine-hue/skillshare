/// Resolves to the native or web platform shim depending on the build target.
///
/// See `platform_io.dart` for why this indirection exists.
///
/// The guard is `dart.library.io`, not the legacy `dart.library.html`: the
/// older web bootstrap defined `html`, but modern Flutter web (dart2js on the
/// js_interop bootstrap and the wasm target) does **not**, so keying off `html`
/// silently selected the `dart:io` shim in the browser and broke the build.
/// `dart.library.io` is true on every native target and false on web, which is
/// exactly the split we want.
library;

export 'platform_web.dart' if (dart.library.io) 'platform_io.dart';
