import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/ai/ai_tutor_screen.dart';
import 'package:skillbridge_python_lab/features/ai/tutor_service.dart';

void main() {
  group('TutorService (offline brain)', () {
    late TutorService svc;

    setUp(() => svc = TutorService());

    test('greets and explains what it can do', () async {
      final reply = await svc.ask('hello');
      expect(reply, contains('Python'));
      expect(reply, contains('quiz'));
    });

    test('"which loop" is a question, never a greeting', () async {
      final reply = await svc.ask('which loop should I use?');
      expect(reply, contains('while'));
      expect(reply, contains('```'));
    });

    test('explains loops with a runnable example', () async {
      final reply = await svc.ask('Explain for and while loops simply');
      expect(reply, contains('Two kinds of loop'));
      expect(reply, contains('while count < 3'));
    });

    test('debugs errors like a detective', () async {
      final reply = await svc.ask('Help me fix this Python error');
      expect(reply, contains('traceback'));
      expect(reply, contains('NameError'));
    });

    test('quiz round-trip: question, right answer, wrong answer', () async {
      final q = await svc.ask('Quiz me');
      expect(q, contains('?'));
      expect(q, contains('A)'));

      final right = await svc.ask('b');
      expect(right, contains('Correct'));

      await svc.ask('quiz me again');
      final wrong = await svc.ask('c');
      expect(wrong, contains('Not quite'));
    });

    test('always answers something useful', () async {
      final reply = await svc.ask('zzz qqq wibble');
      expect(reply.trim(), isNotEmpty);
      expect(reply, contains('loops'));
    });
  });

  group('AiTutorScreen', () {
    Future<void> pumpTutor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: const AiTutorScreen(),
        ),
      );
      await tester.pump();
    }

    testWidgets('welcome shows the hero and starter prompts', (tester) async {
      await pumpTutor(tester);
      expect(find.text('AI Tutor'), findsOneWidget);
      expect(find.text('Explain loops'), findsOneWidget);
      expect(find.text('Quiz me'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('starter card sends and the tutor replies', (tester) async {
      await pumpTutor(tester);

      await tester.tap(find.text('Explain loops'));
      await tester.pump(); // user bubble + typing indicator
      expect(find.text('Explain for and while loops simply'), findsOneWidget);
      expect(find.byKey(const Key('typing-dots')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('typing-dots')), findsNothing);
      expect(find.textContaining('Two kinds of loop'), findsOneWidget);
      // The conversation replaced the welcome state.
      expect(find.text('Quiz me'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('typing a question replies and clears the field',
        (tester) async {
      await pumpTutor(tester);

      await tester.enterText(find.byType(TextField), 'give me a challenge');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();

      expect(find.text('give me a challenge'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('challenge: FizzBuzz'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('quiz round-trip through the chat UI replies to an answer',
        (tester) async {
      await pumpTutor(tester);

      await tester.enterText(find.byType(TextField), 'Quiz me now');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Quick check 1/3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Correct'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('send stays idle until there is text', (tester) async {
      await pumpTutor(tester);

      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();
      // Nothing sent: the welcome screen is still up.
      expect(find.text('Explain loops'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();
      expect(find.text('hi'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('I am your Python tutor'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
