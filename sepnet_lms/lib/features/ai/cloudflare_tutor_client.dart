import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tutor_models.dart';

/// Supplies the Neon-signed access JWT.
///
/// [forceRefresh] asks the caller to mint a new one after a 401 instead of
/// reusing a cached value that may have just expired.
typedef TutorTokenProvider =
    Future<String?> Function({bool forceRefresh});

/// Authenticated client for the SkillsBridge Cloudflare Worker.
///
/// The Worker requires a Neon-signed JWT. Failures are surfaced as
/// [TutorException] with a kind and, for rate limits, a retry hint, so the
/// tutor service can tell the learner what actually happened instead of
/// pretending a fallback answer came from the model.
class CloudflareTutorClient {
  CloudflareTutorClient({
    required String baseUrl,
    required this.accessTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 35),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final TutorTokenProvider accessTokenProvider;
  final Duration timeout;
  final http.Client _client;

  Future<String?> _accessToken({bool forceRefresh = false}) async {
    final token =
        (await accessTokenProvider(forceRefresh: forceRefresh))?.trim();
    return token == null || token.isEmpty ? null : token;
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

  /// Maps an HTTP failure onto something a learner can act on.
  TutorException _failure(int statusCode, {String? retryAfterHeader}) {
    if (statusCode == 401 || statusCode == 403) {
      return const TutorException(
        TutorFailureKind.unauthorized,
        'Your session has expired. Sign in again to use the online AI tutor.',
      );
    }
    if (statusCode == 429) {
      final seconds = int.tryParse(retryAfterHeader ?? '');
      final wait = seconds == null ? null : Duration(seconds: seconds);
      final minutes = wait == null
          ? null
          : (wait.inSeconds / 60).ceil().clamp(1, 60);
      return TutorException(
        TutorFailureKind.rateLimited,
        minutes == null
            ? 'You have asked a lot of questions just now. Try again in a few minutes.'
            : 'You have asked a lot of questions just now. Try again in $minutes minute${minutes == 1 ? '' : 's'}.',
        retryAfter: wait,
      );
    }
    if (statusCode == 503) {
      return const TutorException(
        TutorFailureKind.unavailable,
        'The online AI tutor is not available right now.',
      );
    }
    return const TutorException(
      TutorFailureKind.unavailable,
      'The online AI tutor could not answer just now.',
    );
  }

  Future<http.Response> _post(
    String path,
    Map<String, Object?> body,
    String token,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: <String, String>{
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TutorException(
        TutorFailureKind.offline,
        'The online tutor took too long to answer, so this reply is from the offline tutor.',
      );
    } on http.ClientException {
      throw const TutorException(
        TutorFailureKind.offline,
        'The online tutor could not be reached, so this reply is from the offline tutor.',
      );
    }
  }

  Future<http.Response> _sendJson(
    String path,
    Map<String, Object?> body,
  ) async {
    var token = await _accessToken();
    if (token == null) {
      throw const TutorException(
        TutorFailureKind.unauthorized,
        'Sign in to use the online AI tutor.',
      );
    }
    var response = await _post(path, body, token);
    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _accessToken(forceRefresh: true);
      if (refreshed != null && refreshed != token) {
        token = refreshed;
        response = await _post(path, body, token);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _failure(
      response.statusCode,
      retryAfterHeader: response.headers['retry-after'],
    );
  }

  /// Matches [TutorRemoteChat]. Throws [TutorException] on failure so the
  /// service can explain that it fell back instead of silently substituting.
  Future<TutorReply?> chat({
    required String message,
    required List<TutorChatTurn> history,
    required TutorStudentContext context,
    required TutorTeachingStyle style,
  }) async {
    final response = await _sendJson(
      '/v1/tutor/chat',
      _requestBody(
        message: message,
        history: history,
        context: context,
        style: style,
      ),
    );
    final reply = _replyFromBody(response.bodyBytes);
    if (reply == null) {
      throw const TutorException(
        TutorFailureKind.malformed,
        'The online tutor sent an unreadable reply, so this answer is from the offline tutor.',
      );
    }
    return reply;
  }

  http.Request _streamRequest(
    Map<String, Object?> body,
    String token,
  ) => http.Request('POST', Uri.parse('$_baseUrl/v1/tutor/chat/stream'))
    ..headers.addAll(<String, String>{
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      'authorization': 'Bearer $token',
    })
    ..body = jsonEncode(body);

  /// Streams text tokens and final source metadata from Workers AI.
  Stream<TutorStreamEvent> chatStream({
    required String message,
    required List<TutorChatTurn> history,
    required TutorStudentContext context,
    required TutorTeachingStyle style,
  }) async* {
    final body = _requestBody(
      message: message,
      history: history,
      context: context,
      style: style,
    );
    var token = await _accessToken();
    if (token == null) {
      throw const TutorException(
        TutorFailureKind.unauthorized,
        'Sign in to use the online AI tutor.',
      );
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(_streamRequest(body, token)).timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        final refreshed = await _accessToken(forceRefresh: true);
        if (refreshed != null && refreshed != token) {
          token = refreshed;
          response = await _client
              .send(_streamRequest(body, token))
              .timeout(timeout);
        }
      }
    } on TimeoutException {
      throw const TutorException(
        TutorFailureKind.offline,
        'The online tutor took too long to answer, so this reply is from the offline tutor.',
      );
    } on http.ClientException {
      throw const TutorException(
        TutorFailureKind.offline,
        'The online tutor could not be reached, so this reply is from the offline tutor.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(
        response.statusCode,
        retryAfterHeader: response.headers['retry-after'],
      );
    }

    var eventName = 'message';
    final data = <String>[];
    try {
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
    } on TimeoutException {
      throw const TutorException(
        TutorFailureKind.offline,
        'The online tutor stopped answering, so the rest of this reply is from the offline tutor.',
      );
    }
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

  /// Picks the real image type from the bytes, because pickers routinely
  /// report `null`, `image/*`, `image/jpg` or a HEIC screenshot the vision
  /// model cannot read.
  static String _normalizeImageType(TutorAttachment attachment) {
    final declared = attachment.mimeType
        .toLowerCase()
        .split(';')
        .first
        .trim();
    if (declared == 'image/jpg') return 'image/jpeg';
    if (const <String>{
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(declared)) {
      return declared;
    }
    final bytes = attachment.bytes;
    if (bytes.length >= 12) {
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
    }
    return '';
  }

  Future<TutorToolResult> analyzeScreenshot(
    TutorAttachment attachment, {
    String? question,
    List<TutorChatTurn>? history,
  }) async {
    if (attachment.bytes.length > 2 * 1024 * 1024) {
      return const TutorToolResult(
        tool: 'screenshot',
        text: 'That image is too large. Choose a smaller screenshot and try again.',
      );
    }
    final mimeType = _normalizeImageType(attachment);
    if (mimeType.isEmpty) {
      return const TutorToolResult(
        tool: 'screenshot',
        text:
            'That image format is not supported. Use a PNG, JPEG or WebP screenshot, '
            'or paste the code or error text instead.',
      );
    }
    try {
      final response = await _sendJson('/v1/tutor/vision', <String, Object?>{
        // The learner's own question is what the vision model should answer.
        'message': (question ?? '').trim().isEmpty
            ? 'Explain the Python code or error in this image.'
            : question!.trim(),
        'mimeType': mimeType,
        'image': base64Encode(attachment.bytes),
        // Keeps the screenshot reply in the same conversation.
        'history': [
          for (final turn in history ?? const <TutorChatTurn>[])
            turn.toJson(),
        ],
      });
      final reply = _replyFromBody(response.bodyBytes);
      return TutorToolResult(
        tool: 'screenshot',
        text:
            reply?.text ??
            'I could not analyze that image right now. You can paste the code or error text instead.',
        sources: reply?.sources ?? const <String>[],
      );
    } on TutorException catch (error) {
      return TutorToolResult(tool: 'screenshot', text: error.message);
    }
  }

  Future<List<TutorVideo>> findShortVideos(String topic) async {
    final response = await _sendJson('/v1/tutor/resources', <String, Object?>{
      'topic': topic,
    });

    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Video resources response is invalid.');
      }
      decoded = value;
    } on FormatException {
      throw const TutorException(
        TutorFailureKind.malformed,
        'Video recommendations could not be read.',
      );
    }
    if (decoded['videos'] is! List) {
      throw const TutorException(
        TutorFailureKind.malformed,
        'Video recommendations could not be read.',
      );
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
