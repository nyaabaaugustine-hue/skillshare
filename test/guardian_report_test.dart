import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/course_progress_repository.dart';
import 'package:skillbridge_python_lab/features/course/guardian_report.dart';

CourseStep _step(String id, CourseStepKind kind) => CourseStep(
      id: id,
      title: 'Step $id',
      subtitle: '',
      kind: kind,
      xp: 10,
      blocks: const <CourseBlock>[],
    );

AttemptRecord _try(String id, int score, int minute) => AttemptRecord(
      stepId: id,
      score: score,
      at: DateTime(2026, 10, 19, 9, minute),
    );

void main() {
  final course = CourseUnit(
    id: 'u1',
    sectionLabel: 'UNIT 1',
    title: 'Unit',
    subtitle: '',
    steps: <CourseStep>[
      _step('a', CourseStepKind.reading),
      _step('b', CourseStepKind.quiz),
      _step('c', CourseStepKind.coding),
      _step('d', CourseStepKind.assessment),
    ],
  );

  group('ResultBand', () {
    test('uses the 90 / 70 boundaries', () {
      expect(ResultBand.of(100), ResultBand.mastered);
      expect(ResultBand.of(90), ResultBand.mastered);
      expect(ResultBand.of(89), ResultBand.developing);
      expect(ResultBand.of(70), ResultBand.developing);
      expect(ResultBand.of(69), ResultBand.needsSupport);
      expect(ResultBand.of(0), ResultBand.needsSupport);
    });
  });

  group('GuardianReport', () {
    test('is empty before anything is attempted', () {
      final report = GuardianReport.build(course: course, history: const []);
      expect(report.isEmpty, isTrue);
      expect(report.averageScore, isNull);
      expect(report.totalRetries, 0);
      expect(report.weakPoints, isEmpty);
      expect(report.retried, isEmpty);
    });

    test('counts retries and tracks first vs latest score', () {
      final report = GuardianReport.build(
        course: course,
        history: [
          _try('b', 60, 1),
          _try('b', 80, 2),
          _try('b', 100, 3),
          _try('a', 100, 4),
        ],
      );
      final b = report.results.firstWhere((r) => r.step.id == 'b');
      expect(b.attempts, 3);
      expect(b.retries, 2);
      expect(b.firstScore, 60);
      expect(b.latestScore, 100);
      expect(b.improved, isTrue);
      expect(report.totalRetries, 2);
      expect(report.retried.single.step.id, 'b');
    });

    test('a retried step that is now mastered is not a weak point', () {
      final report = GuardianReport.build(
        course: course,
        history: [_try('b', 60, 1), _try('b', 95, 2)],
      );
      expect(report.weakPoints, isEmpty);
    });

    test('weak points are the not-yet-mastered steps, weakest first', () {
      final report = GuardianReport.build(
        course: course,
        history: [
          _try('a', 100, 1),
          _try('b', 80, 2),
          _try('c', 55, 3),
          _try('d', 90, 4),
        ],
      );
      expect(report.weakPoints.map((r) => r.step.id), ['c', 'b']);
    });

    test('average uses each step\'s latest score and follows course order', () {
      final report = GuardianReport.build(
        course: course,
        history: [
          _try('c', 70, 1),
          _try('a', 100, 2),
          _try('a', 90, 3),
        ],
      );
      expect(report.results.map((r) => r.step.id), ['a', 'c']);
      expect(report.averageScore, 80); // (90 + 70) / 2
    });

    test('ignores attempts for steps that are not in the course', () {
      final report = GuardianReport.build(
        course: course,
        history: [_try('zzz', 10, 1), _try('a', 100, 2)],
      );
      expect(report.attemptedCount, 1);
    });
  });
}
