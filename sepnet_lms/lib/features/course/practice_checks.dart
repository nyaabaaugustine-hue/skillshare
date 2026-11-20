import 'package:skillbridge_python_lab/features/exercises/exercise.dart';
import 'package:skillbridge_python_lab/features/python_runtime/execution_result.dart';

import 'course_models.dart';

/// One line of the "did it work?" checklist shown under the console.
class PracticeCheck {
  const PracticeCheck({required this.label, required this.passed});

  final String label;
  final bool passed;
}

/// Outcome of checking a real run against a practice step's requirements.
class PracticeVerdict {
  const PracticeVerdict(this.checks, {this.diff = const []});

  final List<PracticeCheck> checks;

  /// Expected-versus-actual lines shown when the run failed. Empty when the
  /// step passed or the step has no comparable expected output.
  final List<String> diff;

  bool get passed => checks.isNotEmpty && checks.every((c) => c.passed);

  int get passedCount => checks.where((c) => c.passed).length;
}

/// Builds the "what you should have seen" comparison for a failed run.
///
/// Beginners cannot tell "wrong number" from "wrong words" by reading a
/// checklist, so the expected and real output are shown side by side, capped so
/// a runaway loop cannot flood the screen.
List<String> practiceDiff({
  required CodeBlock block,
  required ExecutionResult result,
}) {
  final printed = result.stdout.replaceAll('\r\n', '\n').trim();
  final actualLines = printed.isEmpty
      ? const <String>['(nothing)']
      : printed.split('\n').take(6).toList();
  const cap = 6;

  final expected = block.expectedOutput?.trim();
  if (expected != null && expected.isNotEmpty) {
    return <String>[
      'Expected:',
      ...expected.split('\n').take(cap),
      'You printed:',
      ...actualLines,
    ];
  }

  final missing = block.outputContains
      .where((token) => !printed.contains(token))
      .toList();
  if (missing.isEmpty) return const <String>[];
  return <String>[
    'Missing from your output:',
    ...missing.take(cap).map((token) => '  "$token"'),
    'You printed:',
    ...actualLines,
  ];
}

/// Hands the editor everything it needs to run a course practice step: what to
/// check, and what to do once the learner has genuinely passed.
class PracticeSession {
  const PracticeSession({required this.block, required this.onCompleted});

  final CodeBlock block;

  /// Called once with a 0-100 score when the learner taps "Finish step".
  final void Function(int score) onCompleted;
}

/// The practice task for [step], or `null` if the step is not hands-on coding.
///
/// Coding steps carry a [CodeBlock]. Project steps with starter code are
/// treated as a practice too, with their checklist as the requirements.
CodeBlock? practiceBlockOf(CourseStep step) {
  for (final block in step.blocks) {
    if (block is CodeBlock) return block;
  }
  for (final block in step.blocks) {
    if (block is ProjectBlock && (block.starterCode ?? '').trim().isNotEmpty) {
      return CodeBlock(
        heading: block.heading,
        brief: block.brief,
        starterCode: block.starterCode!,
        requirements: block.checklist,
      );
    }
  }
  return null;
}

/// Builds the editor's [Exercise] for a course practice. The step id is used as
/// the exercise id so the learner's draft is saved and restored per step.
Exercise exerciseForPractice(CourseStep step, CodeBlock block) => Exercise(
  id: step.id,
  title: step.title,
  instructions: block.brief,
  starterCode: block.starterCode,
  requirements: block.requirements,
  hints: block.hints,
  expectedOutput: block.expectedOutput,
);

/// Removes `# comments` so a requirement cannot be "met" by writing it in a
/// comment. Deliberately simple: a `#` inside a string literal is also cut,
/// which can only make a check stricter, never easier to pass.
String stripComments(String code) => code
    .split('\n')
    .map((line) {
      final hash = line.indexOf('#');
      return hash < 0 ? line : line.substring(0, hash);
    })
    .join('\n');

/// Normalises printed text before comparing it with an expected answer.
///
/// Python's `print` adds a newline, Windows emits `\r\n`, and a learner may
/// leave trailing spaces at the end of a line. None of those change what the
/// program produced, so none of them should fail the check — but a genuinely
/// different line still must.
String normalizePrinted(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
      .toList();
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// Checks a real [result] (and the learner's [code]) against [block].
///
/// Every check comes from what the program actually printed or what the
/// learner actually wrote, never from canned data.
PracticeVerdict evaluatePractice({
  required CodeBlock block,
  required String code,
  required ExecutionResult result,
}) {
  final checks = <PracticeCheck>[
    PracticeCheck(
      label: result.isTimeout
          ? 'Program finishes in time (it was stopped)'
          : 'Program runs without errors',
      passed: result.isSuccess,
    ),
  ];

  final output = result.stdout.replaceAll('\r\n', '\n');
  final lines = output
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  final source = stripComments(code);

  if (block.minOutputLines > 0) {
    checks.add(
      PracticeCheck(
        label: block.minOutputLines == 1
            ? 'Prints something to the output'
            : 'Prints at least ${block.minOutputLines} lines',
        passed: lines.length >= block.minOutputLines,
      ),
    );
  }

  for (final token in block.outputContains) {
    checks.add(
      PracticeCheck(
        label: 'Output shows "$token"',
        passed: output.contains(token),
      ),
    );
  }

  for (final token in block.codeContains) {
    checks.add(
      PracticeCheck(
        label: 'Your code uses $token',
        passed: source.contains(token),
      ),
    );
  }

  for (final literal in block.forbiddenLiterals) {
    checks.add(
      PracticeCheck(
        label: 'Total worked out in code, not typed as text',
        passed: !source.contains(literal),
      ),
    );
  }

  final expected = block.expectedOutput?.trim();
  if (expected != null && expected.isNotEmpty) {
    checks.add(
      PracticeCheck(
        label: 'Output matches the expected result',
        // Compare the whole printed text, normalised only for line endings and
        // trailing spaces. The old version compared the joined trimmed lines,
        // so an expected answer containing a blank line could never match.
        passed: normalizePrinted(output) == normalizePrinted(expected),
      ),
    );
  }

  final verdict = PracticeVerdict(checks);
  if (verdict.passed) return verdict;
  return PracticeVerdict(
    checks,
    diff: practiceDiff(block: block, result: result),
  );
}
