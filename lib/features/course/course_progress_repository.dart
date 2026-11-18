import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// One finished try at a course step. A step with several records has been
/// retried; the order is chronological.
class AttemptRecord {
  const AttemptRecord({
    required this.stepId,
    required this.score,
    required this.at,
    this.eventId = '',
  });

  final String stepId;
  /// 0-100.
  final int score;
  final DateTime at;
  final String eventId;
}

/// Durable, learner-scoped local progress with an idempotent cloud outbox.
/// Only step IDs, scores, event IDs and timestamps are queued; drafts and
/// submitted lesson code are never part of the sync contract.
class CourseProgressRepository {
  CourseProgressRepository(this._prefs);

  final SharedPreferences _prefs;
  void Function(String learner)? onProgressChanged;

  static Future<CourseProgressRepository> create() async =>
      CourseProgressRepository(await SharedPreferences.getInstance());

  static const String _completedPrefix = 'course_completed_';
  static const String _scoresPrefix = 'course_scores_';
  static const String _activityPrefix = 'course_activity_';
  static const String _historyPrefix = 'course_history_';
  static const String _outboxPrefix = 'course_outbox_';
  static const int _maxHistory = 500;
  static const int maxSyncBatch = 100;

  String _completedKey(String learner) => '$_completedPrefix$learner';
  String _scoresKey(String learner) => '$_scoresPrefix$learner';
  String _activityKey(String learner) => '$_activityPrefix$learner';
  String _historyKey(String learner) => '$_historyPrefix$learner';
  String _outboxKey(String learner) => '$_outboxPrefix$learner';

  List<AttemptRecord> history(String learner) {
    final raw = _prefs.getStringList(_historyKey(learner)) ?? const <String>[];
    final records = <AttemptRecord>[];
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length < 3) continue;
      final score = int.tryParse(parts[1]);
      final at = DateTime.tryParse(parts[2]);
      if (score == null || at == null) continue;
      records.add(AttemptRecord(
        stepId: parts[0],
        score: score,
        at: at,
        eventId: parts.length > 3 ? parts[3] : '',
      ));
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
      if (split.length == 2) result[split[0]] = int.tryParse(split[1]) ?? 0;
    }
    return result;
  }

  List<DateTime> activityDates(String learner) {
    final raw = _prefs.getStringList(_activityKey(learner)) ?? const <String>[];
    return raw.map(DateTime.tryParse).whereType<DateTime>().toList();
  }

  List<Map<String, Object?>> pendingEvents(String learner, {int limit = maxSyncBatch}) {
    final raw = _prefs.getStringList(_outboxKey(learner)) ?? const <String>[];
    final events = <Map<String, Object?>>[];
    for (final value in raw) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) events.add(Map<String, Object?>.from(decoded));
      } catch (_) {
        // Ignore a corrupt single row; keep other queued events available.
      }
      if (events.length >= limit) break;
    }
    return events;
  }

  Future<void> markEventsSynced(String learner, Iterable<String> eventIds) async {
    final ids = eventIds.toSet();
    if (ids.isEmpty) return;
    final current = _prefs.getStringList(_outboxKey(learner)) ?? const <String>[];
    final kept = current.where((value) {
      try {
        final decoded = jsonDecode(value);
        return decoded is! Map || !ids.contains(decoded['eventId']);
      } catch (_) {
        return true;
      }
    }).toList();
    await _prefs.setStringList(_outboxKey(learner), kept);
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

    final eventId = const Uuid().v4();
    final at = DateTime.now().toUtc();
    final record = AttemptRecord(
      stepId: stepId,
      score: score,
      at: at,
      eventId: eventId,
    );
    final log = <String>[
      ...(_prefs.getStringList(_historyKey(learner)) ?? const <String>[]),
      _serialize(record),
    ];
    await _prefs.setStringList(
      _historyKey(learner),
      log.length > _maxHistory ? log.sublist(log.length - _maxHistory) : log,
    );

    final outbox = _prefs.getStringList(_outboxKey(learner)) ?? <String>[];
    outbox.add(jsonEncode(<String, Object?>{
      'eventId': eventId,
      'stepId': stepId,
      'score': score,
    }));
    await _prefs.setStringList(_outboxKey(learner), outbox);
    onProgressChanged?.call(learner);
  }

  /// Merge server-generated events and best-score summaries into the local
  /// view. Existing outbox IDs are kept until the POST is acknowledged.
  Future<void> mergeRemoteProgress({
    required String learner,
    required List<dynamic> events,
    required List<dynamic> summaries,
  }) async {
    final legacy = history(learner)
        .where((record) => record.eventId.isEmpty)
        .toList();
    final byId = <String, AttemptRecord>{
      for (final record in history(learner))
        if (record.eventId.isNotEmpty) record.eventId: record,
    };
    for (final value in events) {
      if (value is! Map) continue;
      final eventId = value['eventId'];
      final stepId = value['stepId'];
      final score = value['score'];
      final receivedAt = DateTime.tryParse('${value['receivedAt'] ?? ''}');
      if (eventId is! String ||
          stepId is! String ||
          score is! num ||
          receivedAt == null ||
          eventId.isEmpty) {
        continue;
      }
      byId.putIfAbsent(
        eventId,
        () => AttemptRecord(
          eventId: eventId,
          stepId: stepId,
          score: score.toInt(),
          at: receivedAt.toLocal(),
        ),
      );
    }

    final merged = <AttemptRecord>[...legacy, ...byId.values]
      ..sort((a, b) => a.at.compareTo(b.at));
    final trimmed = merged.length > _maxHistory
        ? merged.sublist(merged.length - _maxHistory)
        : merged;
    await _prefs.setStringList(
      _historyKey(learner),
      trimmed.map(_serialize).toList(),
    );

    final completed = completedSteps(learner);
    final best = scores(learner);
    for (final record in trimmed) {
      completed.add(record.stepId);
      final previous = best[record.stepId] ?? 0;
      if (record.score > previous) best[record.stepId] = record.score;
    }
    for (final value in summaries) {
      if (value is! Map) continue;
      final stepId = value['stepId'];
      final bestScore = value['bestScore'];
      if (stepId is! String || bestScore is! num) continue;
      completed.add(stepId);
      final previous = best[stepId] ?? 0;
      if (bestScore > previous) best[stepId] = bestScore.toInt();
    }
    await _prefs.setStringList(_completedKey(learner), completed.toList());
    await _prefs.setStringList(
      _scoresKey(learner),
      best.entries.map((entry) => '${entry.key}=${entry.value}').toList(),
    );
  }

  String _serialize(AttemptRecord record) =>
      '${record.stepId}|${record.score}|${record.at.toIso8601String()}|${record.eventId}';

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
    await _prefs.remove(_outboxKey(learner));
  }
}
