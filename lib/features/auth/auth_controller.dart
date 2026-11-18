import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/security/id_generator.dart';
import '../course/course_progress_repository.dart';
import '../course/course_progress_sync_service.dart';
import 'cloud_auth.dart';
import 'family_link.dart';

/// The kind of account signing in. Sent to the LMS as `role` and persisted so
/// the rest of the app can adapt (e.g. a guardian-facing home).
enum UserRole {
  student,
  guardian;

  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.guardian => 'Parent / Guardian',
  };

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.student,
  );
}

/// Who is using the app: a registered learner with an LMS session token, a
/// signed-in learner, or someone who chose to continue as a guest.
class AuthSession {
  const AuthSession({
    required this.signedIn,
    this.name,
    this.email,
    this.token,
    this.guest = false,
    this.role = UserRole.student,
    this.linkedStudentName,
    this.linkedGuardianLogin,
    this.guardianEmail,
  });

  final bool signedIn;
  final String? name;
  final String? email;
  final String? token;
  final bool guest;
  final UserRole role;

  /// Learner a guardian session is tracking, or the learner a student session
  /// already created a guardian login for. `null` until a family link exists.
  final String? linkedStudentName;

  /// The auto-generated guardian login attached to this learner, if any.
  final String? linkedGuardianLogin;
  final String? guardianEmail;

  bool get isGuardian => role == UserRole.guardian;

  AuthSession copyWith({
    String? name,
    String? email,
    String? token,
    UserRole? role,
    String? linkedStudentName,
    String? linkedGuardianLogin,
    String? guardianEmail,
  }) => AuthSession(
    signedIn: signedIn,
    name: name ?? this.name,
    email: email ?? this.email,
    token: token ?? this.token,
    guest: guest,
    role: role ?? this.role,
    linkedStudentName: linkedStudentName ?? this.linkedStudentName,
    linkedGuardianLogin: linkedGuardianLogin ?? this.linkedGuardianLogin,
    guardianEmail: guardianEmail ?? this.guardianEmail,
  );

  bool get isAccount => signedIn && !guest;

  String get displayName {
    if (guest) return 'Guest learner';
    final name = this.name;
    if (name != null && name.isNotEmpty) return name;
    final email = this.email;
    if (email != null && email.isNotEmpty) return email;
    return 'Learner';
  }
}

/// Application sign-in state.
///
/// Lives for the whole app lifetime (owned by `BootstrapApp`), so the startup
/// flow, the login screen and Settings all observe the same source of truth:
/// the session is created by the login/register screen and cleared by Settings,
/// which rebuilds `home` and sends the learner back to the login/register
/// screen.
///
/// The backend configuration is late-bound through [configure]. Development
/// and tests can use the offline mock; production requires shared auth.
class AuthController extends ChangeNotifier {
  AuthController({http.Client? client, FamilyLinkStore? familyLinks})
    : _http = client ?? http.Client(),
      _family = familyLinks ?? FamilyLinkStore();

  static const String _keySession = 'auth.session';

  final http.Client _http;
  final FamilyLinkStore _family;

  AppConfig? _config;
  String? _learnerRef;
  AuthSession? _session;
  FamilyLink? _familyLink;
  bool _initialized = false;
  bool _busy = false;
  String? _error;
  String? _pendingVerificationEmail;
  CourseProgressRepository? _courseProgress;
  CourseProgressSyncService? _progressSync;

  /// Shared-account backend, present only when Neon Auth initialized
  /// successfully. Development and tests may use the offline mock.
  CloudAuth? _cloud;
  StreamSubscription<CloudUser>? _cloudEvents;

  AuthSession? get session => _session;

  /// Link between the current learner and their Parent / Guardian login, if
  /// one exists on this device.
  FamilyLink? get familyLink => _familyLink;

  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get isAuthenticated => _session?.signedIn ?? false;
  String? get error => _error;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  /// True when this build signs in against the shared website/Neon Auth origin.
  bool get cloudAuthEnabled => _cloud != null;

  /// Returns a usable tutor access JWT, refreshing it when it is expired or
  /// about to expire (or when the Worker rejected it with 401).
  Future<String?> tutorAccessToken({bool forceRefresh = false}) async {
    final token = _session?.token;
    if (token == null || token.isEmpty) return null;
    final cloud = _cloud;
    if (cloud == null) return token;
    if (!forceRefresh && !_expiresSoon(token)) return token;
    try {
      final fresh = await cloud.refreshAccessToken();
      _session = _session?.copyWith(token: fresh);
      notifyListeners();
      return fresh;
    } catch (error) {
      debugPrint('Tutor token refresh failed: $error');
      return forceRefresh ? null : token;
    }
  }

