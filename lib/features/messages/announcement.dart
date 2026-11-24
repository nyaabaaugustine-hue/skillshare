import 'push_message.dart';

/// A one-way admin message stored in the shared inbox.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) throw const FormatException('Announcement has no id.');
    return Announcement(
      id: id,
      title: json['title']?.toString() ?? 'Announcement',
      body: json['body']?.toString() ?? '',
      audience: json['audience']?.toString() ?? 'all',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      readAt: json['readAt'] == null
          ? null
          : DateTime.tryParse(json['readAt']!.toString()),
    );
  }

  /// Builds an inbox row from a push payload so a tap can open the detail screen
  /// before the next inbox fetch finishes.
  factory Announcement.fromPush(PushMessage message) => Announcement(
    id: message.id,
    title: message.title ?? 'New announcement',
    body: message.body ?? 'Open to read the full message.',
    audience: 'all',
    createdAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'audience': audience,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'readAt': readAt?.toUtc().toIso8601String(),
  };

  Announcement copyWith({DateTime? readAt}) => Announcement(
    id: id,
    title: title,
    body: body,
    audience: audience,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );
}
