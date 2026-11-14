import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'course_models.dart';
import 'guardian_report.dart';

/// Emails a progress report to the learner's parent / guardian.
///
/// The email is **never** sent from the app itself. A Resend key compiled into
/// an APK can be read by anyone who unzips the bundle, and a key that may email
/// the parents of children has to stay server-side. So the app posts a
/// *structured* report (never raw HTML or free text) to the mailer endpoint in
/// `SB_GUARDIAN_REPORT_URL`; that endpoint renders the email and calls Resend
/// with a key only it holds. See `guardian_mailer/README.md`.
///
/// When no endpoint is configured — the default for development builds and for
/// the offline mock — [sendReport] is a silent no-op, so the rest of the app
/// behaves exactly as before.
class GuardianReportMailer {
  GuardianReportMailer({
    required this.config,
    http.Client? client,
    DateTime Function()? clock,
  })  : _http = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final AppConfig config;
  final http.Client _http;
  final DateTime Function() _clock;

  /// At most one automatic progress email per learner in this window, so a
  /// lesson-completion burst (or a replayed step) cannot spam a parent.
  static const Duration minimumInterval = Duration(hours: 20);

  static String _lastSentKey(String learnerRef) =>
      'guardian.report.lastSent.$learnerRef';

  /// Sends [report] to [guardianEmail].
  ///
  /// Returns `true` only when the mailer endpoint accepted the report. Nothing
  /// is thrown: a failed progress email must never interrupt a lesson.
  Future<bool> sendReport({
    required String learnerRef,
    required String studentName,
    required String guardianName,
    required String guardianEmail,
    required GuardianReport report,
  }) async {
    final endpoint = config.guardianReportUrl.trim();
    final to = guardianEmail.trim();
    if (endpoint.isEmpty || to.isEmpty || report.isEmpty) return false;
    if (await _sentRecently(learnerRef)) return false;

    final now = _clock();
    try {
      final response = await _http
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              _payload(
                learnerRef: learnerRef,
                studentName: studentName,
                guardianName: guardianName,
                guardianEmail: to,
                report: report,
                now: now,
              ),
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Guardian report email was not accepted (${response.statusCode}).',
        );
        return false;
      }
    } on TimeoutException {
      debugPrint('Guardian report email timed out.');
      return false;
    } catch (e) {
      debugPrint('Guardian report email failed: $e');
      return false;
    }

    await _recordSent(learnerRef, now);
    return true;
  }

  /// The request body the mailer contract expects. Only report data travels —
  /// no tokens, no code, no contact details beyond the guardian address.
  static Map<String, Object?> _payload({
    required String learnerRef,
    required String studentName,
    required String guardianName,
    required String guardianEmail,
    required GuardianReport report,
    required DateTime now,
  }) {
    final day = now.toUtc().toIso8601String().split('T').first;
    return <String, Object?>{
      'studentName': studentName.trim(),
      'guardianName': guardianName.trim(),
      'guardianEmail': guardianEmail,
      // Stable per learner per day, so a retry or a double tap does not send
      // the same report twice (Resend honours this as its idempotency key).
      'reportKey': 'progress-$learnerRef-$day',
      'report': <String, Object?>{
        'generatedAt': now.toUtc().toIso8601String(),
        'averageScore': report.averageScore,
        'attempted': report.attemptedCount,
        'totalSteps': report.totalSteps,
        'retries': report.totalRetries,
        'steps': <Map<String, Object?>>[
          for (final result in report.results.take(30))
            <String, Object?>{
              'title': result.step.title,
              'kind': result.step.kind.label,
              'score': result.latestScore,
              'attempts': result.attempts,
              'band': result.band.label,
              'weak': result.isWeak,
              'advice': result.advice,
            },
        ],
      },
    };
  }

  Future<bool> _sentRecently(String learnerRef) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSentKey(learnerRef));
      if (raw == null || raw.isEmpty) return false;
      final last = DateTime.tryParse(raw);
      if (last == null) return false;
      return _clock().difference(last) < minimumInterval;
    } catch (_) {
      // Storage problems must not block a report; worst case it is sent once.
      return false;
    }
  }

  Future<void> _recordSent(String learnerRef, DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastSentKey(learnerRef),
        when.toUtc().toIso8601String(),
      );
    } catch (_) {
      // Nothing to recover: the next report is simply sent again later.
    }
  }
}
