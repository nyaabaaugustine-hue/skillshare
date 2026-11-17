import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tutor_models.dart';

/// Authenticated client for the SkillsBridge Cloudflare Worker.
///
/// The Worker now requires a Neon-signed JWT; no provider credential or static
/// app token is shipped in the Flutter bundle. The auth adapter still supplies
/// a Supabase session token today, so remote requests remain incompatible until
/// the Flutter Neon Auth migration is completed.
class CloudflareTutorClient {
  CloudflareTutorClient({
    required String baseUrl,
    required this.accessTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 35),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final String? Function() accessTokenProvider;
  final Duration timeout;
  final http.Client _client;

  Future<String?> _accessToken() async {
    final token = accessTokenProvider()?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<http.Response?> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final token = await _accessToken();
      if (token == null) return null;
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: <String, String>{
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response;
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> _requestBody({
    required String message,
    required List<TutorChatTurn> history,
    required TutorStudentContext context,
    required TutorTeachingStyle style,
  }) => <String, Object?>{
    'message': message,
    'history': [for (final turn in history) turn.toJson()],
    'studentContext': context.toPromptData(),
    'teachingStyle': style.toPromptData(),
  };

  List<String> _safeSources(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((source) => Uri.tryParse(source))
        .where(
          (uri) =>
              uri != null &&
              uri.scheme == 'https' &&
              uri.host == 'docs.python.org',
        )
        .map((uri) => uri!.toString())
        .toList(growable: false);
  }

  TutorReply? _replyFromBody(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final value = decoded['text'];
      if (value is! String || value.trim().isEmpty) return null;
      return TutorReply(
        text: value.trim(),
        sources: _safeSources(decoded['sources']),
      );
    } on FormatException {
      return null;
    }
  }

  /// Matches [TutorRemoteChat]. Invalid auth, network errors, non-2xx and
  /// malformed replies return null so the service uses its offline tutor.
  Future<TutorReply?> chat({
    required String message,
    required List<TutorChatTurn> history,
    required TutorStudentContext context,
    required TutorTeachingStyle style,
  }) async {
    final response = await _postJson(
      '/v1/tutor/chat',
      _requestBody(
        message: message,
        history: history,
        context: context,
        style: style,
      ),
    );
    return response == null ? null : _replyFromBody(response.bodyBytes);
  }

  /// Streams text tokens and final source metadata from Workers AI.
  Stream<TutorStreamEvent> chatStream({
    required String message,
    required List<TutorChatTurn> history,
    required TutorStudentContext context,
    required TutorTeachingStyle style,
  }) async* {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('A signed-in learner session is required.');
    }

    final request =
        http.Request('POST', Uri.parse('$_baseUrl/v1/tutor/chat/stream'))
          ..headers.addAll(<String, String>{
            'content-type': 'application/json',
            'accept': 'text/event-stream',
            'authorization': 'Bearer $token',
          })
          ..body = jsonEncode(
            _requestBody(
              message: message,
              history: history,
              context: context,
              style: style,
            ),
          );
    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Tutor stream returned HTTP ${response.statusCode}.',
      );
    }

    var eventName = 'message';
    final data = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(timeout)) {
      if (line.isEmpty) {
        final event = _decodeEvent(eventName, data.join('\n'));
        if (event != null) yield event;
        eventName = 'message';
        data.clear();
      } else if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    final finalEvent = _decodeEvent(eventName, data.join('\n'));
    if (finalEvent != null) yield finalEvent;
  }

  TutorStreamEvent? _decodeEvent(String eventName, String data) {
    if (data.isEmpty || data == '[DONE]') return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return null;
      if (eventName == 'meta') {
        return TutorStreamEvent(sources: _safeSources(decoded['sources']));
      }
      final response = decoded['response'];
      if (response is String && response.isNotEmpty) {
        return TutorStreamEvent(text: response);
      }
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final delta = (choices.first as Map)['delta'];
        if (delta is Map && delta['content'] is String) {
          return TutorStreamEvent(text: delta['content'] as String);
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<TutorToolResult> analyzeScreenshot(TutorAttachment attachment) async {
    if (attachment.bytes.length > 2 * 1024 * 1024) {
      return const TutorToolResult(
        tool: 'screenshot',
        text: 'That image is too large. Choose a smaller screenshot and try again.',
      );
    }
    final response = await _postJson('/v1/tutor/vision', <String, Object?>{
      'message': 'Explain the Python code or error in this image.',
      'mimeType': attachment.mimeType,
      'image': base64Encode(attachment.bytes),
    });
    final reply = response == null ? null : _replyFromBody(response.bodyBytes);
    return TutorToolResult(
      tool: 'screenshot',
      text: reply?.text ?? 'I could not analyze that image right now. You can paste the code or error text instead.',
      sources: reply?.sources ?? const <String>[],
    );
  }

  Future<List<TutorVideo>> findShortVideos(String topic) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('A signed-in learner session is required.');
    }
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/tutor/resources'),
          headers: <String, String>{
            'content-type': 'application/json',
            'authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, Object?>{'topic': topic}),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Video resources returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['videos'] is! List) {
      throw const FormatException('Video resources response is invalid.');
    }
    return (decoded['videos'] as List)
        .whereType<Map<String, dynamic>>()
        .where((video) => video['url'] is String)
        .map(
          (video) => TutorVideo(
            title: video['title'] is String ? video['title'] as String : '',
            channel: video['channel'] is String
                ? video['channel'] as String
                : '',
            url: video['url'] as String,
          ),
        )
        .where((video) {
          final uri = Uri.tryParse(video.url);
          return uri != null &&
              uri.scheme == 'https' &&
              uri.host == 'www.youtube.com' &&
              uri.path == '/watch';
        })
        .toList(growable: false);
  }

  void close() => _client.close();
}
