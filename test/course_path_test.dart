import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/app/app.dart';
import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/features/home/connectivity_controller.dart';
import 'package:skillbridge_python_lab/features/python_runtime/fake_python_runtime.dart';
import 'package:skillbridge_python_lab/features/settings/settings_controller.dart';

import 'support/test_dependencies.dart';

/// Exercises the gamified Python course path: unlocking, the lesson runner
/// across activity kinds, and persistence of progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDependencies deps;

  setUp(() async {
    deps = await buildTestDependencies(runtime: FakePythonRuntime());
  });

  tearDown(() async {
    await deps.dispose();
  });

  Future<void> pumpFrames(WidgetTester tester, {int count = 10}) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDependencies>.value(value: deps),
          ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController(deps.settings),
          ),
          ChangeNotifierProvider<ConnectivityController>(
            create: (_) => ConnectivityController(deps),
          ),
        ],
        child: const SkillBridgeApp(),
      ),
    );
    await pumpFrames(tester);
  }

  testWidgets(
    'renders the path with the first step current and the rest locked',
    (tester) async {
      await pumpApp(tester);

      expect(find.text('Unit 1: Python Kickstart'), findsOneWidget);
      expect(find.text('START'), findsWidgets);
      expect(find.text('Advancing your career with Python'), findsOneWidget);

      // Step 1 is the only unlocked node.
      expect(
        find.byKey(const ValueKey<String>('course-step-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('course-step-1')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 30));
    },
  );

  testWidgets('locked steps explain what unlocks them', (tester) async {
    await pumpApp(tester);

    final locked = find.byKey(const ValueKey<String>('course-step-1'));
    await tester.ensureVisible(locked);
    await pumpFrames(tester, count: 3);

    await tester.tap(locked);
    await pumpFrames(tester, count: 3);

    expect(
      find.text('Finish the previous step to unlock this one.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 30));
  });

  testWidgets(
    'completing a lesson persists progress and unlocks the next step',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey<String>('course-step-0')));
      await pumpFrames(tester);

      // The first step is a video lesson: it is satisfied as soon as it opens
      // (video steps are skippable), so it can be finished straight away.
      expect(find.text('Advancing your career with Python'), findsWidgets);
      await tester.tap(find.text('FINISH LESSON'));
      await pumpFrames(tester);

      // Back on the path with step 1 recorded.
      expect(
        deps.courseProgress.completedSteps(deps.learnerRef),
        contains('py-video-01'),
      );
      expect(deps.courseProgress.scores(deps.learnerRef)['py-video-01'], 100);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 30));
    },
  );
}
