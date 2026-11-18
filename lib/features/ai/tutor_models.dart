import 'dart:typed_data';

import '../../features/course/guardian_report.dart';
import '../../integrations/lms/lms_models.dart';

/// The minimum learner context the tutor may receive.
///
/// It deliberately excludes email, tokens, raw submissions, and guardian data.
/// Only the active learner's display name, server-authoritative points, progress,
/// weak course steps, and recent scores are exposed.
class TutorStudentContext {
  const TutorStudentContext({
    required this.learnerName,
    required this.totalPoints,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.weakPoints,
    required this.recentScores,
  });

  /// [pointsAreServerAuthoritative] is false when the app is running against
  /// the mock LMS, whose points reset on every launch. In that case the tutor
  /// must not state a points total at all rather than invent one.
  factory TutorStudentContext.fromRecords({
    required String learnerName,
    required LearnerProgress progress,
    required GuardianReport report,
    bool pointsAreServerAuthoritative = true,
  }) {
    return TutorStudentContext(
      learnerName: learnerName,
      totalPoints: pointsAreServerAuthoritative ? progress.totalPoints : null,
      completedChallenges: progress.completedChallenges,
      totalChallenges: progress.totalChallenges,
      weakPoints: [
        for (final result in report.weakPoints)
          '${result.step.title} (${result.latestScore}%)',
      ],
      recentScores: {
        for (final result in report.results)
          result.step.title: result.latestScore,
      },
    );
  }

  final String learnerName;

  /// Server-authoritative points, or null when no real LMS is configured.
  final int? totalPoints;
  final int completedChallenges;
  final int totalChallenges;
  final List<String> weakPoints;
  final Map<String, int> recentScores;

  String get progressLabel =>
      '$completedChallenges of $totalChallenges challenges';

  Map<String, Object?> toPromptData() => <String, Object?>{
    'studentName': learnerName,
    if (totalPoints != null) 'totalPoints': totalPoints,
    'completedChallenges': completedChallenges,
    'totalChallenges': totalChallenges,
    'weakPoints': weakPoints,
    'recentScores': recentScores,
  };

  static const empty = TutorStudentContext(
    learnerName: 'Learner',
    totalPoints: null,
    completedChallenges: 0,
    totalChallenges: 0,
    weakPoints: <String>[],
    recentScores: <String, int>{},
  );
}

/// A screenshot or other visual supplied by the learner for tutoring.
class TutorAttachment {
  const TutorAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  Map<String, Object?> toPromptData() => <String, Object?>{
    'name': name,
    'mimeType': mimeType,
    'byteLength': bytes.length,
  };
}

class TutorToolResult {
  const TutorToolResult({
    required this.tool,
    required this.text,
    this.sources = const <String>[],
  });

  final String tool;
  final String text;
  final List<String> sources;
}

class TutorReply {
  const TutorReply({required this.text, this.sources = const <String>[]});

  final String text;
  final List<String> sources;
}

/// Why an online tutor call failed. The app needs this to tell a learner
/// "sign in again" apart from "you have asked a lot, retry in 4 minutes" and
/// from "you are offline" - otherwise every failure looks like a normal reply
/// from the offline brain.
enum TutorFailureKind { unauthorized, rateLimited, unavailable, offline, malformed }

class TutorException implements Exception {
  const TutorException(this.kind, this.message, {this.retryAfter});

  final TutorFailureKind kind;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class TutorStreamEvent {
  const TutorStreamEvent({this.text = '', this.sources = const <String>[]});

  final String text;
  final List<String> sources;
}

class TutorVideo {
  const TutorVideo({
    required this.title,
    required this.channel,
    required this.url,
  });

  final String title;
  final String channel;
  final String url;
}

typedef TutorWebLookup = Future<TutorToolResult> Function(String query);
typedef TutorScreenshotAnalysis = Future<TutorToolResult> Function(
  TutorAttachment attachment, {
  String? question,
  List<TutorChatTurn>? history,
});
typedef TutorVideoSearch = Future<List<TutorVideo>> Function(String topic);

/// One earlier message, sent with each request so the remote model keeps the
/// thread of the conversation.
class TutorChatTurn {
  const TutorChatTurn({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  Map<String, String> toJson() => <String, String>{
    'role': fromUser ? 'user' : 'assistant',
    'content': text,
  };
}

/// Asks a remote language model for a reply. Returns null on any failure so
/// the caller can fall back to the offline tutor.
typedef TutorRemoteChat = Future<TutorReply?> Function({
  required String message,
  required List<TutorChatTurn> history,
  required TutorStudentContext context,
  required TutorTeachingStyle style,
});

typedef TutorRemoteStream = Stream<TutorStreamEvent> Function({
  required String message,
  required List<TutorChatTurn> history,
  required TutorStudentContext context,
  required TutorTeachingStyle style,
});

/// Optional capabilities supplied by an online tutor adapter.
///
/// The offline app can still use [studentContext]. Web and screenshot access are
/// opt-in callbacks so the app never silently sends learner data to a service.
class TutorToolRegistry {
  const TutorToolRegistry({
    required this.studentContext,
    this.webLookup,
    this.screenshotAnalysis,
    this.videoSearch,
  });

  final TutorStudentContext studentContext;
  final TutorWebLookup? webLookup;
  final TutorScreenshotAnalysis? screenshotAnalysis;
  final TutorVideoSearch? videoSearch;

  bool get canLookupWeb => webLookup != null;
  bool get canAnalyzeScreenshots => screenshotAnalysis != null;
  bool get canFindVideos => videoSearch != null;

  Future<TutorToolResult> lookupWeb(String query) async {
    final lookup = webLookup;
    if (lookup == null) {
      return const TutorToolResult(
        tool: 'web_lookup',
        text: 'Web lookup is not enabled in offline mode.',
      );
    }
    return lookup(query);
  }

  Future<TutorToolResult> analyzeScreenshot(
    TutorAttachment attachment, {
    String? question,
    List<TutorChatTurn>? history,
  }) async {
    final analyze = screenshotAnalysis;
    if (analyze == null) {
      return const TutorToolResult(
        tool: 'screenshot',
        text: 'Screenshot analysis needs an online AI tutor connection.',
      );
    }
    return analyze(attachment, question: question, history: history);
  }

  Future<List<TutorVideo>> findVideos(String topic) async {
    final search = videoSearch;
    if (search == null) return const <TutorVideo>[];
    return search(topic);
  }
}

/// Teaching behavior used by a remote tutor adapter when it builds its prompt.
class TutorTeachingStyle {
  const TutorTeachingStyle({
    this.showWorkedExamples = true,
    this.useSocraticQuestions = true,
    this.explainInSmallSteps = true,
    this.encourageWithoutInflatingScores = true,
  });

  final bool showWorkedExamples;
  final bool useSocraticQuestions;
  final bool explainInSmallSteps;
  final bool encourageWithoutInflatingScores;

  Map<String, bool> toPromptData() => <String, bool>{
    'showWorkedExamples': showWorkedExamples,
    'useSocraticQuestions': useSocraticQuestions,
    'explainInSmallSteps': explainInSmallSteps,
    'encourageWithoutInflatingScores': encourageWithoutInflatingScores,
  };
}
