import 'package:flutter/foundation.dart';

import '../../core/di/app_dependencies.dart';
import '../course/python_course_content.dart';
import 'leaderboard_client.dart';
import 'leaderboard_models.dart';

/// Keeps this learner's leaderboard row current.
///
/// Local progress is the source of truth (the app works offline), so every push
/// sends the totals rather than an increment: finishing a step while offline and
/// then opening the leaderboard publishes the right number, and a failed push is
/// harmless because the next one carries the same figures.
class LeaderboardSync {
  static LeaderboardClient clientFor(AppDependencies deps) =>
      LeaderboardClient(baseUrl: deps.config.leaderboardUrl);

  static LeaderboardSnapshot snapshotFor(AppDependencies deps) =>
      LeaderboardSnapshot.fromProgress(
        course: pythonKickstartCourse,
        completed: deps.courseProgress.completedSteps(deps.learnerRef),
        scores: deps.courseProgress.scores(deps.learnerRef),
      );

  /// Best effort: a ranking update must never interrupt a lesson or a screen.
  static Future<void> push({
    required AppDependencies deps,
    required String name,
    String? avatarDataUrl,
  }) async {
    try {
      final client = clientFor(deps);
      if (!client.configured) return;
      await client.submit(
        ref: deps.learnerRef,
        name: name,
        snapshot: snapshotFor(deps),
        avatarDataUrl: avatarDataUrl,
      );
    } catch (e) {
      debugPrint('Leaderboard sync skipped: $e');
    }
  }
}
