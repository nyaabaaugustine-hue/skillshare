import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillbridge_python_lab/features/course/course_lesson_screen.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';

void main() {
  testWidgets('teaches the code lesson before requiring a checked editor run', (
    tester,
  ) async {
    final completedScores = <int>[];
    late Exercise editorExercise;
    late PracticeSession practice;
    const step = CourseStep(
      id: 'print-practice',
      title: 'Practice: First Output',
      subtitle: 'Use print() to display text.',
      kind: CourseStepKind.coding,
      xp: 20,
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'First Output',
          brief: 'Show a message on screen.',
          starterCode: '# Write your code here',
          requirements: <String>['Print a greeting'],
          hints: <String>['Put text inside quotes.', 'Call print()'],
          workedExample: 'print("Hello!")',
          whyItWorks: 'print() displays the value on its own line.',
          takeaway: 'Display text with print().',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CourseLessonScreen(step: step, onCompleted: completedScores.add),
        onGenerateRoute: (settings) {
          final arguments = settings.arguments! as Map<String, dynamic>;
          editorExercise = arguments['exercise'] as Exercise;
          practice = arguments['practice'] as PracticeSession;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    practice.onCompleted(80);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Finish practice'),
                ),
              ),
            ),
          );
        },
      ),
    );

    expect(find.text("What you'll learn"), findsOneWidget);
    expect(find.text('Short explanation'), findsOneWidget);
    expect(find.text('Worked example'), findsOneWidget);
    expect(find.text('Try it'), findsOneWidget);
    expect(find.text('Put text inside quotes.'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Show next hint'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Show next hint'));
    await tester.pumpAndSettle();
    expect(find.text('• Put text inside quotes.'), findsOneWidget);
    expect(find.text('• Call print()'), findsNothing);

    await tester.tap(find.text('TRY IT IN THE CODE EDITOR'));
    await tester.pumpAndSettle();
    expect(editorExercise.id, step.id);
    expect(practice.block.heading, 'First Output');
    expect(completedScores, isEmpty);

    await tester.tap(find.text('Finish practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Why this works'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Why this works'), findsOneWidget);
    expect(find.text('What you can now do'), findsOneWidget);
    expect(completedScores, isEmpty);

    await tester.tap(find.text('FINISH LESSON'));
    await tester.pumpAndSettle();
    expect(completedScores, <int>[80]);
  });
}
