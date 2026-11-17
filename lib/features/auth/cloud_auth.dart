import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in identity behind one account.
///
/// The same record is produced by email/password sign-in, signup and Facebook,
/// on Android and in the browser, because both builds talk to the same
/// Supabase project: an account created on the phone signs in on the web and
/// the other way round.
class CloudUser {
  const CloudUser({
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.guardianEmail,
  });

  final String name;
  final String email;

  /// `student` or `guardian`, resolved from server-managed account metadata
  /// when available so the app opens the correct shell after sign-in.
  final String role;
  final String? token;
  final String? guardianEmail;
}

/// A sign-in problem that is safe to show to a learner.
class CloudAuthException implements Exception {
  const CloudAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Shared-account gateway (Supabase Auth).
///
/// Enabled when `SB_SUPABASE_URL` and `SB_SUPABASE_ANON_KEY` are passed at
/// build time. Development and tests can use offline mock authentication when
/// they are absent; production builds reject local mock sign-in.
///
/// Nothing secret lives here: the anon key is a publishable key, and every
/// credential check happens on the server.
class CloudAuth {
  CloudAuth._(this._client);

  final SupabaseClient _client;

  /// Android returns from the Facebook browser through this deep link (the
  /// matching intent filter is in `android/app/src/main/AndroidManifest.xml`).
  /// On the web the browser simply returns to the page that started the flow.
  static const String androidRedirectUrl = 'skillsbridge://login-callback';

  static bool isConfigured({required String url, required String key}) =>
      url.trim().isNotEmpty && key.trim().isNotEmpty;

  /// Initialises the SDK once per process and restores a previous session, so
  /// a learner who signed in on this device stays signed in across reloads.
  static Future<CloudAuth> initialize({
    required String url,
    required String key,
  }) async {
    await Supabase.initialize(url: url.trim(), publishableKey: key.trim());
    return CloudAuth._(Supabase.instance.client);
  }

  Session? get currentSession => _client.auth.currentSession;

  /// Emits whenever a session becomes available: an email sign-in, a restored
  /// session, or the moment Facebook hands control back to the app.
  Stream<CloudUser> get userEvents => _client.auth.onAuthStateChange
      .where((state) => state.session != null)
      .map((state) => userFrom(state.session!));

  CloudUser userFrom(Session session) => CloudUser(
    name: _name(session.user),
    email: session.user.email ?? '',
    role: _role(session.user),
    token: session.accessToken,
    guardianEmail: _guardianEmail(session.user),
  );

  Future<CloudUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _guard(
      () => _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ),
    );
    final session = response.session ?? _client.auth.currentSession;
    if (session == null) {
      throw const CloudAuthException(
        'Sign-in did not complete. Please try again.',
      );
    }
    return userFrom(session);
  }

  Future<CloudUser> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _guard(
      () => _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, Object?>{'name': name.trim(), 'role': role},
      ),
    );
    final session = response.session ?? _client.auth.currentSession;
    if (session == null) {
      // Email confirmation is on: the account exists, but there is no session
      // to open the app with yet.
      throw CloudAuthException(
        'Account created. Open the confirmation link sent to ${email.trim()}, then sign in.',
      );
    }
    return userFrom(session);
  }

  /// Opens Facebook's consent screen.
  ///
  /// The web build navigates away and comes back to the same page; Android
  /// leaves for the browser and returns through [androidRedirectUrl]. The
  /// session arrives on [userEvents] in both cases.
  Future<bool> signInWithFacebook() => _guard(
    () => _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: kIsWeb ? null : androidRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    ),
  );

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      // Signing out locally must succeed even if the server is unreachable.
      debugPrint('Cloud sign-out failed: $e');
    }
  }

  String _name(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    for (final key in const <String>['name', 'full_name', 'display_name']) {
      final value = metadata[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final email = user.email ?? '';
    return email.isEmpty ? 'Learner' : email.split('@').first;
  }

  String _role(User user) {
    final trustedRole = user.appMetadata['role']?.toString();
    if (trustedRole == 'student') return 'student';
    if (trustedRole == 'guardian') return 'guardian';
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return metadata['role']?.toString() == 'guardian' ? 'guardian' : 'student';
  }

  String? _guardianEmail(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final email = metadata['guardian_email']?.toString().trim() ?? '';
    return email.isEmpty ? null : email;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw CloudAuthException(_messageFor(e.message));
    } catch (e) {
      debugPrint('Cloud auth error: $e');
      throw const CloudAuthException(
        'We could not reach the sign-in service. Check your connection.',
      );
    }
  }

  /// Server messages become sentences a learner can act on.
  String _messageFor(String message) {
    final text = message.toLowerCase();
    if (text.contains('invalid login credentials') ||
        text.contains('invalid_credentials')) {
      return 'That email and password do not match an account.';
    }
    if (text.contains('email not confirmed') ||
        text.contains('email_not_confirmed')) {
      return 'Confirm your email first — open the link we sent, then sign in.';
    }
    if (text.contains('already registered') ||
        text.contains('user_already_exists')) {
      return 'An account with that email already exists. Sign in instead.';
    }
    if (text.contains('password')) {
      return 'Use a password with at least 6 characters.';
    }
    if (text.contains('provider is not enabled')) {
      return 'Facebook sign-in is not switched on yet for this build.';
    }
    return message;
  }
}
