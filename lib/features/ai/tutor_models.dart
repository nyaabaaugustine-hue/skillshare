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

  factory TutorStudentContext.fromRecords({
    required String learnerName,
    required LearnerProgress progress,
    required GuardianReport report,
  }) {
    return TutorStudentContext(
      learnerName: learnerName,
      totalPoints: progress.totalPoints,
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
  final int totalPoints;
  final int completedChallenges;
  final int totalChallenges;
  final List<String> weakPoints;
  final Map<String, int> recentScores;

  String get progressLabel =>
      '$completedChallenges of $totalChallenges challenges';

  Map<String, Object?> toPromptData() => <String, Object?>{
    'studentName': learnerName,
    'totalPoints': totalPoints,
    'completedChallenges': completedChallenges,
    'totalChallenges': totalChallenges,
    'weakPoints': weakPoints,
    'recentScores': recentScores,
  };

  static const empty = TutorStudentContext(
    learnerName: 'Learner',
    totalPoints: 0,
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

typedef TutorWebLookup = Future<TutorToolResult> Function(String query);
typedef TutorScreenshotAnalysis = Future<TutorToolResult> Function(
  TutorAttachment attachment,
);

/// Optional capabilities supplied by an online tutor adapter.
///
/// The offline app can still use [studentContext]. Web and screenshot access are
/// opt-in callbacks so the app never silently sends learner data to a service.
class TutorToolRegistry {
  const TutorToolRegistry({
    required this.studentContext,
    this.webLookup,
    this.screenshotAnalysis,
  });

  final TutorStudentContext studentContext;
  final TutorWebLookup? webLookup;
  final TutorScreenshotAnalysis? screenshotAnalysis;

  bool get canLookupWeb => webLookup != null;
  bool get canAnalyzeScreenshots => screenshotAnalysis != null;

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

  Future<TutorToolResult> analyzeScreenshot(TutorAttachment attachment) async {
    final analyze = screenshotAnalysis;
    if (analyze == null) {
      return const TutorToolResult(
        tool: 'screenshot',
        text: 'Screenshot analysis needs an online AI tutor connection.',
      );
    }
    return analyze(attachment);
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
