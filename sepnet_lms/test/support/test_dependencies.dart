import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:skillbridge_python_lab/core/config/app_config.dart';
import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/core/notifications/reminder_gateway.dart';
import 'package:skillbridge_python_lab/core/notifications/reminder_service.dart';
import 'package:skillbridge_python_lab/core/security/id_generator.dart';
import 'package:skillbridge_python_lab/core/storage/app_database.dart';
import 'package:skillbridge_python_lab/core/storage/draft_repository.dart';
import 'package:skillbridge_python_lab/core/storage/exercise_repository.dart';
import 'package:skillbridge_python_lab/core/storage/settings_repository.dart';
import 'package:skillbridge_python_lab/core/storage/submission_repository.dart';
import 'package:skillbridge_python_lab/features/course/course_progress_repository.dart';
import 'package:skillbridge_python_lab/features/offline_sync/connectivity_service.dart';
import 'package:skillbridge_python_lab/features/offline_sync/submission_sync_service.dart';
import 'package:skillbridge_python_lab/features/python_runtime/python_runtime.dart';
import 'package:skillbridge_python_lab/integrations/lms/mock_lms_client.dart';

class _TestReminderGateway implements ReminderGateway {
  @override
  bool get supported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleComeback({
    required Duration after,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelComeback() async {}

  @override
  Future<void> cancelAll() async {}
}

/// Builds a real dependency graph against a real SQLite database, injecting
/// whatever [runtime] the caller wants to exercise.
///
/// Everything except the Python runtime is the production implementation, so a
/// widget test that passes a real runtime exercises the same wiring the shipped
/// app uses: real repositories, real submission queue, real mock LMS.
Future<AppDependencies> buildTestDependencies({
  required PythonRuntime runtime,
  bool online = true,
  String learnerRef = 'test-learner',
}) async {
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();

  final dbPath = p.join(
    Directory.systemTemp.path,
    'sb_widget_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  // In-process FFI: see app_database.dart for why the isolate-backed factory is
  // not usable inside `testWidgets`.
  final database = AppDatabase(
    factory: databaseFactoryFfiNoIsolate,
    path: dbPath,
  );
  await database.open();

  final settings = await SettingsRepository.create();
  await settings.setLearnerRef(learnerRef);

  final courseProgress = await CourseProgressRepository.create();

  final submissions = SubmissionRepository(database);
  final lms = MockLmsClient();
  final connectivity = FakeConnectivityService(online: online);

  return AppDependencies(
    config: AppConfig.test(),
    database: database,
    settings: settings,
    drafts: DraftRepository(database),
    submissions: submissions,
    exercises: ExerciseRepository(database),
    courseProgress: courseProgress,
    lmsClient: lms,
    connectivity: connectivity,
    runtime: runtime,
    syncService: SubmissionSyncService(
      lmsClient: lms,
      submissions: submissions,
      connectivity: connectivity,
    ),
    idGenerator: IdGenerator(),
    learnerRef: learnerRef,
    reminders: ReminderService(
      gateway: _TestReminderGateway(),
      settings: settings,
    ),
  );
}
