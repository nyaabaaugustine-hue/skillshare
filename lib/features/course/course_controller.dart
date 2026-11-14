import 'package:flutter/foundation.dart';

import 'course_models.dart';
import 'course_progress_repository.dart';

/// Visual state of a node on the course path.
enum CourseStepStatus {
  /// Prerequisites are not met; the node cannot be opened.
  locked,

  /// Unlocked and ripe, but not the learner's current focus. Reachable when
  /// progress is resumed out of order (for example after a restored backup).
  available,

  /// The next step the learner should take. Highlighted on the path.
  current,

  /// Finished. Revisitable at any time.
  completed,
}

/// Owns the course path state: what is completed, what is unlocked, the
/// learner's streak and the display totals for the header.
class CourseController extends ChangeNotifier {
  CourseController({
    required this.course,
    required this.repository,
    required this.learnerRef,
  });

  final CourseUnit course;
  final CourseProgressRepository repository;
  final String learnerRef;

  bool _loading = true;
  String? _error;
  final Set<String> _completed = <String>{};
  final Map<String, int> _scores = <String, int>{};
  List<DateTime> _activity = const <DateTime>[];
  List<AttemptRecord> _history = const <AttemptRecord>[];

  bool get isLoading => _loading;
  String? get error => _error;

  /// Every finished attempt, oldest first (used by the guardian report).
  List<AttemptRecord> get history => List<AttemptRecord>.unmodifiable(_history);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _completed
        ..clear()
        ..addAll(repository.completedSteps(learnerRef));
      _scores
        ..clear()
        ..addAll(repository.scores(learnerRef));
      _activity = repository.activityDates(learnerRef);
      _history = repository.history(learnerRef);
    } catch (_) {
      _error = 'Could not load your course progress.';
    }
    _loading = false;
    notifyListeners();
  }

  bool isCompleted(String stepId) => _completed.contains(stepId);

  int scoreFor(String stepId) => _scores[stepId] ?? 0;

  int get totalSteps => course.steps.length;

  int get completedCount =>
      course.steps.where((s) => _completed.contains(s.id)).length;

  double get progress => totalSteps == 0 ? 0 : completedCount / totalSteps;

  /// Index of the step the learner should do next, or -1 when the course is
  /// complete.
  int get currentIndex {
    for (var i = 0; i < course.steps.length; i++) {
      if (!_completed.contains(course.steps[i].id)) return i;
    }
    return -1;
  }

  CourseStep? get nextStep {
    final index = currentIndex;
    return index == -1 ? null : course.steps[index];
  }

  bool _isUnlocked(int index) {
    if (index <= 0) return true;
    return _completed.contains(course.steps[index - 1].id);
  }

  CourseStepStatus statusFor(int index) {
    if (index < 0 || index >= course.steps.length) {
      return CourseStepStatus.locked;
    }
    if (_completed.contains(course.steps[index].id)) {
      return CourseStepStatus.completed;
    }
    if (!_isUnlocked(index)) return CourseStepStatus.locked;
    return index == currentIndex
        ? CourseStepStatus.current
        : CourseStepStatus.available;
  }

  int get xpEarned => course.steps
      .where((s) => _completed.contains(s.id))
      .fold(0, (sum, s) => sum + s.xp);

  int get coinsEarned => completedCount * 25;

  /// Consecutive days of activity ending today (or yesterday, so a streak is
  /// not lost until a day is missed).
  int get streak {
    if (_activity.isEmpty) return 0;
    final days = _activity.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Marks a step complete and persists it. Safe to call for a step that is
  /// already done (for example when replaying a completed lesson).
  Future<void> markCompleted(CourseStep step, {int score = 0}) async {
    _completed.add(step.id);
    _scores[step.id] = score < 0 ? 0 : score;
    notifyListeners();
    await repository.markCompleted(
      learner: learnerRef,
      stepId: step.id,
      score: _scores[step.id]!,
    );
    await repository.recordActivity(learnerRef);
    _activity = repository.activityDates(learnerRef);
    _history = repository.history(learnerRef);
    notifyListeners();
  }
}
