import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tutor_models.dart';

/// Small, explicit adapter for the online tutor tool API.
///
/// The app never calls arbitrary URLs from learner text. Only the configured
/// gateway receives requests, and only the minimum context needed for a tool is
/// sent. The server should authenticate the request, apply child-safety rules,
/// and return citations for web results.
class HttpTutorTools {
  HttpTutorTools({
    required String baseUrl,
    this.token = '',
    http.Client? client,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final String token;
  final http.Client _client;

  TutorToolRegistry registry(TutorStudentContext context) => TutorToolRegistry(
        studentContext: context,
        webLookup: (query) => webLookup(query),
        screenshotAnalysis: (attachment) => analyzeScreenshot(
          attachment,
          context: context,
        ),
      );

  Future<TutorToolResult> webLookup(String query) async {
    final response = await _post(
      '/v1/tutor/tools/web-lookup',
      <String, Object?>{'query': query},
    );
    return _result('web_lookup', response);
  }

  Future<TutorToolResult> analyzeScreenshot(
    TutorAttachment attachment, {
    required TutorStudentContext context,
  }) async {
    final response = await _post(
      '/v1/tutor/tools/screenshot',
      <String, Object?>{
        'attachment': <String, Object?>{
          'name': attachment.name,
          'mimeType': attachment.mimeType,
          'base64': base64Encode(attachment.bytes),
        },
        'studentContext': context.toPromptData(),
      },
    );
    return _result('screenshot', response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final headers = <String, String>{
        'content-type': 'application/json',
        if (token.isNotEmpty) 'authorization': 'Bearer $token',
      };
      final response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{
          'text': 'The online tutor tool is temporarily unavailable.',
        };
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'text': 'The tutor returned an invalid tool response.'};
    } catch (_) {
      return <String, dynamic>{
        'text': 'I could not reach the online tutor tool. Check your connection '
            'or continue with the offline explanation.',
      };
    }
  }

  TutorToolResult _result(String tool, Map<String, dynamic> json) {
    final sources = (json['sources'] as List<dynamic>?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    return TutorToolResult(
      tool: tool,
      text: (json['text'] as String?) ?? 'The tutor tool returned no explanation.',
      sources: sources,
    );
  }
}
