import 'package:flutter/material.dart';

/// The kind of activity a course step teaches. Drives the node icon, the
/// colour accent and the tag shown on the path.
enum CourseStepKind {
  reading,
  video,
  coding,
  quiz,
  prompt,
  api,
  project,
  assessment,
}

extension CourseStepKindX on CourseStepKind {
  String get label => switch (this) {
    CourseStepKind.reading => 'READ',
    CourseStepKind.video => 'VIDEO',
    CourseStepKind.coding => 'CODE',
    CourseStepKind.quiz => 'QUIZ',
    CourseStepKind.prompt => 'PROMPT',
    CourseStepKind.api => 'API',
    CourseStepKind.project => 'PROJECT',
    CourseStepKind.assessment => 'REVIEW',
  };

  IconData get icon => switch (this) {
    CourseStepKind.reading => Icons.menu_book_rounded,
    CourseStepKind.video => Icons.play_arrow_rounded,
    CourseStepKind.coding => Icons.terminal_rounded,
    CourseStepKind.quiz => Icons.help_rounded,
    CourseStepKind.prompt => Icons.auto_fix_high_rounded,
    CourseStepKind.api => Icons.hub_rounded,
    CourseStepKind.project => Icons.rocket_launch_rounded,
    CourseStepKind.assessment => Icons.military_tech_rounded,
  };
}

/// The teaching content shown inside a step's lesson screen.
///
/// A step may mix several blocks (a short reading, then a knowledge check, then
/// a hands-on exercise) so the lesson runner can walk the learner through it.
sealed class CourseBlock {
  const CourseBlock();

  /// The heading shown above the block.
  String get heading;
}

class ReadingBlock extends CourseBlock {
  const ReadingBlock({
    required this.heading,
    required this.paragraphs,
    this.tip,
  });

  @override
  final String heading;

  final List<String> paragraphs;

  /// An optional highlighted takeaway rendered in a callout card.
  final String? tip;
}

class VideoBlock extends CourseBlock {
  const VideoBlock({
    required this.heading,
    required this.subtitle,
    required this.publicId,
  });

  @override
  final String heading;

  final String subtitle;

  /// Cloudinary public id streamed by [CloudinaryVideoScreen].
  final String publicId;
}

class CodeBlock extends CourseBlock {
  const CodeBlock({
    required this.heading,
    required this.brief,
    required this.starterCode,
    required this.requirements,
    this.expectedOutput,
    this.hints = const [],
    this.workedExample,
    this.whyItWorks,
    this.takeaway,
    this.outputContains = const [],
    this.codeContains = const [],
    this.forbiddenLiterals = const [],
    this.minOutputLines = 0,
  });

  @override
  final String heading;

  final String brief;
  final String starterCode;
  final List<String> requirements;
  final String? expectedOutput;
  final List<String> hints;

  /// A small, complete example learners can study before trying the task.
  final String? workedExample;

  /// The idea demonstrated by [workedExample].
  final String? whyItWorks;

  /// The skill the learner should be able to use after passing the checks.
  final String? takeaway;

  /// Text the program's real output must contain (all of it, case-sensitive).
  final List<String> outputContains;

  /// Text the learner's own source must contain (comments are ignored), used
  /// to make sure a concept was actually used, e.g. `print(` or `*`.
  final List<String> codeContains;

  /// Answers the learner must produce by computing, never by typing.
  ///
  /// Used with randomised practice values: the expected total changes on every
  /// launch, and if it appears anywhere in the learner's source the step fails
  /// with "worked out in code, not typed as text". Typing the number is not
  /// the skill being taught.
  final List<String> forbiddenLiterals;

  /// The program must print at least this many non-empty lines.
  final int minOutputLines;
}

class QuizBlock extends CourseBlock {
  const QuizBlock({
    required this.heading,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  @override
  final String heading;

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class PromptBlock extends CourseBlock {
  const PromptBlock({
    required this.heading,
    required this.task,
    required this.mustInclude,
    required this.hints,
    this.minLength = 60,
  });

  @override
  final String heading;

  final String task;

  /// Phrases the learner's prompt must contain to be considered complete.
  /// Matching is case-insensitive.
  final List<String> mustInclude;
  final List<String> hints;
  final int minLength;
}

class ApiBlock extends CourseBlock {
  const ApiBlock({
    required this.heading,
    required this.brief,
    required this.endpoints,
    required this.correctEndpointIndex,
    required this.payloadFields,
    required this.requiredFields,
  });

  @override
  final String heading;

  final String brief;
  final List<String> endpoints;
  final int correctEndpointIndex;
  final List<String> payloadFields;

  /// Payload fields that must be included in the request to be valid.
  final List<String> requiredFields;
}

class ProjectBlock extends CourseBlock {
  const ProjectBlock({
    required this.heading,
    required this.brief,
    required this.checklist,
    this.starterCode,
    this.options = const [],
  });

  @override
  final String heading;

  final String brief;
  final List<String> checklist;
  final String? starterCode;
  final List<ProjectOption> options;
}

class ProjectOption {
  const ProjectOption({
    required this.title,
    required this.description,
    required this.prompt,
  });

  final String title;
  final String description;
  final String prompt;
}

class AssessmentQuestion {
  const AssessmentQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class AssessmentBlock extends CourseBlock {
  const AssessmentBlock({required this.heading, required this.questions});

  @override
  final String heading;

  final List<AssessmentQuestion> questions;
}

/// One node on the course path.
class CourseStep {
  const CourseStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.xp,
    required this.blocks,
    this.previewAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final CourseStepKind kind;

  /// Optional real course snapshot shown on the path node instead of an icon.
  final String? previewAsset;

  /// XP the step offers. Display only: the LMS is the system of record and
  /// grants the real reward after grading.
  final int xp;

  final List<CourseBlock> blocks;
}

/// A unit of the course: a header card plus the ordered steps on the path.
class CourseUnit {
  const CourseUnit({
    required this.id,
    required this.sectionLabel,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String id;
  final String sectionLabel;
  final String title;
  final String subtitle;
  final List<CourseStep> steps;
}
