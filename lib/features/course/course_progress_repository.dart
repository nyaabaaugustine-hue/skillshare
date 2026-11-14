import 'package:shared_preferences/shared_preferences.dart';

/// One finished try at a course step. A step with several records has been
/// retried; the order is chronological.
class AttemptRecord {
  const AttemptRecord({
    required this.stepId,
    required this.score,
    required this.at,
  });

  final String stepId;

  /// 0-100.
  final int score;
  final DateTime at;
}

/// Durable, learner-scoped store for course progress.
///
/// Progress is keyed by the learner reference the app already authenticates
/// with, so the same device can hold progress for more than one learner. Like
/// [SettingsRepository] it rides on `SharedPreferences`, which is the app's
/// existing local backend surface.
class CourseProgressRepository {
  CourseProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static Future<CourseProgressRepository> create() async =>
      CourseProgressRepository(await SharedPreferences.getInstance());

  static const String _completedPrefix = 'course_completed_';
  static const String _scoresPrefix = 'course_scores_';
  static const String _activityPrefix = 'course_activity_';
  static const String _historyPrefix = 'course_history_';
  static const int _maxHistory = 500;

  String _completedKey(String learner) => '$_completedPrefix$learner';
  String _scoresKey(String learner) => '$_scoresPrefix$learner';
  String _activityKey(String learner) => '$_activityPrefix$learner';
  String _historyKey(String learner) => '$_historyPrefix$learner';

  /// Every finished attempt for [learner], oldest first. This is what lets a
  /// guardian see retries and how a score changed between tries.
  List<AttemptRecord> history(String learner) {
    final raw = _prefs.getStringList(_historyKey(learner)) ?? const <String>[];
    final records = <AttemptRecord>[];
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length != 3) continue;
      final score = int.tryParse(parts[1]);
      final at = DateTime.tryParse(parts[2]);
      if (score == null || at == null) continue;
      records.add(AttemptRecord(stepId: parts[0], score: score, at: at));
    }
    return records;
  }

  Set<String> completedSteps(String learner) =>
      _prefs.getStringList(_completedKey(learner))?.toSet() ?? <String>{};

  Map<String, int> scores(String learner) {
    final raw = _prefs.getStringList(_scoresKey(learner)) ?? const <String>[];
    final result = <String, int>{};
    for (final entry in raw) {
      final split = entry.split('=');
      if (split.length == 2) {
        result[split[0]] = int.tryParse(split[1]) ?? 0;
      }
    }
    return result;
  }

  List<DateTime> activityDates(String learner) {
    final raw = _prefs.getStringList(_activityKey(learner)) ?? const <String>[];
    return raw.map(DateTime.tryParse).whereType<DateTime>().toList();
  }

  Future<void> markCompleted({
    required String learner,
    required String stepId,
    required int score,
  }) async {
    final completed = completedSteps(learner)..add(stepId);
    await _prefs.setStringList(_completedKey(learner), completed.toList());

    final current = scores(learner)..[stepId] = score;
    await _prefs.setStringList(
      _scoresKey(learner),
      current.entries.map((e) => '${e.key}=${e.value}').toList(),
    );

    // Append to the attempt log (bounded so it can never grow without limit).
    final log = _prefs.getStringList(_historyKey(learner)) ?? <String>[];
    final next = <String>[
      ...log,
      '$stepId|$score|${DateTime.now().toIso8601String()}',
    ];
    final trimmed = next.length > _maxHistory
        ? next.sublist(next.length - _maxHistory)
        : next;
    await _prefs.setStringList(_historyKey(learner), trimmed);
  }

  /// Records that the learner was active today, so a streak can be derived.
  Future<void> recordActivity(String learner) async {
    final key = _activityKey(learner);
    final existing = _prefs.getStringList(key) ?? <String>[];
    final now = DateTime.now();
    final stamp = DateTime(now.year, now.month, now.day).toIso8601String();
    if (existing.contains(stamp)) return;
    await _prefs.setStringList(key, [...existing, stamp]);
  }

  Future<void> reset(String learner) async {
    await _prefs.remove(_completedKey(learner));
    await _prefs.remove(_scoresKey(learner));
    await _prefs.remove(_activityKey(learner));
    await _prefs.remove(_historyKey(learner));
  }
}