  /// True when the JWT expires within two minutes (or its `exp` is unreadable).
  static bool _expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map<String, dynamic>) return false;
      final exp = claims['exp'];
      if (exp is! int) return false;
      final remaining = exp * 1000 - DateTime.now().millisecondsSinceEpoch;
      return remaining < const Duration(minutes: 2).inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Late-bound LMS configuration; call once [AppDependencies] is ready.
  ///
  /// [learnerRef] ties a created family link to this device's learner, so a
  /// progress report can never be sent to the wrong family on a shared device.
  void configure(
    AppConfig config, {
    String? learnerRef,
    CourseProgressRepository? courseProgress,
  }) {
    _config = config;
    if (learnerRef != null && learnerRef.isNotEmpty) _learnerRef = learnerRef;
    _courseProgress = courseProgress;
    if (courseProgress != null) {
      courseProgress.onProgressChanged = _onLocalProgressChanged;
    }
  }

  /// Connects the shared account backend when configured.
  Future<void> initCloudAuth() async {
    final config = _config;
    if (config == null || !config.cloudAuthEnabled || _cloud != null) return;
    try {
      final cloud = await CloudAuth.initialize(
        baseUrl: config.sharedApiBaseUrl,
      );
      _cloud = cloud;
      final repository = _courseProgress;
      if (repository != null) {
        _progressSync = CourseProgressSyncService(
          baseUrl: config.sharedApiBaseUrl,
          auth: cloud,
          repository: repository,
        );
      }
      _cloudEvents = cloud.userEvents.listen(_adoptCloudUser);
      // A session restored from this device's storage keeps the same account
      // signed in across reloads (notably in the browser).
      final existing = cloud.currentSession;
      if (existing != null) {
        _adoptCloudUser(existing);
        _syncCloudProgress();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Shared accounts unavailable: $e');
    }
  }

  /// Opens the session Facebook (or a restored sign-in) produced.
  void _adoptCloudUser(CloudUser user) {
    _session = AuthSession(
      signedIn: true,
      name: user.name,
      email: user.email,
      token: user.token,
      role: UserRole.fromName(user.role),
      guardianEmail: user.guardianEmail,
    );
    _busy = false;
    _error = null;
    notifyListeners();
    // Device-local FamilyLinkStore entries are not trusted cloud relationships.
  }

  /// Facebook sign-in, available in the app and on the web.
  ///
  /// The browser leaves for Facebook and comes back (deep link on Android,
  /// redirect on the web), so there is nothing to navigate to here: the
  /// session arrives on the stream captured in [initCloudAuth].
  Future<bool> loginWithFacebook() async {
    final cloud = _cloud;
    if (cloud == null) {
      _error = 'Facebook sign-in is not switched on for this build.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final launched = await cloud.signInWithFacebook();
      if (!launched) {
        _error = 'Facebook sign-in was closed before it finished.';
        return false;
      }
      return true;
    } on CloudAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Facebook sign-in could not start. Please try again.';
      debugPrint('Facebook sign-in failed: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Cold-start reset.
  ///
  /// Clears local guest/mock state at launch. A persisted Neon Auth session is
  /// restored separately by [initCloudAuth].
  Future<void> startSignedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySession);
    } catch (_) {
      // Storage problems must not block startup.
    } finally {
      _session = null;
      _initialized = true;
      notifyListeners();
    }
  }

  /// Clears the last failure message (e.g. when the learner switches between
  /// sign in and create account).
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> login({
    required String identifier,
    required String password,
    UserRole role = UserRole.student,
  }) async {
    // A generated guardian login is a real credential: reject a wrong
    // password even though the offline mock would otherwise accept anything.
    final link = await _family.findByLogin(identifier);
    if (link != null &&
        !link.matchesStudentEmail(identifier) &&
        !link.verifyPassword(password)) {
      _error = 'Incorrect password for $identifier.';
      notifyListeners();
      return false;
    }
    final asGuardian = link != null && !link.matchesStudentEmail(identifier);
    final resolvedRole = asGuardian ? UserRole.guardian : role;
    final resolvedName = asGuardian ? link.guardianName : identifier;
    return _authenticate(
      path: '/auth/login',
      body: <String, Object?>{
        'identifier': identifier,
        'password': password,
        'role': resolvedRole.name,
      },
      fallbackName: resolvedName,
      role: resolvedRole,
      identifier: identifier,
      // Generated guardian logins are device-local and cannot authenticate
      // against the shared account provider.
      preferLocal: asGuardian,
    );
  }

  /// Registers a student and, in the same step, creates the linked Parent /
  /// Guardian login — no second account, no manual connect.
  ///
  /// Returns the one-time credentials to hand to the parent, or `null` when
  /// registration failed (see [error]).
  ///
  /// The guardian email is what the parent signs in with **and** where progress
  /// reports are emailed, so it is required for a family link; leaving it empty
  /// simply registers the learner.
  Future<GuardianCredentials?> registerStudentWithGuardian({
    required String name,
    required String email,
    required String password,
    String guardianName = '',
    String guardianEmail = '',
  }) async {
    if (_cloud != null) {
      await _authenticate(
        path: '/auth/register',
        body: <String, Object?>{
          'name': name,
          'email': email,
          'password': password,
          'role': UserRole.student.name,
          'guardianEmail': guardianEmail.trim(),
        },
        fallbackName: name,
        fallbackEmail: email,
        role: UserRole.student,
        identifier: email,
      );
      return null;
    }

    final ok = await register(
      name: name,
      email: email,
      password: password,
      role: UserRole.student,
    );
    if (!ok) return null;
    final resolvedEmail = guardianEmail.trim();
    if (resolvedEmail.isEmpty) return null;

    final resolvedGuardianName = guardianName.trim().isEmpty
        ? 'Parent of ${name.trim().split(RegExp(r'\s+')).first}'
        : guardianName.trim();
    final generatedPassword = FamilyLink.generatePassword();
    final link = FamilyLink.create(
      studentName: name,
      studentEmail: email,
      guardianName: resolvedGuardianName,
      guardianEmail: resolvedEmail,
      guardianLogin: resolvedEmail,
      learnerRef: _learnerRef ?? '',
      password: generatedPassword,
    );
    await _family.save(link);
    _familyLink = link;
    _session = _session?.copyWith(
      linkedStudentName: link.studentName,
      linkedGuardianLogin: link.guardianLogin,
    );
    notifyListeners();
    return GuardianCredentials(
      name: resolvedGuardianName,
      login: link.guardianLogin,
      password: generatedPassword,
    );
  }

  /// Issues a fresh password for the linked guardian login and returns the new
  /// credentials to hand over (the old password stops working immediately).
  Future<GuardianCredentials?> resetGuardianPassword() async {
    final link = _familyLink;
    if (link == null) return null;
    final password = FamilyLink.generatePassword();
    final updated = link.withPassword(password);
    await _family.save(updated);
    _familyLink = updated;
    notifyListeners();
    return GuardianCredentials(
      name: updated.guardianName,
      login: updated.guardianLogin,
      password: password,
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.student,
  }) {
    if (_cloud != null && role == UserRole.guardian) {
      _error = 'A Parent / Guardian must sign in with an invited family account.';
      notifyListeners();
      return Future<bool>.value(false);
    }
    return _authenticate(
      path: '/auth/register',
      body: <String, Object?>{
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
      },
      fallbackName: name,
      fallbackEmail: email,
      role: role,
      identifier: email,
    );
  }

  Future<bool> verifyEmail({required String email, required String otp}) async {
    final cloud = _cloud;
    if (cloud == null) {
      _error = 'Email verification is unavailable until shared sign-in is configured.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final user = await cloud.verifyEmail(email: email, otp: otp);
      _session = AuthSession(
        signedIn: true,
        name: user.name,
        email: user.email,
        token: user.token,
        role: UserRole.fromName(user.role),
        guardianEmail: user.guardianEmail,
      );
      _pendingVerificationEmail = null;
      _syncCloudProgress();
      return true;
    } on CloudAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerificationCode(String email) async {
    final cloud = _cloud;
    if (cloud == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await cloud.sendVerificationCode(email);
      _error = 'A new verification code was sent.';
      return true;
    } on CloudAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _authenticate({
    required String path,
    required Map<String, Object?> body,
    required String fallbackName,
    required UserRole role,
    String? fallbackEmail,
    String? identifier,
    bool preferLocal = false,
  }) async {
    _busy = true;
    _error = null;
    _pendingVerificationEmail = null;
    notifyListeners();
    try {
      final resolved = await _post(
        path: path,
        body: body,
        preferLocal: preferLocal,
      );
      final session = AuthSession(
        signedIn: true,
        name: resolved['name'] as String? ?? fallbackName,
        email: resolved['email'] as String? ?? fallbackEmail,
        token: resolved['token'] as String?,
        // Prefer the role the server confirms; fall back to what was chosen.
        role: resolved['role'] is String
            ? UserRole.fromName(resolved['role'] as String)
            : role,
      );
      _session = session;
      if (_cloud == null) await _bindFamily(identifier ?? session.email ?? '');
      _syncCloudProgress();
      return true;
    } on _AuthFailure catch (e) {
      _error = e.message;
      return false;
    } on CloudAuthException catch (e) {
      if (e.needsEmailVerification) {
        _pendingVerificationEmail = fallbackEmail;
        _error = 'Check your email for the verification code.';
        return false;
      }
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      debugPrint('Auth failed: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Skips authentication for this session only; the next launch starts at the
  /// login/register screen again.
  Future<void> continueAsGuest() async {
    _familyLink = null;
    _session = const AuthSession(signedIn: true, guest: true);
    _error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _cloud?.signOut();
    _session = null;
    _familyLink = null;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySession);
    } catch (_) {
      // Storage problems must not block signing out.
    }
    notifyListeners();
  }

  /// Attaches the stored family link, if any, to the session that just opened.
  ///
  /// Signing in with the guardian login turns the session into a guardian
  /// session tracking that learner; signing in as the learner keeps the student
  /// role but exposes the generated guardian login in Settings.
  Future<void> _bindFamily(String identifier) async {
    if (identifier.trim().isEmpty) return;
    final link =
        await _family.findByLogin(identifier) ??
        await _family.findByStudentEmail(identifier);
    if (link == null) {
      _familyLink = null;
      return;
    }
    final asGuardian = link.matchesLogin(identifier);
    _familyLink = link;
    _session = _session?.copyWith(
      role: asGuardian ? UserRole.guardian : _session?.role,
      name: asGuardian ? link.guardianName : _session?.name,
      linkedStudentName: link.studentName,
      linkedGuardianLogin: link.guardianLogin,
    );
  }

  void _onLocalProgressChanged(String learner) {
    if (learner != _learnerRef || !(_session?.isAccount ?? false)) return;
    _syncCloudProgress();
  }

  void _syncCloudProgress() {
    final sync = _progressSync;
    final learner = _learnerRef;
    if (sync == null || learner == null || !(_session?.isAccount ?? false)) {
      return;
    }
    unawaited(sync.sync(learner));
  }

  /// Uses Neon Auth for shared accounts. Local guest progress remains offline.
  Future<Map<String, Object?>> _post({
    required String path,
    required Map<String, Object?> body,
    bool preferLocal = false,
  }) async {
    // One account for app and web: when a shared backend is configured, email
    // sign-in and signup go there instead of the device.
    final cloud = _cloud;
    if (cloud != null && preferLocal) {
      throw const _AuthFailure(
        'This guardian login is stored only on this device. Create a shared '
        'account with this email to sign in on other devices.',
      );
    }
    if (cloud != null) {
      final user = path == '/auth/register'
          ? await cloud.register(
              name: body['name'] as String? ?? '',
              email: body['email'] as String? ?? '',
              password: body['password'] as String? ?? '',
              role: body['role'] as String? ?? UserRole.student.name,
              guardianEmail: body['guardianEmail'] as String? ?? '',
            )
          : await cloud.signIn(
              email: body['identifier'] as String? ?? '',
              password: body['password'] as String? ?? '',
            );
      return <String, Object?>{
        'token': user.token,
        'name': user.name,
        'email': user.email,
        'role': user.role,
      };
    }

    if (_config?.requiresCloudAuth ?? kReleaseMode) {
      throw const _AuthFailure(
        'Shared sign-in is not configured. Please contact SkillBridge Academy '
        'support before creating an account.',
      );
    }

    final baseUrl = _config?.lmsBaseUrl ?? '';
    if (baseUrl.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return <String, Object?>{'token': IdGenerator().newShortId(24)};
    }

    http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const _AuthFailure('The server took too long to respond.');
    } catch (e) {
      throw const _AuthFailure('We could not reach the server.');
    }

    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw _AuthFailure(
        (payload['message'] as String?) ??
            'Incorrect details. Please try again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _AuthFailure(
        (payload['message'] as String?) ??
            'The server returned an error (${response.statusCode}).',
      );
    }

    final user = payload['user'] as Map<String, dynamic>?;
    return <String, Object?>{
      'token': payload['token'] ?? payload['access_token'],
      'name': payload['name'] ?? user?['name'],
      'email': payload['email'] ?? user?['email'],
      'role': payload['role'] ?? user?['role'],
    };
  }

  @override
  void dispose() {
    _cloudEvents?.cancel();
    final cloud = _cloud;
    if (cloud != null) unawaited(cloud.dispose());
    super.dispose();
  }
}

class _AuthFailure implements Exception {
  const _AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
