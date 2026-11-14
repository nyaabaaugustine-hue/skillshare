import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/features/lms/certificate_card.dart';
import 'package:skillbridge_python_lab/features/lms/lms_hub_screen.dart';
import 'package:skillbridge_python_lab/features/python_runtime/fake_python_runtime.dart';
import 'package:skillbridge_python_lab/features/settings/settings_controller.dart';

import 'support/test_dependencies.dart';

/// Exercises the LMS certificate tab: the premium sample preview is always
/// visible, it is locked until every lesson is finished, and the download
/// action only becomes available once the whole course is complete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDependencies deps;

  setUp(() async {
    deps = await buildTestDependencies(runtime: FakePythonRuntime());
  });

  tearDown(() async {
    await deps.dispose();
  });

  Future<void> pumpFrames(WidgetTester tester, {int count = 12}) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpCertificate(WidgetTester tester) async {
    // A tall window so the whole certificate (and its call-to-action) is laid
    // out at once and does not depend on scrolling in the test.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDependencies>.value(value: deps),
          ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController(deps.settings),
          ),
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
        ],
        child: const MaterialApp(
          home: LmsHubScreen(initialSection: 3),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  Future<void> completeWholeCourse(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final step in pythonKickstartCourse.steps) {
        await deps.courseProgress.markCompleted(
          learner: deps.learnerRef,
          stepId: step.id,
          score: 100,
        );
      }
    });
  }

  testWidgets('shows a premium sample certificate behind a lock', (
    tester,
  ) async {
    await pumpCertificate(tester);

    // The certificate artwork itself is always rendered.
    expect(find.byType(CertificateCard), findsOneWidget);
    expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
    expect(find.text('Certificate of Completion'), findsOneWidget);
    expect(find.text('SKILLSBRIDGE ACADEMY'), findsOneWidget);
    expect(find.text(pythonKickstartCourse.title), findsOneWidget);

    // ... but it is locked, so there is no download action yet.
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Your certificate is waiting'), findsOneWidget);
    expect(find.text('Certificate unlocks at 100%'), findsOneWidget);
    expect(find.text('Download certificate'), findsNothing);
  });

  testWidgets('unlocks and offers the download once every lesson is done', (
    tester,
  ) async {
    await completeWholeCourse(tester);
    await pumpCertificate(tester);

    expect(find.byType(CertificateCard), findsOneWidget);
    expect(find.text('SAMPLE PREVIEW'), findsNothing);
    expect(find.text('Locked'), findsNothing);
    expect(find.text('Your certificate is ready'), findsOneWidget);
    expect(find.text('Download certificate'), findsOneWidget);
  });

  testWidgets('reports the real progress, not a hard-coded value', (
    tester,
  ) async {
    await pumpCertificate(tester);
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.text('0 of ${pythonKickstartCourse.steps.length} lessons complete'),
      findsOneWidget,
    );
  });
}
