import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillbridge_python_lab/core/config/app_config.dart';
import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/auth/login_register_screen.dart';
import 'package:skillbridge_python_lab/features/splash/splash_screen.dart';
import 'package:skillbridge_python_lab/shared/widgets/premium_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Advances fake time far enough for microtasks, futures and short animations,
  /// without [WidgetTester.pumpAndSettle] (Bit loops forever, the busy spinner
  /// is indeterminate and the splash pulse never stops).
  Future<void> pumpFrames(WidgetTester tester, {int count = 8}) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  group('SplashScreen', () {
    Widget host({required bool ready, required VoidCallback onDone}) =>
        MaterialApp(
          home: SplashScreen(
            onDone: onDone,
            ready: ready,
            minDuration: const Duration(milliseconds: 100),
          ),
        );

    testWidgets('holds until ready, then fires onDone exactly once', (
      tester,
    ) async {
      var done = 0;

      await tester.pumpWidget(host(ready: false, onDone: () => done++));
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 0, reason: 'deps not loaded yet -> still on splash');

      await tester.pumpWidget(host(ready: true, onDone: () => done++));
      await tester.pump();
      expect(done, 1, reason: 'ready flip after minDuration -> hand off');

      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 1, reason: 'onDone must fire only once');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('waits for the minimum duration when already ready', (
      tester,
    ) async {
      var done = 0;

      await tester.pumpWidget(host(ready: true, onDone: () => done++));
      await tester.pump();
      expect(done, 0, reason: 'minDuration has not elapsed yet');

      await tester.pump(const Duration(milliseconds: 200));
      expect(done, 1);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('LoginRegisterScreen', () {
    testWidgets('empty sign-in form shows validation errors', (tester) async {
      final auth = AuthController();
      addTearDown(auth.dispose);
      var authed = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            home: LoginRegisterScreen(
              onAuthenticated: () => authed++,
              onGuest: () {},
            ),
          ),
        ),
      );
      await pumpFrames(tester);
      // Headline is role-aware ("Welcome back, Student" / "Welcome, Parent /
      // Guardian"); the role cards must be offered up front either way.
      expect(find.textContaining('Welcome back'), findsOneWidget);
      expect(find.text('Parent / Guardian'), findsOneWidget);
      expect(find.text('Demo student'), findsNothing);
      expect(find.text('Demo parent'), findsNothing);

      await tester.ensureVisible(find.byType(PremiumButton));
      await tester.tap(find.byType(PremiumButton));
      await pumpFrames(tester);

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(authed, 0);
      expect(auth.isAuthenticated, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('valid credentials sign in and enter the app', (tester) async {
      final auth = AuthController();
      addTearDown(auth.dispose);
      var authed = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            home: LoginRegisterScreen(
              onAuthenticated: () => authed++,
              onGuest: () {},
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'learner@academy.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.ensureVisible(find.byType(PremiumButton));
      await tester.tap(find.byType(PremiumButton));

      // Mock auth resolves after a short delay, then the screen hands off.
      await tester.pump(const Duration(milliseconds: 800));
      await pumpFrames(tester);

      expect(authed, 1);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session?.isAccount, isTrue);
      expect(auth.error, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('continue as guest enters the app without an account', (
      tester,
    ) async {
      final auth = AuthController();
      addTearDown(auth.dispose);
      var guested = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            home: LoginRegisterScreen(
              onAuthenticated: () {},
              onGuest: () => guested++,
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      await tester.ensureVisible(find.text('Continue as guest'));
      await tester.tap(find.text('Continue as guest'));
      await pumpFrames(tester);

      expect(guested, 1);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session?.guest, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('production authentication', () {
    test(
      'does not fall back to local mock accounts without Supabase config',
      () async {
        final auth = AuthController();
        addTearDown(auth.dispose);
        auth.configure(
          const AppConfig(
            environment: 'production',
            lmsBaseUrl: '',
            lmsClientId: '',
            runtimeKind: PythonRuntimeKind.fake,
            pythonExecutable: 'python',
            executionTimeout: Duration(seconds: 10),
            maxOutputChars: 200000,
          ),
        );

        final ok = await auth.login(
          identifier: 'learner@example.com',
          password: 'secret123',
        );
        expect(ok, isFalse);
        expect(auth.error, contains('Shared sign-in is not configured'));
        expect(auth.isAuthenticated, isFalse);
      },
    );
  });

  group('student registration with guardian link', () {
    test('creates a linked guardian login without a second signup', () async {
      final auth = AuthController();
      addTearDown(auth.dispose);

      final credentials = await auth.registerStudentWithGuardian(
        name: 'Ama Mensah',
        email: 'ama@academy.test',
        password: 'secret123',
        guardianName: 'Kofi Mensah',
        guardianEmail: 'kofi@academy.test',
      );

      expect(credentials, isNotNull);
      expect(credentials!.login, 'kofi@academy.test');
      expect(credentials.password, isNotEmpty);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session?.linkedGuardianLogin, 'kofi@academy.test');
      expect(auth.familyLink?.guardianName, 'Kofi Mensah');

      // The generated guardian login resolves straight to the linked learner.
      final signedOut = AuthController();
      addTearDown(signedOut.dispose);
      final ok = await signedOut.login(
        identifier: credentials.login,
        password: credentials.password,
      );
      expect(ok, isTrue);
      expect(signedOut.session?.role, UserRole.guardian);
      expect(signedOut.session?.linkedStudentName, 'Ama Mensah');
    });

    test('the guardian email is the login and the report address', () async {
      final auth = AuthController();
      addTearDown(auth.dispose);

      final credentials = await auth.registerStudentWithGuardian(
        name: 'Kojo Boateng',
        email: 'kojo@academy.test',
        password: 'secret123',
        guardianName: 'Yaa Boateng',
        guardianEmail: 'yaa@academy.test',
      );

      expect(credentials, isNotNull);
      expect(credentials!.login, 'yaa@academy.test');
      expect(auth.familyLink?.guardianEmail, 'yaa@academy.test');
    });
  });
}
