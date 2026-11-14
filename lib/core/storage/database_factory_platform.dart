/// Platform-specific choice of SQLite implementation.
///
/// `sqflite` only ships an Android/iOS plugin. Desktop and `flutter test` need
/// `sqflite_common_ffi`, which loads SQLite through `dart:ffi` — a library that
/// does not exist in a browser. Pointing the build at a conditional export
/// means the web build never compiles the FFI package at all.
///
/// The guard is `dart.library.io`, not the legacy `dart.library.html`: modern
/// Flutter web (dart2js js_interop bootstrap and wasm) does not define `html`,
/// so keying off it selected the `dart:ffi` implementation in the browser and
/// broke startup. `dart.library.io` is true only on native targets.
///
/// Both implementations export the same two names, so callers import this file
/// and use them without knowing which one was selected.
library;

export 'database_factory_web.dart'
    if (dart.library.io) 'database_factory_io_impl.dart';
