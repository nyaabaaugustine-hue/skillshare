import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Parent / Guardian login that is created together with a student
/// account.
///
/// Families never register a second account and never have to connect anything
/// by hand: the guardian signs in with [guardianLogin] / their password and
/// lands straight on the linked learner's progress.
///
/// Only a salted hash of the password is kept on the device; the plaintext is
/// shown once, right after registration (see [GuardianCredentials]).
class FamilyLink {
  const FamilyLink({
    required this.studentName,
    required this.studentEmail,
    required this.guardianName,
    required this.guardianEmail,
    required this.guardianLogin,
    required this.passwordSalt,
    required this.passwordHash,
    this.learnerRef = '',
  });

  final String studentName;
  final String studentEmail;
  final String guardianName;

  /// Where progress reports are emailed. Empty means no reports.
  final String guardianEmail;

  final String guardianLogin;

  /// Local learner id this link belongs to, so a report is never sent to the
  /// wrong family on a shared classroom device.
  final String learnerRef;
  final String passwordSalt;
  final String passwordHash;

  /// Builds a link and hashes [password] with a fresh random salt.
  factory FamilyLink.create({
    required String studentName,
    required String studentEmail,
    required String guardianName,
    required String guardianEmail,
    required String guardianLogin,
    required String password,
    String learnerRef = '',
    Random? random,
  }) {
    final salt = newSalt(random);
    return FamilyLink(
      studentName: studentName,
      studentEmail: studentEmail,
      guardianName: guardianName,
      guardianEmail: guardianEmail,
      guardianLogin: guardianLogin,
      learnerRef: learnerRef,
      passwordSalt: salt,
      passwordHash: hashPassword(password, salt),
    );
  }

  factory FamilyLink.fromJson(Map<String, Object?> json) {
    // Links written before guardian emails existed stored the contact under
    // `guardianContact`; adopt it only when it actually is an email address.
    final legacy = json['guardianContact'] as String? ?? '';
    final stored = json['guardianEmail'] as String? ?? '';
    final email = stored.isNotEmpty
        ? stored
        : (legacy.contains('@') ? legacy : '');
    return FamilyLink(
      studentName: json['studentName'] as String? ?? '',
      studentEmail: json['studentEmail'] as String? ?? '',
      guardianName: json['guardianName'] as String? ?? '',
      guardianEmail: email,
      guardianLogin: json['guardianLogin'] as String? ?? '',
      learnerRef: json['learnerRef'] as String? ?? '',
      passwordSalt: json['passwordSalt'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'studentName': studentName,
        'studentEmail': studentEmail,
        'guardianName': guardianName,
        'guardianEmail': guardianEmail,
        'guardianLogin': guardianLogin,
        'learnerRef': learnerRef,
        'passwordSalt': passwordSalt,
        'passwordHash': passwordHash,
      };

  bool matchesLogin(String identifier) =>
      guardianLogin.toLowerCase() == identifier.trim().toLowerCase();

  bool matchesStudentEmail(String email) =>
      studentEmail.toLowerCase() == email.trim().toLowerCase();

  bool verifyPassword(String password) =>
      hashPassword(password, passwordSalt) == passwordHash;

  /// Same link with a newly generated password (used when the family asks for
  /// a fresh guardian password).
  FamilyLink withPassword(String password, {Random? random}) {
    final salt = newSalt(random);
    return FamilyLink(
      studentName: studentName,
      studentEmail: studentEmail,
      guardianName: guardianName,
      guardianEmail: guardianEmail,
      guardianLogin: guardianLogin,
      learnerRef: learnerRef,
      passwordSalt: salt,
      passwordHash: hashPassword(password, salt),
    );
  }

  /// Hash of `salt + password`; never stores or logs the plaintext.
  static String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  /// `<guardian.name>.parent<nnn>`, lower-case and ASCII-safe.
  static String generateLogin({required String guardianName, Random? random}) {
    final rng = random ?? Random.secure();
    final slug = guardianName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    final base = slug.isEmpty ? 'guardian' : slug;
    return '$base.parent${100 + rng.nextInt(900)}';
  }

  /// Readable password such as `Meadow-7314`.
  static String generatePassword([Random? random]) {
    final rng = random ?? Random.secure();
    final word = _passwordWords[rng.nextInt(_passwordWords.length)];
    return '$word-${1000 + rng.nextInt(9000)}';
  }

  static String newSalt([Random? random]) {
    final rng = random ?? Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(16))
        .map((n) => n.toRadixString(16))
        .join();
  }

  static const List<String> _passwordWords = <String>[
    'Bridge',
    'Python',
    'Rocket',
    'Sunrise',
    'Meadow',
    'Comet',
    'Lantern',
    'Harbor',
    'Summit',
    'Cactus',
  ];
}

/// One-time credentials handed to the family right after registration.
class GuardianCredentials {
  const GuardianCredentials({
    required this.name,
    required this.login,
    required this.password,
  });

  final String name;
  final String login;
  final String password;
}

/// Device-local directory of student -> guardian links.
///
/// Sign-in consults it, so a guardian login resolves to the right learner with
/// no separate "connect accounts" step.
class FamilyLinkStore {
  static const String _key = 'family.links';

  Future<List<FamilyLink>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const <FamilyLink>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <FamilyLink>[];
      return <FamilyLink>[
        for (final entry in decoded)
          if (entry is Map)
            FamilyLink.fromJson(Map<String, Object?>.from(entry)),
      ];
    } catch (_) {
      // A corrupt entry must never block sign-in.
      return const <FamilyLink>[];
    }
  }

  /// Adds [link], replacing any earlier link for the same guardian login or the
  /// same student email.
  Future<void> save(FamilyLink link) async {
    final existing = await all();
    final kept = existing.where(
      (l) =>
          !l.matchesLogin(link.guardianLogin) &&
          !(link.studentEmail.isNotEmpty && l.matchesStudentEmail(link.studentEmail)),
    );
    await _write(<FamilyLink>[link, ...kept]);
  }

  Future<FamilyLink?> findByLogin(String identifier) async {
    final links = await all();
    for (final link in links) {
      if (link.matchesLogin(identifier)) return link;
    }
    return null;
  }

  /// The link owned by [learnerRef] on this device, if there is one.
  Future<FamilyLink?> findByLearner(String learnerRef) async {
    if (learnerRef.trim().isEmpty) return null;
    final links = await all();
    for (final link in links) {
      if (link.learnerRef == learnerRef) return link;
    }
    return null;
  }

  Future<FamilyLink?> findByStudentEmail(String email) async {
    final links = await all();
    for (final link in links) {
      if (link.matchesStudentEmail(email)) return link;
    }
    return null;
  }

  Future<void> _write(List<FamilyLink> links) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(<Object?>[for (final link in links) link.toJson()]),
      );
    } catch (_) {
      // Storage problems must not block registration or sign-in.
    }
  }
}
