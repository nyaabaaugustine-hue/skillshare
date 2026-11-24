import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../messages/announcement.dart';
import '../messages/announcement_repository.dart';
import '../messages/push_message.dart';

/// Inbox state. Screens never call the API directly; they observe this.
class AnnouncementController extends ChangeNotifier {
  AnnouncementController({required this.repository});

  final AnnouncementRepository repository;

  final List<Announcement> _items = <Announcement>[];
  String? _nextCursor;
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  List<Announcement> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  bool get loaded => _loaded;
  String? get error => _error;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Announcement? find(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> load({bool refresh = false}) async {
    if (_busy) return;
    if (refresh) {
      _items.clear();
      _nextCursor = null;
      _loaded = false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.list(
        limit: 20,
        cursor: refresh ? null : _nextCursor,
      );
      if (refresh) {
        _items
          ..clear()
          ..addAll(page.items);
      } else {
        final known = _items.map((item) => item.id).toSet();
        for (final item in page.items) {
          if (!known.contains(item.id)) _items.add(item);
        }
      }
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _nextCursor = page.nextCursor;
      _loaded = true;
    } catch (error) {
      _error = error is AppException
          ? error.userMessage
          : 'Announcements could not be loaded right now.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_busy || _nextCursor == null) return;
    await load();
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final previous = _items[index];
    if (previous.isRead) return;

    _items[index] = previous.copyWith(readAt: DateTime.now());
    notifyListeners();
    try {
      await repository.markRead(id);
    } catch (error) {
      _items[index] = previous;
      _error = 'We could not mark that announcement as read.';
      notifyListeners();
      debugPrint('Could not mark announcement read: $error');
    }
  }

  /// Inserts a message delivered by FCM so a notification tap has something to
  /// show even before the next inbox fetch.
  void applyPush(PushMessage message) {
    final index = _items.indexWhere((item) => item.id == message.id);
    if (index >= 0) return;
    _items.insert(0, Announcement.fromPush(message));
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
