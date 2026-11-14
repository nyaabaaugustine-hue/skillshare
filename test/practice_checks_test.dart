import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/features/python_runtime/execution_result.dart';

ExecutionResult _ok(String stdout) =>
    ExecutionResult(status: ExecutionStatus.success, stdout: stdout);

void main() {
  const block = CodeBlock(
    heading: 'h',
    brief: 'b',
    starterCode: '',
    requirements: <String>[],
    outputContains: <String>['Ama', '36'],
    codeContains: <String>['print(', '*'],
    minOutputLines: 1,
  );

  group('evaluatePractice', () {
    test('passes when real output and code satisfy every check', () {
      final verdict = evaluatePractice(
        block: block,
        code: 'p = 12 * 3\nprint("Ama owes", p)',
        result: _ok('Ama owes 36\n'),
      );
      expect(verdict.passed, isTrue);
    });

    test('fails when the output is wrong, naming the missing check', () {
      final verdict = evaluatePractice(
        block: block,
        code: 'print("Ama owes", 12 * 2)',
        result: _ok('Ama owes 24\n'),
      );
      expect(verdict.passed, isFalse);
      expect(
        verdict.checks.where((c) => !c.passed).map((c) => c.label),
        contains('Output shows "36"'),
      );
    });

    test('a program that errors never passes', () {
      final verdict = evaluatePractice(
        block: block,
        code: 'print("Ama owes", 12 * 3)',
        result: const ExecutionResult(
          status: ExecutionStatus.error,
          stdout: 'Ama owes 36\n',
          stderr: 'boom',
        ),
      );
      expect(verdict.passed, isFalse);
      expect(verdict.checks.first.passed, isFalse);
    });

    test('requirements cannot be satisfied by writing them in a comment', () {
      final verdict = evaluatePractice(
        block: block,
        code: '# print(a * b)\n',
        result: _ok('Ama 36\n'),
      );
      expect(verdict.passed, isFalse);
    });

    test('too few output lines fails', () {
      const two = CodeBlock(
        heading: 'h',
        brief: 'b',
        starterCode: '',
        requirements: <String>[],
        minOutputLines: 2,
      );
      expect(
        evaluatePractice(block: two, code: 'print(1)', result: _ok('1\n'))
            .passed,
        isFalse,
      );
      expect(
        evaluatePractice(
          block: two,
          code: 'print(1)\nprint(2)',
          result: _ok('1\n2\n'),
        ).passed,
        isTrue,
      );
    });
  });

  group('course practice content', () {
    final practices = pythonKickstartCourse.steps
        .where((s) => s.kind == CourseStepKind.coding)
        .toList();

    test('there are practice steps', () {
      expect(practices, isNotEmpty);
    });

    test('no starter code already passes without the learner writing any',
        () {
      // Starter code is comments/assignments only: running it prints nothing,
      // so a learner cannot pass a practice step by just pressing Run.
      for (final step in practices) {
        final block = practiceBlockOf(step)!;
        final verdict = evaluatePractice(
          block: block,
          code: block.starterCode,
          result: _ok(''),
        );
        expect(verdict.passed, isFalse, reason: step.id);
      }
    });
  });
}
