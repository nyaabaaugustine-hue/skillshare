import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/features/python_runtime/execution_result.dart';

ExecutionResult _ok(String stdout) =>
    ExecutionResult(status: ExecutionStatus.success, stdout: stdout);

CourseStep _step(String id) =>
    pythonKickstartCourse.steps.firstWhere((s) => s.id == id);

void main() {
  group('fix-the-bug exercises', () {
    test('both debugging steps are in the course', () {
      expect(_step('py-fix-bug-loop').kind, CourseStepKind.coding);
      expect(_step('py-fix-bug-concat').kind, CourseStepKind.coding);
    });

    test('the endless-loop starter fails as shipped', () {
      final block = practiceBlockOf(_step('py-fix-bug-loop'))!;
      // The runtime stops a loop like this and reports a timeout.
      const timedOut = ExecutionResult(
        status: ExecutionStatus.timeout,
        stdout: '1\n1\n1\n',
      );
      final verdict = evaluatePractice(
        block: block,
        code: block.starterCode,
        result: timedOut,
      );
      expect(verdict.passed, isFalse);
      expect(
        verdict.checks.any((c) => c.label.contains('finishes in time')),
        isTrue,
      );
    });

    test('the endless loop passes once the counter advances', () {
      final block = practiceBlockOf(_step('py-fix-bug-loop'))!;
      final verdict = evaluatePractice(
        block: block,
        code:
            'count = 1\n'
            'while count <= 3:\n'
            '    print(count)\n'
            '    count += 1\n',
        result: _ok('1\n2\n3\n'),
      );
      expect(verdict.passed, isTrue);
    });

    test('the text-total starter fails with the wrong output', () {
      final block = practiceBlockOf(_step('py-fix-bug-concat'))!;
      final verdict = evaluatePractice(
        block: block,
        code: block.starterCode,
        result: _ok('Total: 123\n'),
      );
      expect(verdict.passed, isFalse);
      expect(verdict.diff, isNotEmpty, reason: 'expected vs actual is shown');
    });

    test('multiplying fixes it, typing the answer does not', () {
      final block = practiceBlockOf(_step('py-fix-bug-concat'))!;

      final fixed = evaluatePractice(
        block: block,
        code:
            'price = 12\n'
            'quantity = 3\n'
            'total = price * quantity\n'
            'print("Total:", total)\n',
        result: _ok('Total: 36\n'),
      );
      expect(fixed.passed, isTrue);

      final typed = evaluatePractice(
        block: block,
        code: 'price = 12\nquantity = 3\ntotal = 36\nprint("Total:", total)\n',
        result: _ok('Total: 36\n'),
      );
      expect(typed.passed, isFalse);
    });
  });
}
