import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillbridge_python_lab/features/auth/cloud_auth.dart';

class _MemoryCookieStore implements AuthCookieStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  test(
    'can initialize the sign-in client without restoring a session first',
    () async {
      var requests = 0;
      final auth = await CloudAuth.initialize(
        baseUrl: 'https://auth.example.test',
        cookieStore: _MemoryCookieStore(),
        client: MockClient((_) async {
          requests++;
          return http.Response('null', 503);
        }),
        restoreExistingSession: false,
      );
      addTearDown(auth.dispose);

      expect(requests, 0);
    },
  );

  test(
    'registers, verifies, and invites a guardian through Neon Auth',
    () async {
      final requests = <http.Request>[];
      final user = <String, Object?>{
        'id': 'student-1',
        'name': 'Student Name',
        'email': 'student@example.com',
        'emailVerified': false,
      };
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'o': <String, Object?>{'role': 'owner'},
              }),
            ),
          )
          .replaceAll('=', '');
      final responses = <http.Response>[
        http.Response(jsonEncode(<String, Object?>{'user': user}), 200),
        http.Response('{}', 200),
        http.Response('{}', 200),
        http.Response(
          jsonEncode(<String, Object?>{
            'user': user,
            'session': <String, Object?>{},
          }),
          200,
        ),
        http.Response(jsonEncode(<String, Object?>{'data': <Object?>[]}), 200),
        http.Response(jsonEncode(<String, Object?>{'id': 'family-1'}), 200),
        http.Response('{}', 200),
        http.Response('{}', 200),
        http.Response(
          jsonEncode(<String, Object?>{
            'user': user,
            'session': <String, Object?>{'activeOrganizationId': 'family-1'},
          }),
          200,
          headers: <String, String>{'set-auth-jwt': 'header.$payload.signature'},
        ),
      ];
      final auth = await CloudAuth.initialize(
        baseUrl: 'https://auth.example.test',
        cookieStore: _MemoryCookieStore(),
        client: MockClient((request) async {
          requests.add(request);
          return responses.removeAt(0);
        }),
        restoreExistingSession: false,
      );
      addTearDown(auth.dispose);

      await expectLater(
        auth.register(
          name: ' Student Name ',
          email: ' Student@Example.com ',
          password: 'StrongPassword123',
          role: 'student',
          guardianEmail: ' Parent@Example.com ',
        ),
        throwsA(
          isA<CloudAuthException>().having(
            (error) => error.needsEmailVerification,
            'needsEmailVerification',
            isTrue,
          ),
        ),
      );

      final signedIn = await auth.verifyEmail(
        email: ' Student@Example.com ',
        otp: '123456',
      );

      expect(signedIn.email, 'student@example.com');
      expect(signedIn.role, 'student');
      expect(requests.map((request) => request.url.path), <String>[
        '/api/auth/sign-up/email',
        '/api/auth/email-otp/send-verification-otp',
        '/api/auth/email-otp/verify-email',
        '/api/auth/get-session',
        '/api/auth/organization/list',
        '/api/auth/organization/create',
        '/api/auth/organization/set-active',
        '/api/auth/organization/invite-member',
        '/api/auth/get-session',
      ]);
      expect(jsonDecode(requests.first.body)['email'], 'student@example.com');
      expect(jsonDecode(requests[1].body)['email'], 'student@example.com');
      expect(jsonDecode(requests[7].body)['email'], 'parent@example.com');
      expect(responses, isEmpty);
    },
  );

  test('one account signs in with the same email and password as the web', () async {
    final user = <String, Object?>{
      'id': 'student-1',
      'name': 'Student Name',
      'email': 'student@example.com',
      'emailVerified': true,
    };
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(<String, Object?>{'sub': 'student-1'})))
        .replaceAll('=', '');
    final requests = <http.Request>[];
    final responses = <http.Response>[
      http.Response('{}', 200),
      http.Response(
        jsonEncode(<String, Object?>{
          'user': user,
          'session': <String, Object?>{'activeOrganizationId': 'family-1'},
        }),
        200,
      ),
      http.Response(
        jsonEncode(<String, Object?>{
          'user': user,
          'session': <String, Object?>{'activeOrganizationId': 'family-1'},
        }),
        200,
      ),
      // The tutor JWT comes from the Better Auth `/token` route: `session.token`
      // from `get-session` is an opaque session id the Worker cannot verify.
      http.Response(
        jsonEncode(<String, Object?>{'token': 'header.$payload.signature'}),
        200,
      ),
    ];
    final auth = await CloudAuth.initialize(
      baseUrl: 'https://auth.example.test',
      cookieStore: _MemoryCookieStore(),
      client: MockClient((request) async {
        requests.add(request);
        return responses.removeAt(0);
      }),
      restoreExistingSession: false,
    );
    addTearDown(auth.dispose);

    final signedIn = await auth.signIn(
      email: ' Student@Example.com ',
      password: 'StrongPassword123',
    );

    expect(signedIn.email, 'student@example.com');
    expect(signedIn.role, 'student');
    expect(requests.map((request) => request.url.path), <String>[
      '/api/auth/sign-in/email',
      '/api/auth/get-session',
      '/api/auth/get-session',
      '/api/auth/token',
    ]);
    expect(requests.first.url.path, '/api/auth/sign-in/email');
    expect(jsonDecode(requests.first.body), <String, Object?>{
      'email': 'student@example.com',
      'password': 'StrongPassword123',
    });
    expect(responses, isEmpty);
  });

  test('a failed family-group lookup does not turn a valid login into an error', () async {
    final user = <String, Object?>{
      'id': 'student-1',
      'name': 'Student Name',
      'email': 'student@example.com',
      'emailVerified': true,
    };
    final responses = <http.Response>[
      http.Response('{}', 200),
      http.Response(
        jsonEncode(<String, Object?>{'user': user, 'session': <String, Object?>{}}),
        200,
      ),
      http.Response('{"message":"plugin disabled"}', 400),
      http.Response(
        jsonEncode(<String, Object?>{'user': user, 'session': <String, Object?>{}}),
        200,
      ),
      http.Response(
        jsonEncode(<String, Object?>{'token': 'header.payload.signature'}),
        200,
      ),
    ];
    final auth = await CloudAuth.initialize(
      baseUrl: 'https://auth.example.test',
      cookieStore: _MemoryCookieStore(),
      client: MockClient((request) async => responses.removeAt(0)),
      restoreExistingSession: false,
    );
    addTearDown(auth.dispose);

    final signedIn = await auth.signIn(
      email: 'student@example.com',
      password: 'StrongPassword123',
    );

    expect(signedIn.email, 'student@example.com');
    expect(responses, isEmpty);
  });
}
