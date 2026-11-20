import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/app/router.dart';
import 'package:skillbridge_python_lab/features/quizzes/quiz.dart';
import 'package:skillbridge_python_lab/features/quizzes/quiz_screen.dart';

void main() {
  testWidgets('CHECK is gated until selection and wrong answers show feedback', (
    tester,
  ) async {
    final scores = <int>[];
    const quiz = Quiz(
      id: 'print-output',
      prompt: 'What does `print()` do?',
      options: <AnswerOption>[
        AnswerOption(text: 'Stores a value', isCorrect: false),
        AnswerOption(text: 'Writes text to output', isCorrect: true),
      ],
      explanation: 'Use print() to display a value in the output area.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: QuizScreen(quiz: quiz, onAnswered: scores.add),
      ),
    );

    final checkButton = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(checkButton).onPressed, isNull);

    await tester.tap(find.text('Stores a value'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(checkButton).onPressed, isNotNull);

    await tester.tap(find.text('CHECK'));
    await tester.pump();

    expect(
      find.text('Not quite. The correct answer is "Writes text to output".'),
      findsOneWidget,
    );
    expect(
      find.text('Use print() to display a value in the output area.'),
      findsOneWidget,
    );
    expect(scores, <int>[0]);
    expect(tester.widget<ElevatedButton>(checkButton).onPressed, isNull);

    await tester.tap(find.text('Writes text to output'));
    await tester.pump();
    expect(scores, <int>[0]);
  });

  testWidgets('correct answers report formative success once', (tester) async {
    final scores = <int>[];
    const quiz = Quiz(
      id: 'variable-name',
      prompt: 'Which name is valid?',
      options: <AnswerOption>[
        AnswerOption(text: '2name', isCorrect: false),
        AnswerOption(text: 'user_name', isCorrect: true),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: QuizScreen(quiz: quiz, onAnswered: scores.add),
      ),
    );

    await tester.tap(find.text('user_name'));
    await tester.pump();
    await tester.tap(find.text('CHECK'));
    await tester.pump();

    expect(find.text('Correct!'), findsOneWidget);
    expect(scores, <int>[100]);
    expect(find.text('This is practice feedback, not an official grade.'), findsOneWidget);
  });

  testWidgets('the named quiz route accepts a Quiz argument', (tester) async {
    const quiz = Quiz(
      id: 'route-test',
      prompt: 'Which value is Boolean?',
      options: <AnswerOption>[
        AnswerOption(text: 'True', isCorrect: true),
        AnswerOption(text: 'Maybe', isCorrect: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRouter.quizRoute,
                  arguments: quiz,
                ),
                child: const Text('Open quiz'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Which value is Boolean?'), findsOneWidget);
    expect(find.text('CHECK'), findsOneWidget);
  });
}
