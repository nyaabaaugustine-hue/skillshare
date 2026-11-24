import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/messages/announcement.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_controller.dart';
import 'package:skillbridge_python_lab/features/messages/announcement_repository.dart';
import 'package:skillbridge_python_lab/features/messages/push_message.dart';

class _FakeRepository implements AnnouncementRepository {
  _FakeRepository(this.pages);

  final List<AnnouncementPage> pages;
  final List<String> markedRead = <String>[];
  bool failMarkRead = false;
  int calls = 0;

  @override
  Future<AnnouncementPage> list({int limit = 20, String? cursor}) async {
    final page = pages[calls.clamp(0, pages.length - 1)];
    calls++;
    return page;
  }

  @override
  Future<void> markRead(String id) async {
    if (failMarkRead) throw StateError('offline');
    markedRead.add(id);
  }
}

Announcement _announcement(String id, {DateTime? createdAt}) => Announcement(
  id: id,
  title: 'Title $id',
  body: 'Body $id',
  audience: 'all',
  createdAt: createdAt ?? DateTime(2026, 11, 20, 9),
);

void main() {
  test('load sorts newest first and counts unread announcements', () async {
    final repository = _FakeRepository([
      AnnouncementPage(
        items: [
          _announcement('old', createdAt: DateTime(2026, 11, 19)),
          _announcement('new', createdAt: DateTime(2026, 11, 21)),
        ],
        nextCursor: null,
      ),
    ]);
    final controller = AnnouncementController(repository: repository);

    await controller.load();

    expect(controller.items.map((item) => item.id), ['new', 'old']);
    expect(controller.unreadCount, 2);
    expect(controller.loaded, isTrue);
    expect(controller.error, isNull);
  });

  test('markRead is optimistic and rolls back when the API fails', () async {
    final repository = _FakeRepository([
      AnnouncementPage(items: [_announcement('a1')], nextCursor: null),
    ]);
    final controller = AnnouncementController(repository: repository);
    await controller.load();
    repository.failMarkRead = true;

    await controller.markRead('a1');

    expect(controller.unreadCount, 1);
    expect(controller.error, contains('could not mark'));
    expect(repository.markedRead, isEmpty);
  });

  test(
    'an FCM push is inserted once and opens without an inbox fetch',
    () async {
      final repository = _FakeRepository([
        const AnnouncementPage(items: [], nextCursor: null),
      ]);
      final controller = AnnouncementController(repository: repository);
      final push = PushMessage(
        id: 'push-1',
        title: 'Scheduled maintenance',
        body: 'The lab will be unavailable at midnight.',
      );

      controller
        ..applyPush(push)
        ..applyPush(push);

      expect(controller.items, hasLength(1));
      expect(controller.find('push-1')?.title, 'Scheduled maintenance');
      expect(repository.calls, 0);
    },
  );
}
