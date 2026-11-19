import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/di/app_dependencies.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_register_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/guardian_home_screen.dart';
import 'features/home/connectivity_controller.dart';
import 'features/onboarding/welcome_video_dialog.dart';
import 'features/settings/settings_controller.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

/// Builds the dependency graph while showing clear loading and error states
/// (important on slow, low-end devices).
///
/// Two rules keep this stable:
///  1. One MaterialApp stays mounted for the whole app lifetime (swapping
///     MaterialApps caused an "inactive element" assertion).
///  2. Providers are installed through MaterialApp.builder, i.e. ABOVE the
///     Navigator. Pushed routes (editor, lesson, achievements, settings...)
///     are siblings of `home`, not children of it, so providers placed inside
///     `home` are invisible to them and throw ProviderNotFoundError.
///
/// The provider tree shape never changes between loading and loaded. Each
/// provider is lazy, so nothing reads `_deps` until a screen that needs it is
/// built, which only happens after loading has finished.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppDependencies? _deps;
  Object? _error;
  bool _splashDone = false;

  /// Owned here so it outlives every screen; provided via `.value` above the
  /// Navigator so Settings (a pushed route) can sign out too.
  final AuthController _auth = AuthController();

  @override
  void initState() {
    super.initState();
    _auth.startSignedOut();
    _load();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final deps = await AppDependencies.create(
        accessTokenProvider: () => _auth.session?.token,
      );
      if (!mounted) return;
      _auth.configure(
        deps.config,
        learnerRef: deps.learnerRef,
        courseProgress: deps.courseProgress,
      );
      // Shared accounts (same Neon Auth login on phone and web) when the
      // public website API origin is configured; guest/offline access remains.
      await _auth.initCloudAuth();
      // Schedules the daily nudge (and asks for notification permission the
      // first time). Never blocks the first frame.
      unawaited(deps.reminders.bootstrap());
      setState(() {
        _deps = deps;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() {
      _deps = null;
      _error = null;
      _splashDone = false;
    });
    _load();
  }

  void _finishSplash() {
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  Widget _home() {
    if (_error != null) {
      return _ErrorScreen(message: '$_error', onRetry: _retry);
    }
    // Wait for dependencies and auth state. Neon Auth restores shared sessions;
    // local guest/mock sessions do not persist. Signing out returns here, while
    // signing in (or continuing as guest) opens the app shell.
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        final ready = _deps != null && _auth.initialized;
        if (!_splashDone) {
          return SplashScreen(onDone: _finishSplash, ready: ready);
        }
        if (_auth.isAuthenticated) {
          // Parents / guardians get the read-only report; everyone else gets
          // the full learning shell.
          return _WelcomeGate(
            child: (_auth.session?.isGuardian ?? false)
                ? const GuardianHomeScreen()
                : const HomeScreen(),
          );
        }
        return LoginRegisterScreen(
          onAuthenticated: _finishSplash,
          onGuest: _finishSplash,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Providers sit ABOVE MaterialApp so the app itself can read
    // SettingsController for `themeMode` (a provider below MaterialApp is
    // invisible to it) while still being above the Navigator, so pushed routes
    // reach them too. They are lazy, so `_deps!` is only touched once loading
    // has finished and a screen actually asks for a dependency.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: _auth),
        Provider<AppDependencies>(create: (_) => _deps!),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(_deps!.settings),
        ),
        ChangeNotifierProvider<ConnectivityController>(
          create: (_) => ConnectivityController(_deps!),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Before dependencies load there is no settings store yet, so the
          // shell stays on the brand's dark theme until `_deps` arrives. Once it
          // does, the picker in Settings drives light / dark / system live.
          final themeMode = _deps == null
              ? ThemeMode.dark
              : context.watch<SettingsController>().themeMode;
          return MaterialApp(
            title: 'SkillBridge Academy',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeOutCubic,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: _home(),
          );
        },
      ),
    );
  }
}

/// Pops the English welcome video once after a successful sign-in. It is
/// mounted only while authenticated, so signing
/// out and back in shows it again.
class _WelcomeGate extends StatefulWidget {
  const _WelcomeGate({required this.child});

  final Widget child;

  @override
  State<_WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<_WelcomeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Let the sign-in transition settle before the video sheet rises, so the
      // learner sees the shell arrive first instead of two animations at once.
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const WelcomeVideoDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'The app could not start',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
