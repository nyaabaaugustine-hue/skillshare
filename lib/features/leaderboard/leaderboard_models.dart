import 'package:flutter/foundation.dart';

import '../course/course_models.dart';
import '../course/practice_checks.dart';

/// One ranked learner, exactly as the server returns it.
///
/// The same shape is produced for a phone learner and for a browser learner, so
/// both clients render one shared ranking.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.rank,
    required this.name,
    required this.hasAvatar,
    required this.stepsCompleted,
    required this.practicesCompleted,
    required this.score,
    required this.average,
    required this.source,
  });

  final String id;
  final int rank;
  final String name;
  final bool hasAvatar;
  final int stepsCompleted;
  final int practicesCompleted;
  final int score;
  final int average;

  /// `app` for an Android learner, `web` for a browser account.
  final String source;

  bool get fromApp => source == 'app';

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value, [int fallback = 0]) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse('${value ?? ''}') ?? fallback;
    }

    return LeaderboardEntry(
      id: '${json['id'] ?? ''}',
      rank: asInt(json['rank'], 0),
      name: '${json['name'] ?? 'Learner'}',
      hasAvatar: json['hasAvatar'] == true,
      stepsCompleted: asInt(json['stepsCompleted']),
      practicesCompleted: asInt(json['practicesCompleted']),
      score: asInt(json['score']),
      average: asInt(json['average']),
      source: '${json['source'] ?? 'app'}',
    );
  }
}

/// What this device should send: how much was finished and how well.
@immutable
class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.stepsCompleted,
    required this.practicesCompleted,
    required this.scoreTotal,
  });

  final int stepsCompleted;
  final int practicesCompleted;
  final int scoreTotal;

  static const LeaderboardSnapshot empty = LeaderboardSnapshot(
    stepsCompleted: 0,
    practicesCompleted: 0,
    scoreTotal: 0,
  );

  /// Reads local progress: only finished steps count, and a step contributes the
  /// best score it was given. Practice steps are the hands-on blocks, so the
  /// "courses and practice" split the leaderboard shows is real.
  factory LeaderboardSnapshot.fromProgress({
    required CourseUnit course,
    required Set<String> completed,
    required Map<String, int> scores,
  }) {
    var steps = 0;
    var practices = 0;
    var total = 0;
    for (final step in course.steps) {
      if (!completed.contains(step.id)) continue;
      steps += 1;
      if (practiceBlockOf(step) != null) practices += 1;
      total += scores[step.id] ?? 0;
    }
    return LeaderboardSnapshot(
      stepsCompleted: steps,
      practicesCompleted: practices,
      scoreTotal: total,
    );
  }
}

/// A leaderboard problem that is safe to show to a learner.
class LeaderboardException implements Exception {
  const LeaderboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
