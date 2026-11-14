import 'course_models.dart';
import 'course_progress_repository.dart';

/// How a latest score reads to a parent.
enum ResultBand {
  /// 90% and above.
  mastered,

  /// 70-89%.
  developing,

  /// Below 70%.
  needsSupport;

  static ResultBand of(int score) {
    if (score >= masteredAt) return ResultBand.mastered;
    if (score >= developingAt) return ResultBand.developing;
    return ResultBand.needsSupport;
  }

  static const int masteredAt = 90;
  static const int developingAt = 70;

  String get label => switch (this) {
        ResultBand.mastered => 'Mastered',
        ResultBand.developing => 'Developing',
        ResultBand.needsSupport => 'Needs support',
      };
}

/// How one course step has gone for the learner: every score, oldest first.
class StepResult {
  const StepResult({required this.step, required this.scores})
      : assert(scores.length > 0);

  final CourseStep step;

  /// One entry per finished attempt, chronological.
  final List<int> scores;

  int get attempts => scores.length;

  /// Tries beyond the first.
  int get retries => attempts - 1;

  int get firstScore => scores.first;
  int get latestScore => scores.last;

  ResultBand get band => ResultBand.of(latestScore);

  /// A weak point is anything not yet mastered on the latest try.
  bool get isWeak => latestScore < ResultBand.masteredAt;

  bool get improved => attempts > 1 && latestScore > firstScore;

  /// Short, parent-friendly suggestion for what to revisit.
  String get advice => switch (step.kind) {
        CourseStepKind.quiz =>
          'Re-read the lesson together, then retry the quiz.',
        CourseStepKind.assessment =>
          'Go over the questions that were missed, then run the review again.',
        CourseStepKind.coding =>
          'Practise writing and running this code a little each day.',
        CourseStepKind.project =>
          'Check the project checklist and finish any missing parts.',
        CourseStepKind.prompt =>
          'Practise writing clearer, more specific prompts.',
        CourseStepKind.api =>
          'Review how requests, endpoints and fields fit together.',
        _ => 'Revisit this lesson and try it again.',
      };
}

/// Everything a parent / guardian sees: scores, weak points and retries.
/// Nothing here is editable, and no lesson content or code is exposed.
class GuardianReport {
  const GuardianReport._({
    required this.results,
    required this.totalSteps,
  });

  /// Builds the report for [course] from the learner's attempt [history].
  factory GuardianReport.build({
    required CourseUnit course,
    required List<AttemptRecord> history,
  }) {
    final byStep = <String, List<int>>{};
    for (final record in history) {
      byStep.putIfAbsent(record.stepId, () => <int>[]).add(record.score);
    }
    final results = <StepResult>[
      for (final step in course.steps)
        if (byStep[step.id] != null)
          StepResult(step: step, scores: byStep[step.id]!),
    ];
    return GuardianReport._(results: results, totalSteps: course.steps.length);
  }

  /// Attempted steps, in course order.
  final List<StepResult> results;
  final int totalSteps;

  bool get isEmpty => results.isEmpty;

  int get attemptedCount => results.length;

  /// Mean of each step's latest score, or `null` before anything is attempted.
  int? get averageScore {
    if (results.isEmpty) return null;
    final sum = results.fold<int>(0, (a, r) => a + r.latestScore);
    return (sum / results.length).round();
  }

  int get totalRetries => results.fold<int>(0, (a, r) => a + r.retries);

  /// Steps not yet mastered, weakest first.
  List<StepResult> get weakPoints =>
      results.where((r) => r.isWeak).toList()
        ..sort((a, b) => a.latestScore.compareTo(b.latestScore));

  /// Steps tried more than once, most retries first.
  List<StepResult> get retried =>
      results.where((r) => r.retries > 0).toList()
        ..sort((a, b) => b.retries.compareTo(a.retries));
}
