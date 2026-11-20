import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/ai/tutor_models.dart';
import 'package:skillbridge_python_lab/features/ai/tutor_service.dart';

void main() {
  const context = TutorStudentContext(
    learnerName: 'Ama',
    totalPoints: 120,
    completedChallenges: 3,
    totalChallenges: 8,
    weakPoints: <String>['Loops (55%)'],
    recentScores: <String, int>{'Loops': 55},
  );

  test('progress question uses only the active learner context', () async {
    final service = TutorService(
      studentContext: context,
      tools: const TutorToolRegistry(studentContext: context),
    );

    final answer = await service.ask('What are my weak points and points?');

    expect(answer, contains('Ama'));
    expect(answer, contains('120 points'));
    expect(answer, contains('Loops (55%)'));
    expect(answer, isNot(contains('email')));
  });

  test('web lookup uses the injected tool and preserves sources', () async {
    final service = TutorService(
      studentContext: context,
      tools: TutorToolRegistry(
        studentContext: context,
        webLookup: (query) async => TutorToolResult(
          tool: 'web_lookup',
          text: 'Result for $query',
          sources: const <String>['https://docs.python.org/'],
        ),
      ),
    );

    final reply = await service.askReply(
      'Search the latest Python range docs',
    );

    expect(reply.text, contains('Result for Search the latest Python range docs'));
    // Sources travel beside the text, not inside it.
    expect(reply.sources, contains('https://docs.python.org/'));
  });

  test(
    'screenshot is rejected clearly when offline analysis is disabled',
    () async {
      final service = TutorService(
        studentContext: context,
        tools: const TutorToolRegistry(studentContext: context),
      );

      final answer = await service.ask(
        'Please explain this error',
        attachments: <TutorAttachment>[
          TutorAttachment(
            name: 'traceback.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      );

      expect(answer, contains('screenshot'));
      expect(answer, contains('offline'));
    },
  );

  test('screenshot is passed to an injected analysis tool', () async {
    var called = false;
    final service = TutorService(
      studentContext: context,
      tools: TutorToolRegistry(
        studentContext: context,
        screenshotAnalysis: (attachment, {question, history}) async {
          called = attachment.name == 'code.png' && question == 'Explain this code';
          return const TutorToolResult(
            tool: 'screenshot',
            text: 'The screenshot shows a missing colon.',
          );
        },
      ),
    );

    final answer = await service.ask(
      'Explain this code',
      attachments: <TutorAttachment>[
        TutorAttachment(
          name: 'code.png',
          mimeType: 'image/png',
          bytes: Uint8List(0),
        ),
      ],
    );

    expect(called, isTrue);
    expect(answer, contains('missing colon'));
  });
}
