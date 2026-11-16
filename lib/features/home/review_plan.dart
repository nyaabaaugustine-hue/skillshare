import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/course_progress_repository.dart';

/// One entry in the short daily review shown on the course path.
class ReviewItem {
  const ReviewItem({required this.step, required this.reason});

  final CourseStep step;

  /// Why this step is here, in the learner's words ("Last try: 60%").
  final String reason;
}

/// Picks a short review for today: the weakest finished steps first, then the
/// next unfinished step so the card always gives the learner somewhere to go.
///
/// Only scores the learner actually earned are used — nothing is invented and a
/// step never appears twice. The list is deliberately capped: three steps is
/// about three minutes, which is the habit the review is meant to build.
List<ReviewItem> buildReviewPlan({
  required CourseUnit course,
  required List<AttemptRecord> history,
  required Set<String> completed,
  int masteredAt = 90,
  int limit = 3,
}) {
  // A review card on day zero is noise: "review" only makes sense once the
  // learner has finished something to review.
  if (limit <= 0 || completed.isEmpty) return const <ReviewItem>[];

  final latest = <String, int>{};
  for (final record in history) {
    latest[record.stepId] = record.score;
  }

  final weak =
      course.steps
          .where(
            (step) =>
                completed.contains(step.id) &&
                (latest[step.id] ?? 0) < masteredAt,
          )
          .toList()
        ..sort((a, b) => (latest[a.id] ?? 0).compareTo(latest[b.id] ?? 0));

  final items = <ReviewItem>[
    for (final step in weak.take(limit))
      ReviewItem(
        step: step,
        reason: latest[step.id] == null
            ? 'Finished, not scored yet'
            : 'Last try: ${latest[step.id]}%',
      ),
  ];

  if (items.length < limit) {
    for (final step in course.steps) {
      if (completed.contains(step.id)) continue;
      if (items.any((item) => item.step.id == step.id)) continue;
      items.add(ReviewItem(step: step, reason: 'Next up'));
      break;
    }
  }

  return items;
}
