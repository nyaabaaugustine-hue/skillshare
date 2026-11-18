import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:skillbridge_python_lab/features/ai/cloudflare_tutor_client.dart';
import 'package:skillbridge_python_lab/features/ai/tutor_models.dart';

void main() {
  test(
    'chat stream decodes tokens and keeps only trusted source URLs',
    () async {
      final client = CloudflareTutorClient(
        baseUrl: 'https://worker.example',
                accessTokenProvider: ({bool forceRefresh = false}) async =>
            'learner-token',
        client: _ResponseClient(
          200,'data: {"choices":[{"delta":{"content":"Hello "}}]}\n\n'
          'data: {"response":"world"}\n\n'
          'event: meta\n'
          'data: {"sources":["https://docs.python.org/3/tutorial/",'
          '"https://example.com/fake"]}\n\n',
        ),
      );
      addTearDown(client.close);

      final events = await client
          .chatStream(
            message: 'Explain loops',
            history: const <TutorChatTurn>[],
            context: TutorStudentContext.empty,
            style: const TutorTeachingStyle(),
          )
          .toList();

      expect(events.map((event) => event.text), <String>[
        'Hello ',
        'world',
        '',
      ]);
      expect(events.last.sources, <String>[
        'https://docs.python.org/3/tutorial/',
      ]);
    },
  );

  test('video lookup returns only HTTPS YouTube watch URLs', () async {
    final client = CloudflareTutorClient(
      baseUrl: 'https://worker.example',
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'learner-token',
      client: _ResponseClient(
        200,
        jsonEncode(<String, Object?>{
          'videos': <Map<String, String>>[
            <String, String>{
              'title': 'Python loops',
              'channel': 'Trusted channel',
              'url': 'https://www.youtube.com/watch?v=abc123',
            },
            <String, String>{
              'title': 'Untrusted URL',
              'channel': 'Unknown',
              'url': 'https://example.com/watch?v=bad',
            },
          ],
        }),
      ),
    );
    addTearDown(client.close);

    final videos = await client.findShortVideos('loops');

    expect(videos, hasLength(1));
    expect(videos.single.title, 'Python loops');
  });

  test('video lookup surfaces an unavailable Worker response', () async {
    final client = CloudflareTutorClient(
      baseUrl: 'https://worker.example',
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'learner-token',
      client: _ResponseClient(503, '{"error":"video_search_not_configured"}'),
    );
    addTearDown(client.close);

    await expectLater(
      client.findShortVideos('loops'),
      throwsA(
        isA<TutorException>().having(
          (error) => error.kind,
          'kind',
          TutorFailureKind.unavailable,
        ),
      ),
    );
  });
}

class _ResponseClient extends http.BaseClient {
  _ResponseClient(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
