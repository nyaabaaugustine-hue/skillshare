import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'leaderboard_models.dart';

/// Talks to the same `/api/leaderboard` endpoint the website uses.
///
/// Points at `SB_LEADERBOARD_URL`, falling back to the LMS base URL so a single
/// server address can serve both. With neither configured the screen says so
/// instead of failing silently.
class LeaderboardClient {
  LeaderboardClient({required String baseUrl, http.Client? client})
    : _base = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      _http = client ?? http.Client();

  final String _base;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 15);

  bool get configured => _base.isNotEmpty;

  String get baseUrl => _base;

  /// Absolute URL of a learner's photo, for `Image.network`.
  String avatarUrl(String id) =>
      '$_base/api/leaderboard/avatar/${Uri.encodeComponent(id)}';

  Future<List<LeaderboardEntry>> top({int limit = 50}) async {
    if (!configured) {
      throw const LeaderboardException('The leaderboard is not connected yet.');
    }
    final response = await _request(
      () => _http.get(
        Uri.parse('$_base/api/leaderboard?limit=$limit'),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final entries = _payload(response)['entries'];
    if (entries is! List) {
      throw const LeaderboardException('The leaderboard reply was invalid.');
    }
    return <LeaderboardEntry>[
      for (final entry in entries)
        if (entry is Map)
          LeaderboardEntry.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  Future<LeaderboardEntry> submit({
    required String ref,
    required String name,
    required LeaderboardSnapshot snapshot,
    String? avatarDataUrl,
  }) async {
    if (!configured) {
      throw const LeaderboardException('The leaderboard is not connected yet.');
    }
    final response = await _request(
      () => _http.post(
        Uri.parse('$_base/api/leaderboard'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object?>{
          'ref': ref,
          'name': name,
          'stepsCompleted': snapshot.stepsCompleted,
          'practicesCompleted': snapshot.practicesCompleted,
          'scoreTotal': snapshot.scoreTotal,
          if (avatarDataUrl != null && avatarDataUrl.isNotEmpty)
            'avatar': avatarDataUrl,
        }),
      ),
    );
    final entry = _payload(response)['entry'];
    if (entry is! Map) {
      throw const LeaderboardException('Your score could not be saved.');
    }
    return LeaderboardEntry.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(_timeout);
    } on TimeoutException {
      throw const LeaderboardException(
        'The leaderboard took too long to answer. Try again.',
      );
    } catch (e) {
      throw const LeaderboardException(
        'Could not reach the leaderboard. Check your connection.',
      );
    }
  }

  Map<String, dynamic> _payload(http.Response response) {
    Map<String, dynamic> payload = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } catch (_) {
        // Fall through to the status handling below.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error'];
      throw LeaderboardException(
        message is String && message.isNotEmpty
            ? message
            : 'The leaderboard returned an error (${response.statusCode}).',
      );
    }
    return payload;
  }
}
