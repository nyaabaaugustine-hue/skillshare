import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/network/http_client_factory.dart';

/// A shared Neon Auth identity used by the website and Flutter clients.
class CloudUser {
  const CloudUser({
    this.id = '',
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.guardianEmail,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? token;
  final String? guardianEmail;
}

class CloudAuthException implements Exception {
  const CloudAuthException(this.message, {this.needsEmailVerification = false});

  final String message;
  final bool needsEmailVerification;

  @override
  String toString() => message;
}

/// Injectable cookie storage makes native session persistence testable. The
/// production implementation uses Android Keystore/iOS Keychain (and the
/// secure-storage package's WebCrypto-backed web implementation).
abstract interface class AuthCookieStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureAuthCookieStore implements AuthCookieStore {
  SecureAuthCookieStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'neon_auth.session_cookie';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Thin Better Auth-compatible client for the website's `/api/auth` proxy.
///
/// No database URL, service key, or server secret is used here. Native clients
/// persist only the opaque session cookie in secure storage; browser clients
/// use the browser's credentialed cookie jar. The API origin must be HTTPS in
/// production and must be the same trusted website origin used by web sign-in.
class CloudAuth {
  // Positional initializing formals, because named parameters cannot start
  // with an underscore.
  CloudAuth._(this.baseUrl, this._cookieStore, this._http);

  final String baseUrl;
  final AuthCookieStore _cookieStore;
  final http.Client _http;
  final StreamController<CloudUser> _events =
      StreamController<CloudUser>.broadcast();
  CloudUser? _currentSession;
  bool _pendingStudentSignup = false;
  String? _pendingGuardianEmail;

  CloudUser? get currentSession => _currentSession;
  Stream<CloudUser> get userEvents => _events.stream;

  /// The website origin sent as `Origin` on native requests.
  ///
  /// Native HTTP sends no `Origin` header at all, and Neon Auth rejects a
  /// sign-in that arrives without a trusted origin (`INVALID_ORIGIN`). Sending
  /// the website's own origin makes the request match the origin allowlisted on
  /// both the website proxy and the Neon Auth branch. Browsers set `Origin`
  /// themselves (and forbid overriding it), so this is native-only.
  String get requestOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    if (uri.scheme != 'http' && uri.scheme != 'https') return baseUrl;
    return uri.origin.isEmpty ? baseUrl : uri.origin;
  }

  static bool isConfigured({required String baseUrl}) =>
      baseUrl.trim().isNotEmpty;

  static Future<CloudAuth> initialize({
    required String baseUrl,
    AuthCookieStore? cookieStore,
    http.Client? client,
    bool restoreExistingSession = true,
  }) async {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final auth = CloudAuth._(
      normalized,
      cookieStore ?? SecureAuthCookieStore(),
      client ?? createHttpClient(),
    );
    if (restoreExistingSession) await auth.restoreSession();
    return auth;
  }

  /// Restores the web cookie or securely stored native cookie and refreshes the
  /// short-lived access JWT. A missing/expired session is a normal signed-out
  /// result, not a startup failure.
  Future<CloudUser?> restoreSession() async {
    try {
      final payload = await _request('GET', 'get-session');
      var user = _findUser(payload);
      if (user == null) {
        _currentSession = null;
        return null;
      }
      await _activateSoleFamily(payload);
      final refreshed = await _request('GET', 'get-session');
      user = _findUser(refreshed) ?? user;
      final token = await _getAccessToken();
      final resolved = _cloudUser(user, token);
      _currentSession = resolved;
      _events.add(resolved);
      return resolved;
    } on CloudAuthException catch (error) {
      if (error.message.toLowerCase().contains('unauthorized') ||
          error.message.toLowerCase().contains('session')) {
        _currentSession = null;
        await _cookieStore.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<CloudUser> signIn({
    required String email,
    required String password,
  }) async {
    _pendingStudentSignup = false;
    _pendingGuardianEmail = null;
    await _request('POST', 'sign-in/email', <String, Object?>{
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return _loadAuthenticatedUser();
  }

  Future<CloudUser> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String guardianEmail = '',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    _pendingStudentSignup = role == 'student';
    _pendingGuardianEmail = guardianEmail.trim().isEmpty
        ? null
        : guardianEmail.trim().toLowerCase();
    final result = await _request('POST', 'sign-up/email', <String, Object?>{
      'email': normalizedEmail,
      'password': password,
      'name': name.trim(),
    });
    final user = _findUser(result);
    if (user != null && user['emailVerified'] == true) {
      return _loadAuthenticatedUser();
    }

    // Use the same email-code flow as the website; do not silently create a
    // device-only account when verification is enabled.
    await sendVerificationCode(normalizedEmail);
    throw CloudAuthException(
      'verification_required',
      needsEmailVerification: true,
    );
  }

  Future<void> sendVerificationCode(String email) async {
    await _request('POST', 'email-otp/send-verification-otp', <String, Object?>{
      'email': email.trim().toLowerCase(),
      'type': 'email-verification',
    });
  }

  Future<CloudUser> verifyEmail({
    required String email,
    required String otp,
  }) async {
    await _request('POST', 'email-otp/verify-email', <String, Object?>{
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
    return _loadAuthenticatedUser();
  }

  Future<CloudUser> _loadAuthenticatedUser() async {
    var payload = await _request('GET', 'get-session');
    var user = _findUser(payload);
    if (user == null) {
      throw const CloudAuthException(
        'Your email was verified. Sign in to continue.',
      );
    }
    if (_pendingStudentSignup) {
      await _createStudentFamily(user);
      _pendingStudentSignup = false;
      _pendingGuardianEmail = null;
      payload = await _request('GET', 'get-session');
      user = _findUser(payload) ?? user;
    } else {
      await _activateSoleFamily(payload);
      payload = await _request('GET', 'get-session');
      user = _findUser(payload) ?? user;
    }
    final token = await _getAccessToken();
    final resolved = _cloudUser(user, token);
    _currentSession = resolved;
    _events.add(resolved);
    return resolved;
  }

  /// Mints a fresh access JWT without changing the signed-in user.
  ///
  /// The tutor client calls this when its token is about to expire or the
  /// Worker answered 401, instead of reusing the token captured at sign-in.
  Future<String> refreshAccessToken() async {
    final token = await _getAccessToken();
    final current = _currentSession;
    if (current != null) {
      _currentSession = CloudUser(
        id: current.id,
        name: current.name,
        email: current.email,
        role: current.role,
        token: token,
        guardianEmail: current.guardianEmail,
      );
      _events.add(_currentSession!);
    }
    return token;
  }

  Future<String> _getAccessToken() async {
    final payload = await _request('POST', 'get-access-token', <String, Object?>{});
    final nested = payload['data'];
    final token = payload['token'] ?? payload['accessToken'] ??
        (nested is Map ? nested['token'] ?? nested['accessToken'] : null);
    if (token is! String || token.isEmpty) {
      throw const CloudAuthException(
        'The sign-in service did not return a tutor access token.',
      );
    }
    return token;
  }

  Future<void> _createStudentFamily(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw const CloudAuthException('Could not identify the student account.');
    }
    final suffix = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final slug = 'family-${suffix.isEmpty ? 'student' : suffix}';
    var organizations = await _organizationList();
    final matches = organizations.where((item) => item['slug'] == slug).toList();
    Map<String, dynamic>? family = matches.isEmpty ? null : matches.first;
    if (family == null) {
      final created = await _request('POST', 'organization/create', <String, Object?>{
        'name': "${(user['name'] ?? 'Student').toString()}'s Family",
        'slug': slug,
      });
      family = _organizationFrom(created);
      if (family == null) {
        organizations = await _organizationList();
        final afterCreate = organizations.where((item) => item['slug'] == slug).toList();
        if (afterCreate.isNotEmpty) family = afterCreate.first;
      }
    }
    final organizationId = family?['id']?.toString();
    if (organizationId == null || organizationId.isEmpty) {
      throw const CloudAuthException('Could not create the family group.');
    }
    await _request('POST', 'organization/set-active', <String, Object?>{
      'organizationId': organizationId,
    });
    final guardianEmail = _pendingGuardianEmail;
    if (guardianEmail != null) {
      await _request('POST', 'organization/invite-member', <String, Object?>{
        'email': guardianEmail,
        'role': 'member',
        'organizationId': organizationId,
        'resend': true,
      });
    }
  }

  Future<void> _activateSoleFamily(Map<String, dynamic> payload) async {
    final session = payload['session'];
    if (session is Map && session['activeOrganizationId'] is String) return;
    final organizations = await _organizationList();
    if (organizations.length != 1) return;
    final organizationId = organizations.single['id']?.toString();
    if (organizationId == null || organizationId.isEmpty) return;
    await _request('POST', 'organization/set-active', <String, Object?>{
      'organizationId': organizationId,
    });
  }

  Future<List<Map<String, dynamic>>> _organizationList() async {
    final payload = await _request('GET', 'organization/list');
    final data = payload['data'] ?? payload['organizations'];
    if (data is! List) return const [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Map<String, dynamic>? _organizationFrom(Map<String, dynamic> payload) {
    if (payload['id'] is String) return payload;
    final data = payload['data'];
    if (data is Map && data['id'] is String) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> listOrganizations() => _organizationList();

  /// Neon Auth verifies membership before changing the active family group.
  Future<CloudUser> selectOrganization(String organizationId) async {
    if (organizationId.trim().isEmpty) {
      throw const CloudAuthException('Choose a family group first.');
    }
    await _request('POST', 'organization/set-active', <String, Object?>{
      'organizationId': organizationId,
    });
    return _loadAuthenticatedUser();
  }

  Future<bool> signInWithFacebook() async => false;

  /// Calls an authenticated website API using the shared Neon Auth session.
  /// Native clients send the secure cookie; web uses its credentialed cookie
  /// jar through the conditional HTTP client.
  Future<http.Response> requestSharedApi(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (!path.startsWith('/api/')) {
      throw ArgumentError.value(path, 'path', 'Must be a website API path.');
    }
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (!kIsWeb) {
      final cookie = await _cookieStore.read();
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    }
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      );
      await _captureCookies(response);
      return response;
    } on TimeoutException {
      throw const CloudAuthException('The shared service took too long to respond.');
    } catch (error) {
      if (error is CloudAuthException) rethrow;
      throw const CloudAuthException('The shared service is temporarily unavailable.');
    }
  }

  Future<void> signOut() async {
    try {
      await _request('POST', 'sign-out', <String, Object?>{});
    } catch (error) {
      // A network failure must not retain a local account session.
      debugPrint('Neon Auth sign-out request failed.');
    } finally {
      _currentSession = null;
      await _cookieStore.clear();
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, [
    Map<String, Object?>? body,
  ]) async {
    final uri = Uri.parse('$baseUrl/api/auth/$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (!kIsWeb) {
      headers['Origin'] = requestOrigin;
      final cookie = await _cookieStore.read();
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    }

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      );
    } on TimeoutException {
      throw const CloudAuthException('The sign-in service took too long to respond.');
    } catch (error) {
      if (error is CloudAuthException) rethrow;
      throw const CloudAuthException(
        'We could not reach the sign-in service. Check your connection.',
      );
    }

    await _captureCookies(response);
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : decoded is List
        ? <String, dynamic>{'data': decoded}
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final nested = payload['error'];
      final code =
          (payload['code'] ?? (nested is Map ? nested['code'] : null))
              ?.toString()
              .toUpperCase();
      final message =
          payload['message'] ??
          (nested is Map ? nested['message'] : nested) ??
          'The sign-in service returned an error (${response.statusCode}).';
      final raw = message.toString();
      // Signing in before the email code is used returns EMAIL_NOT_VERIFIED;
      // surface it so the screen offers the code field instead of a dead end.
      throw CloudAuthException(
        _friendlyMessage(raw),
        needsEmailVerification:
            code == 'EMAIL_NOT_VERIFIED' ||
            raw.toLowerCase().contains('not verified'),
      );
    }
    return payload;
  }

  Future<void> _captureCookies(http.Response response) async {
    if (kIsWeb) return; // The browser owns its HttpOnly cookie jar.
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final existing = <String, String>{};
    for (final part in (await _cookieStore.read() ?? '').split(';')) {
      final separator = part.indexOf('=');
      if (separator > 0) {
        existing[part.substring(0, separator).trim()] = part.substring(separator + 1).trim();
      }
    }
    // A comma inside the Expires attribute is not followed by another cookie
    // name/value pair, so this split preserves it while handling combined
    // Set-Cookie headers from the HTTP stack.
    for (final cookie in raw.split(RegExp(r',\s*(?=[^;,\s]+=)'))) {
      final segments = cookie.split(';');
      final pair = segments.first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      final deleted = segments.skip(1).any((attribute) {
        final normalized = attribute.trim().toLowerCase();
        return normalized == 'max-age=0' || normalized.startsWith('max-age=0;');
      });
      if (deleted || value.isEmpty) {
        existing.remove(name);
      } else {
        existing[name] = value;
      }
    }
    if (existing.isEmpty) {
      await _cookieStore.clear();
    } else {
      await _cookieStore.write(
        existing.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
      );
    }
  }

  Map<String, dynamic>? _findUser(Map<String, dynamic> payload) {
    final direct = payload['user'];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    final data = payload['data'];
    if (data is Map) {
      final nested = data['user'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return null;
  }

  CloudUser _cloudUser(Map<String, dynamic> user, String token) {
    final email = user['email'] is String ? user['email'] as String : '';
    final metadata = user['userMetadata'] is Map
        ? Map<String, dynamic>.from(user['userMetadata'] as Map)
        : user['user_metadata'] is Map
        ? Map<String, dynamic>.from(user['user_metadata'] as Map)
        : <String, dynamic>{};
    final displayName = (user['name'] ?? metadata['name'] ?? '').toString().trim();
    final role = _displayRole(token);
    return CloudUser(
      id: user['id']?.toString() ?? '',
      name: displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : 'Learner'),
      email: email,
      role: role,
      token: token,
      guardianEmail: metadata['guardian_email']?.toString(),
    );
  }

  /// This decoding is for UI selection only. The tutor Worker independently
  /// verifies the JWT signature, issuer, audience, and organization role.
  String _displayRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'student';
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final role = (claims['o'] as Map?)?['role'];
      return role == 'member' ? 'guardian' : 'student';
    } catch (_) {
      return 'student';
    }
  }

  String _friendlyMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid origin') || lower.contains('invalid_origin')) {
      return 'Sign-in is blocked for this build because its origin is not '
          'trusted. Add "$requestOrigin" to the allowed origins.';
    }
    if (lower.contains('invalid email or password') ||
        lower.contains('invalid credentials')) {
      return 'That email and password do not match an account.';
    }
    if (lower.contains('already exists') || lower.contains('already registered')) {
      return 'An account with that email already exists. Sign in instead.';
    }
    if (lower.contains('password')) return 'Use a password with at least 6 characters.';
    return message;
  }

  Future<void> dispose() async {
    await _events.close();
    _http.close();
  }
}
