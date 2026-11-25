import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/platform.dart';
import '../../core/notifications/reminder_service.dart';
import 'push_gateway.dart';
import 'push_message.dart';

/// Firebase Cloud Messaging adapter.
///
/// Desktop builds have no Firebase messaging plugin; they get a no-op service
/// rather than a runtime crash. Web needs a VAPID key, supplied by
/// `--dart-define=SB_FCM_VAPID_KEY=...`; without it token registration is
/// skipped and the in-app inbox still works.
class PushService implements PushGateway {
  PushService({FirebaseMessaging? messaging, required this._reminders})
    : _messaging = (kIsWeb || isAndroid || isIOS)
          ? messaging ?? FirebaseMessaging.instance
          : null;

  final FirebaseMessaging? _messaging;
  final ReminderService _reminders;

  final StreamController<PushMessage> _messages =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _opened =
      StreamController<PushMessage>.broadcast();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _localOpenedSub;
  String? _vapidKey;
  bool _initialized = false;

  @override
  bool get supported => kIsWeb || isAndroid || isIOS;

  @override
  Future<void> initialize({String? vapidKey}) async {
    final trimmed = vapidKey?.trim();
    _vapidKey = trimmed == null || trimmed.isEmpty ? null : trimmed;
    final messaging = _messaging;
    if (!supported || messaging == null || _initialized) return;
    _initialized = true;

    _messageSub ??= FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });
    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final push = PushMessage.fromRemoteMessage(message);
      if (push != null) _opened.add(push);
    });
    // Foreground announcements are shown by the local-notification plugin, so
    // their taps arrive here rather than through FCM's onMessageOpenedApp.
    _localOpenedSub ??= _reminders.opened.listen((id) {
      if (id.isNotEmpty) _opened.add(PushMessage(id: id));
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final push = PushMessage.fromRemoteMessage(message);
    if (push == null) return;

    // Foreground FCM does not show a system notification by itself. Reuse the
    // existing local-notification channel so the learner still gets a heads-up.
    unawaited(
      _reminders.showHeadsUp(
        id: 2000 + (push.id.hashCode.abs() % 100000),
        title: push.title ?? 'New announcement',
        body: push.body ?? 'You have a new message from SkillBridge Academy.',
        payload: push.id,
      ),
    );
    _messages.add(push);
  }

  @override
  Stream<PushMessage> get messages => _messages.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (!supported || messaging == null) return false;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (error) {
      debugPrint('FCM permission request failed: $error');
      return false;
    }
  }

  @override
  Future<String?> token() async {
    final messaging = _messaging;
    if (!supported || messaging == null) return null;
    try {
      if (kIsWeb) {
        final vapid = _vapidKey;
        if (vapid == null) {
          debugPrint(
            'Web push skipped: set SB_FCM_VAPID_KEY with --dart-define to enable it.',
          );
          return null;
        }
        // The web app is served from /app/, so Firebase's default root worker
        // (/firebase-messaging-sw.js) does not exist here. Register the worker
        // next to the app instead; its scope is /app/ and it also caches the
        // app shell for offline use.
        final workerPath = Uri.base.resolve('firebase-messaging-sw.js').path;
        // ignore: deprecated_member_use
        return await messaging.getToken(
          vapidKey: vapid,
          serviceWorkerScriptPath: workerPath,
        );
      }
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } catch (error) {
      debugPrint('Could not read the FCM token: $error');
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    final messaging = _messaging;
    if (!supported || messaging == null) return;
    try {
      // ignore: deprecated_member_use
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('Could not delete the FCM token: $error');
    }
  }

  @override
  Future<PushMessage?> initialMessage() async {
    final messaging = _messaging;
    if (!supported || messaging == null) return null;
    try {
      final message = await messaging.getInitialMessage();
      return message == null ? null : PushMessage.fromRemoteMessage(message);
    } catch (error) {
      debugPrint('Could not read the launching FCM message: $error');
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_messageSub?.cancel() ?? Future<void>.value());
    unawaited(_openedSub?.cancel() ?? Future<void>.value());
    unawaited(_localOpenedSub?.cancel() ?? Future<void>.value());
    unawaited(_messages.close());
    unawaited(_opened.close());
  }
}
