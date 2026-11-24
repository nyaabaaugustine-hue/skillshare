import 'package:firebase_messaging/firebase_messaging.dart';

/// The small, platform-independent shape shared by FCM callbacks and the inbox.
class PushMessage {
  const PushMessage({required this.id, this.title, this.body});

  final String id;
  final String? title;
  final String? body;

  /// Parses an FCM data payload.
  ///
  /// Returns `null` for unrelated messages or malformed announcements so a
  /// stray data message can never crash a background isolate or the UI.
  static PushMessage? fromData(Map<String, Object?> data) {
    if (data['type'] != 'announcement') return null;
    final id = data['announcementId']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final title = data['title']?.toString().trim();
    final body = data['body']?.toString().trim();
    return PushMessage(
      id: id,
      title: title == null || title.isEmpty ? null : title,
      body: body == null || body.isEmpty ? null : body,
    );
  }

  static PushMessage? fromRemoteMessage(RemoteMessage message) =>
      fromData(message.data);
}
