import 'push_message.dart';

/// What the app needs from a push provider.
///
/// Kept separate from [PushService] so token registration and UI routing can be
/// tested without touching Firebase plugins.
abstract interface class PushGateway {
  /// Whether this build can receive push messages at all.
  bool get supported;

  Future<void> initialize({String? vapidKey});

  /// True when the OS/browser granted notification permission.
  Future<bool> requestPermission();

  /// Current FCM registration token, or `null` when unavailable.
  Future<String?> token();

  /// Invalidates the local FCM token.
  Future<void> deleteToken();

  /// Message that launched the app from a terminated state, if any.
  Future<PushMessage?> initialMessage();

  /// Messages received while the app is in the foreground.
  Stream<PushMessage> get messages;

  /// Messages the learner tapped while the app was in the background.
  Stream<PushMessage> get opened;

  void dispose();
}
