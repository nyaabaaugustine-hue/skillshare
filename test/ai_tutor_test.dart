import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/ai/ai_tutor_screen.dart';
import 'package:skillbridge_python_lab/features/ai/tutor_models.dart';
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

    test('a greeting followed by a real question is answered', () async {
      // Regression: "hi, ..." was treated as a bare hello and the question was
      // dropped.
      final reply = await svc.ask('hi, how do I use a while loop?');
      expect(reply, contains('while'));
      expect(reply, isNot(contains('I am your Python tutor')));
    });

    test('a topic question is not swallowed by the debugging branch', () async {
      final reply = await svc.ask('help me fix my list');
      expect(reply, contains('append'));
      expect(reply, isNot(contains('traceback')));
    });

    test('substring lookalikes do not hijack a topic', () async {
      final reply = await svc.ask('what is a suffix');
      expect(reply, isNot(contains('traceback')));
    });

    test('resetConversation clears the pending quiz answer', () async {
      final service = TutorService();
      await service.ask('Quiz me');
      service.resetConversation();
      final reply = await service.ask('b');
      expect(reply, isNot(contains('Correct')));
      expect(reply, isNot(contains('Not quite')));
    });

    test('a failed online call is labelled and remembered', () async {
      final service = TutorService(
        remote:
            ({
              required String message,
              required List<TutorChatTurn> history,
              required TutorStudentContext context,
              required TutorTeachingStyle style,
            }) async {
              expect(message, 'Explain loops');
              throw const TutorException(
                TutorFailureKind.offline,
                'The online tutor could not be reached.',
              );
            },
      );

      final reply = await service.ask('Explain loops');
      expect(reply, contains(TutorService.offlineNotice));
      expect(reply, contains('Two kinds of loop'));
      expect(service.lastFailure, 'The online tutor could not be reached.');
      expect(service.modeLabel, 'Offline fallback');
    });

    test('open-ended answers are deterministic', () async {
      final first = await TutorService().ask('zzz qqq wibble');
      final second = await TutorService().ask('zzz qqq wibble');
      expect(first, second);
    });
  });

  group('AiTutorScreen', () {
    Future<void> pumpTutor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildDarkTheme(), home: const AiTutorScreen()),
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
      await tester.pump();
      expect(find.text('Explain for and while loops simply'), findsOneWidget);

      // The offline brain now answers without an artificial delay, so the
      // typing indicator is not guaranteed to be visible between frames.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('typing-dots')), findsNothing);
      expect(find.textContaining('Two kinds of loop'), findsOneWidget);
      // The conversation replaced the welcome state.
      expect(find.text('Quiz me'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('streamed replies show citations and visual explanations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = TutorService(
        remoteStream:
            ({
              required String message,
              required List<TutorChatTurn> history,
              required TutorStudentContext context,
              required TutorTeachingStyle style,
            }) async* {
              yield const TutorStreamEvent(text: 'A loop repeats code.');
              yield const TutorStreamEvent(
                sources: <String>[
                  'https://docs.python.org/3/tutorial/controlflow.html',
                ],
              );
            },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: AiTutorScreen(service: service),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Explain loops');
      await tester.pump();
      await tester.tap(find.byTooltip('Send to tutor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.textContaining('A loop repeats code.'), findsOneWidget);
      expect(find.text('Python documentation'), findsOneWidget);
      expect(find.text('QUICK PICTURE'), findsOneWidget);
      expect(find.byTooltip('Read aloud'), findsNothing);
      expect(find.text('Read aloud'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('typing a question replies and clears the field', (
      tester,
    ) async {
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

    testWidgets('quiz round-trip through the chat UI replies to an answer', (
      tester,
    ) async {
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
