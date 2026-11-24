import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import 'announcement.dart';

/// The subset of `CloudAuth.requestSharedApi` the inbox needs.
typedef SharedApiCaller = Future<http.Response> Function(
  String method,
  String path, {
  Map<String, Object?>? body,
});

class AnnouncementPage {
  const AnnouncementPage({required this.items, required this.nextCursor});

  final List<Announcement> items;
  final String? nextCursor;
}

abstract interface class AnnouncementRepository {
  Future<AnnouncementPage> list({int limit = 20, String? cursor});

  Future<void> markRead(String id);
}

/// Authenticated website API implementation.
class HttpAnnouncementRepository implements AnnouncementRepository {
  HttpAnnouncementRepository({required this.call});

  final SharedApiCaller call;

  @override
  Future<AnnouncementPage> list({int limit = 20, String? cursor}) async {
    final safeLimit = limit.clamp(1, 100);
    final query = <String, String>{
      'limit': '$safeLimit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = Uri.parse('/api/announcements').replace(queryParameters: query);
    final payload = _json(await call('GET', uri.toString()));
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(Announcement.fromJson)
              .toList()
        : <Announcement>[];
    return AnnouncementPage(
      items: items,
      nextCursor: payload['nextCursor'] as String?,
    );
  }

  @override
  Future<void> markRead(String id) async {
    _json(await call('POST', '/api/announcements/$id/read'));
  }

  Map<String, dynamic> _json(http.Response response) {
    if (response.statusCode == 401) throw const AuthenticationException();
    if (response.statusCode == 404) {
      throw const NotFoundException(
        'That announcement is no longer available.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkException(
        'Announcements are temporarily unavailable. Please try again.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } catch (error) {
      throw NetworkException(
        'Announcements could not be read right now.',
        cause: error,
      );
    }
  }
}
