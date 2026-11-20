import 'dart:convert';

import '../../features/auth/cloud_auth.dart';
import 'course_progress_repository.dart';

/// Synchronizes only progress metadata through the website's authenticated
/// Neon API. Drafts and submitted lesson source code are never sent here.
class CourseProgressSyncService {
  CourseProgressSyncService({
    required this.baseUrl,
    required this.auth,
    required this.repository,
  });

  final String baseUrl;
  final CloudAuth auth;
  final CourseProgressRepository repository;
  bool _running = false;

  Future<bool> sync(String learner) async {
    if (_running || baseUrl.trim().isEmpty) return false;
    _running = true;
    try {
      final response = await auth.requestSharedApi('GET', '/api/progress');
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body);
      if (payload is! Map) return false;
      await repository.mergeRemoteProgress(
        learner: learner,
        events: payload['events'] is List ? payload['events'] as List : const [],
        summaries: payload['progress'] is List
            ? payload['progress'] as List
            : const [],
      );

      while (true) {
        final batch = repository.pendingEvents(
          learner,
          limit: CourseProgressRepository.maxSyncBatch,
        );
        if (batch.isEmpty) break;
        final posted = await auth.requestSharedApi(
          'POST',
          '/api/progress',
          body: <String, Object?>{'events': batch},
        );
        if (posted.statusCode < 200 || posted.statusCode >= 300) return false;
        await repository.markEventsSynced(
          learner,
          batch.map((event) => event['eventId'] as String),
        );
      }
      return true;
    } catch (_) {
      // Network, auth, and malformed-response failures preserve local progress
      // and the durable outbox for the next retry.
      return false;
    } finally {
      _running = false;
    }
  }
}
