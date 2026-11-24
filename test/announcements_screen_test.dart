import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/messages/announcement.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_controller.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_repository.dart';
import 'package:skillbridge_python_lab/features/messages/announcements_screen.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_detail_screen.dart';
import 'package:skillbridge_python_lab/features/messages/push_message.dart';

class _AuthStub extends AuthController {
  _AuthStub({required this.signedIn});

  final bool signedIn;

  @override
  AuthSession? get session => signedIn
      ? const AuthSession(
          signedIn: true,
          name: 'Learner',
          email: 'learner@example.com',
          token: 'token',
        )
      : null;
}

class _Repo implements AnnouncementRepository {
  _Repo(this.page);

  final AnnouncementPage page;
  final List<String> markedRead = <String>[];
  int listCalls = 0;

  @override
  Future<AnnouncementPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    return page;
  }

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
  }
}

Widget _wrap({
  required Widget child,
  required AuthController auth,
  required AnnouncementController controller,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController?>.value(value: auth),
      ChangeNotifierProvider<AnnouncementController>.value(value: controller),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('inbox loads announcements for a signed-in account', (
    tester,
  ) async {
    final repo = _Repo(
      AnnouncementPage(
        items: [
          Announcement(
            id: 'a1',
            title: 'Admin update',
            body: 'The lab maintenance is finished.',
            audience: 'all',
            createdAt: DateTime(2026, 11, 22, 10),
          ),
        ],
        nextCursor: null,
      ),
    );
    final controller = AnnouncementController(repository: repo);

    await tester.pumpWidget(
      _wrap(
        child: const AnnouncementsScreen(),
        auth: _AuthStub(signedIn: true),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.textContaining('Admin update'), findsOneWidget);
    expect(repo.listCalls, 1);
  });

  testWidgets('inbox asks guests to sign in without calling the API', (
    tester,
  ) async {
    final repo = _Repo(const AnnouncementPage(items: [], nextCursor: null));
    final controller = AnnouncementController(repository: repo);

    await tester.pumpWidget(
      _wrap(
        child: const AnnouncementsScreen(),
        auth: _AuthStub(signedIn: false),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to see announcements'), findsOneWidget);
    expect(repo.listCalls, 0);
  });

  testWidgets('opening a detail screen marks the announcement read', (
    tester,
  ) async {
    final repo = _Repo(const AnnouncementPage(items: [], nextCursor: null));
    final controller = AnnouncementController(repository: repo)
      ..applyPush(
        const PushMessage(id: 'a1', title: 'Admin update', body: 'Body'),
      );

    await tester.pumpWidget(
      _wrap(
        child: const AnnouncementDetailScreen(id: 'a1'),
        auth: _AuthStub(signedIn: true),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin update'), findsOneWidget);
    expect(repo.markedRead, ['a1']);
  });
}
