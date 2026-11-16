import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/course_progress_repository.dart';
import 'package:skillbridge_python_lab/features/home/review_plan.dart';

CourseStep _step(String id) => CourseStep(
  id: id,
  title: 'Step $id',
  subtitle: 's',
  kind: CourseStepKind.coding,
  xp: 10,
  blocks: const <CourseBlock>[],
);

CourseUnit _course() => CourseUnit(
  id: 'c',
  sectionLabel: 'S',
  title: 'Course',
  subtitle: 's',
  steps: <CourseStep>[_step('a'), _step('b'), _step('c'), _step('d')],
);

AttemptRecord _try(String id, int score) =>
    AttemptRecord(stepId: id, score: score, at: DateTime(2026, 1, 1));

void main() {
  group('buildReviewPlan', () {
    test('shows finished steps below mastery, weakest first', () {
      final plan = buildReviewPlan(
        course: _course(),
        history: <AttemptRecord>[_try('a', 80), _try('b', 55)],
        completed: <String>{'a', 'b'},
        limit: 3,
      );
      expect(plan.map((item) => item.step.id), <String>['b', 'a', 'c']);
      expect(plan.first.reason, 'Last try: 55%');
    });

    test('fills the last slot with the next unfinished step', () {
      final plan = buildReviewPlan(
        course: _course(),
        history: <AttemptRecord>[_try('a', 40)],
        completed: <String>{'a'},
      );
      expect(plan.map((item) => item.step.id), <String>['a', 'b']);
      expect(plan.last.reason, 'Next up');
    });

    test('never repeats a step or invents scores', () {
      final plan = buildReviewPlan(
        course: _course(),
        history: <AttemptRecord>[_try('a', 100), _try('a', 30)],
        completed: <String>{'a'},
      );
      expect(plan.map((item) => item.step.id).toList(), <String>['a', 'b']);
      // Only the latest score counts.
      expect(plan.first.reason, 'Last try: 30%');
    });

    test('is empty on a brand new account with no steps completed', () {
      final plan = buildReviewPlan(
        course: _course(),
        history: const <AttemptRecord>[],
        completed: const <String>{},
      );
      expect(plan, isEmpty);
    });
  });
}
