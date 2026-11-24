import 'dart:async';

import 'package:skillbridge_python_lab/core/config/app_config.dart';
import 'package:skillbridge_python_lab/core/notifications/reminder_service.dart';
import 'package:skillbridge_python_lab/core/notifications/reminders.dart';
import 'package:skillbridge_python_lab/core/security/id_generator.dart';
import 'package:skillbridge_python_lab/core/storage/app_database.dart';
import 'package:skillbridge_python_lab/core/storage/draft_repository.dart';
import 'package:skillbridge_python_lab/core/storage/exercise_repository.dart';
import 'package:skillbridge_python_lab/core/storage/settings_repository.dart';
import 'package:skillbridge_python_lab/core/storage/submission_repository.dart';
import 'package:skillbridge_python_lab/features/course/course_progress_repository.dart';
import 'package:skillbridge_python_lab/features/offline_sync/connectivity_service.dart';
import 'package:skillbridge_python_lab/features/messages/push_gateway.dart';
import 'package:skillbridge_python_lab/features/messages/push_service.dart';
import 'package:skillbridge_python_lab/features/offline_sync/submission_sync_service.dart';
import 'package:skillbridge_python_lab/features/python_runtime/python_runtime.dart';
import 'package:skillbridge_python_lab/features/python_runtime/python_runtime_factory.dart';
import 'package:skillbridge_python_lab/integrations/lms/http_lms_client.dart';
import 'package:skillbridge_python_lab/integrations/lms/lms_client.dart';
import 'package:skillbridge_python_lab/integrations/lms/mock_lms_client.dart';

/// Composition root. Everything the app needs is created here and injected via
/// `provider`, so tests can substitute fakes without touching widgets.
class AppDependencies {
  AppDependencies({
    required this.config,
    required this.database,
    required this.settings,
    required this.drafts,
    required this.submissions,
    required this.exercises,
    required this.courseProgress,
    required this.lmsClient,
    required this.connectivity,
    required this.runtime,
    required this.syncService,
    required this.idGenerator,
    required this.learnerRef,
    required this.reminders,
    required this.push,
    this.ownsLmsClient = true,
    this.ownsRuntime = true,
  });

  final AppConfig config;
  final AppDatabase database;
  final SettingsRepository settings;
  final DraftRepository drafts;
  final SubmissionRepository submissions;
  final ExerciseRepository exercises;
  final CourseProgressRepository courseProgress;
  final LmsClient lmsClient;
  final ConnectivityService connectivity;
  final PythonRuntime runtime;
  final SubmissionSyncService syncService;
  final IdGenerator idGenerator;
  final String learnerRef;

  /// Daily + "you stopped halfway" reminders. A no-op on web.
  final ReminderService reminders;

  /// FCM push adapter. Desktop builds get a no-op implementation.
  final PushGateway push;
  final bool ownsLmsClient;
  final bool ownsRuntime;

  /// Builds the real dependency graph for the running app.
  static Future<AppDependencies> create({
    AppConfig? config,
    String? Function()? accessTokenProvider,
  }) async {
    final resolved = config ?? AppConfig.forCurrentPlatform();
    final database = AppDatabase();
    final databaseOpen = database.open();
    final settingsFuture = SettingsRepository.create();
    final courseProgressFuture = CourseProgressRepository.create();
    await databaseOpen;
    final settings = await settingsFuture;
    final courseProgress = await courseProgressFuture;
    final connectivity = ConnectivityPlusService();

    final learnerRef =
        settings.learnerRef ?? 'local-${IdGenerator().newShortId(10)}';
    await settings.setLearnerRef(learnerRef);

    LmsClient lmsClient;
    var ownsLms = true;
    if (resolved.useMockLms) {
      lmsClient = MockLmsClient();
    } else {
      lmsClient = HttpLmsClient(
        baseUrl: resolved.lmsBaseUrl,
        tokenProvider: CallbackTokenProvider(accessTokenProvider ?? () => null),
      );
    }

    final submissions = SubmissionRepository(database);
    final runtime = createPythonRuntime(resolved);
    final reminders = ReminderService(
      gateway: await Reminders.create(),
      settings: settings,
      learnedToday: () => ReminderService.learnedOn(
        courseProgress.activityDates(learnerRef),
        DateTime.now(),
      ),
    );
    final push = PushService(reminders: reminders);
    await push.initialize(
      // Web push public key from Firebase console > Cloud Messaging. It is a
      // public value; a build can still override it with --dart-define.
      vapidKey: const String.fromEnvironment(
        'SB_FCM_VAPID_KEY',
        defaultValue: 'BPc1Ed7KtjSKLU8l9ni0MsOk-oii_HpLSMp1A_VDhvRYuVmVb3ozFcuZUFquT5GRursvWhSCXnJu7kfZpfVSFI4',
      ),
    );

    return AppDependencies(
      config: resolved,
      database: database,
      settings: settings,
      drafts: DraftRepository(database),
      submissions: submissions,
      exercises: ExerciseRepository(database),
      courseProgress: courseProgress,
      lmsClient: lmsClient,
      connectivity: connectivity,
      runtime: runtime,
      syncService: SubmissionSyncService(
        lmsClient: lmsClient,
        submissions: submissions,
        connectivity: connectivity,
      ),
      idGenerator: IdGenerator(),
      learnerRef: learnerRef,
      reminders: reminders,
      push: push,
      ownsLmsClient: ownsLms,
      ownsRuntime: true,
    );
  }

  Future<void> dispose() async {
    push.dispose();
    reminders.dispose();
    if (ownsRuntime) await runtime.dispose();
    await connectivity.dispose();
    await database.close();
  }
}
