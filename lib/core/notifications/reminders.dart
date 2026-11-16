/// Platform notifications.
///
/// The browser build has no local-notification scheduler (and no guaranteed
/// permission), so it exports a no-op implementation. Native builds get the
/// real Android/iOS scheduling. The split is `dart.library.io` for the same
/// reason as `core/config/platform.dart`: modern Flutter web does not define
/// `dart.library.html`.
library;

export 'reminders_stub.dart' if (dart.library.io) 'reminders_io.dart';
