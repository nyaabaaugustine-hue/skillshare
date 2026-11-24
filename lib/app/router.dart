import 'package:flutter/material.dart';

import 'package:skillbridge_python_lab/features/editor/editor_screen.dart';
import 'package:skillbridge_python_lab/features/home/home_screen.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise_details_screen.dart';
import 'package:skillbridge_python_lab/features/lessons/lesson_screen.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_detail_screen.dart';
import 'package:skillbridge_python_lab/features/messages/announcements_screen.dart';
import 'package:skillbridge_python_lab/features/lms/lms_hub_screen.dart';
import 'package:skillbridge_python_lab/features/ai/ai_tutor_screen.dart';
import 'package:skillbridge_python_lab/features/lms/cloudinary_video_screen.dart';
import 'package:skillbridge_python_lab/features/achievements/achievements_screen.dart';
import 'package:skillbridge_python_lab/features/course/course_lesson_screen.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/quizzes/quiz.dart';
import 'package:skillbridge_python_lab/features/quizzes/quiz_screen.dart';
import 'package:skillbridge_python_lab/features/settings/settings_screen.dart';

/// Central named-route table for pushed (full-screen) destinations.
///
/// Tab-level screens (Home, Progress, Settings) are hosted by the shell; only
/// detail destinations are routes.
class AppRouter {
  const AppRouter._();

  /// Lets a background notification tap open a route from outside the widget
  /// tree. Installed on MaterialApp.navigatorKey by the bootstrap widget.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String home = '/';
  static const String editor = '/editor';
  static const String exercise = '/exercise';
  static const String lesson = '/lesson';
  static const String lms = '/lms';
  static const String aiTutor = '/ai-tutor';
  static const String lmsVideo = '/lms-video';
  static const String courseLesson = '/course-lesson';
  static const String quizRoute = '/quiz';
  static const String announcements = '/announcements';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name != null && name.startsWith('$announcements/')) {
      final id = name.substring('$announcements/'.length);
      if (id.isNotEmpty) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AnnouncementDetailScreen(id: id),
        );
      }
    }

    switch (settings.name) {
      case editor:
        // Either a bare Exercise (practice tab) or a map carrying the exercise
        // plus a course PracticeSession (practice step on the course path).
        final editorArgs = settings.arguments;
        final exercise = editorArgs is Map
            ? editorArgs['exercise']
            : editorArgs;
        if (exercise is! Exercise) return _home(settings);
        final practice = editorArgs is Map ? editorArgs['practice'] : null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => EditorScreen(
            exercise: exercise,
            practice: practice is PracticeSession ? practice : null,
          ),
        );
      case exercise:
        final exercise = settings.arguments;
        if (exercise is! Exercise) return _home(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ExerciseDetailsScreen(exercise: exercise),
        );
      case lesson:
        // Arguments may be the bare exercise, or a map carrying a callback so
        // the caller can chain lesson -> editor without a second push.
        final args = settings.arguments;
        final exercise = switch (args) {
          final Exercise e => e,
          final Map<String, dynamic> a when a['exercise'] is Exercise =>
            a['exercise'] as Exercise,
          _ => null,
        };
        if (exercise == null) return _home(settings);
        final onFinished = args is Map<String, dynamic>
            ? args['onFinished'] as VoidCallback?
            : null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              LessonScreen(exercise: exercise, onFinished: onFinished),
        );
      case lms:
        final initialSection = settings.arguments is int
            ? settings.arguments as int
            : 0;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LmsHubScreen(initialSection: initialSection),
        );
      case aiTutor:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AiTutorScreen(),
        );
      case lmsVideo:
        // Deep links (`#/lms-video` on a reload) carry no arguments: fall back
        // to the shell instead of throwing during route generation.
        final args = settings.arguments;
        if (args is! Map) return _home(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CloudinaryVideoScreen(
            title: args['title'] as String? ?? 'Python lesson',
            subtitle: args['subtitle'] as String? ?? 'SkillBridge Academy',
            publicId: args['publicId'] as String? ?? '',
          ),
        );
      case courseLesson:
        final args = settings.arguments;
        if (args is! Map) return _home(settings);
        final step = args['step'];
        if (step is! CourseStep) return _home(settings);
        final onCompleted = args['onCompleted'];
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CourseLessonScreen(
            step: step,
            onCompleted: onCompleted is ValueChanged<int> ? onCompleted : null,
          ),
        );
      case quizRoute:
        final quizArgument = settings.arguments;
        if (quizArgument is! Quiz) return _home(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => QuizScreen(quiz: quizArgument),
        );
      case announcements:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AnnouncementsScreen(),
        );
      case '/progress':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AchievementsScreen(),
        );
      case '/settings':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      default:
        return null;
    }
  }

  /// Safety net for routes reached without their arguments (hash deep link,
  /// browser reload, restored session): show the shell rather than crash.
  static Route<dynamic> _home(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const HomeScreen(),
    );
  }
}
