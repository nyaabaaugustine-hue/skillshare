import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillbridge_python_lab/core/notifications/reminder_gateway.dart';
import 'package:skillbridge_python_lab/core/notifications/reminder_service.dart';
import 'package:skillbridge_python_lab/core/storage/settings_repository.dart';

class _FakeGateway implements ReminderGateway {
  _FakeGateway();

  final StreamController<String> _opened = StreamController<String>.broadcast();

  @override
  Stream<String> get opened => _opened.stream;

  bool initialized = false;
  bool permissionAsked = false;
  bool cancelledAll = false;
  bool cancelledComeback = false;

  int? dailyHour;
  int? dailyMinute;
  String? dailyBody;
  Duration? comebackAfter;
  String? comebackTitle;

  @override
  bool get supported => true;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> requestPermission() async {
    permissionAsked = true;
    return true;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    dailyHour = hour;
    dailyMinute = minute;
    dailyBody = body;
  }

  @override
  Future<void> scheduleComeback({
    required Duration after,
    required String title,
    required String body,
  }) async {
    comebackAfter = after;
    comebackTitle = title;
  }

  @override
  Future<void> cancelComeback() async => cancelledComeback = true;

  @override
  Future<void> cancelAll() async => cancelledAll = true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownId = id;
    shownPayload = payload;
  }

  int? shownId;
  String? shownPayload;

  @override
  void dispose() {
    unawaited(_opened.close());
  }
}

Future<(ReminderService, _FakeGateway, SettingsRepository)> _build({
  bool learnedToday = false,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await SettingsRepository.create();
  final gateway = _FakeGateway();
  final service = ReminderService(
    gateway: gateway,
    settings: settings,
    learnedToday: () => learnedToday,
  );
  return (service, gateway, settings);
}

void main() {
  group('ReminderService', () {
    test('bootstrap schedules the daily reminder at the saved time', () async {
      final (service, gateway, _) = await _build();
      await service.bootstrap();

      expect(gateway.initialized, isTrue);
      expect(gateway.permissionAsked, isTrue, reason: 'asked exactly once');
      expect(gateway.dailyHour, 18);
      expect(gateway.dailyMinute, 0);
      expect(gateway.dailyBody, contains('not learned yet'));
    });

    test('a learner who already studied gets tomorrow-toned copy', () async {
      final (service, gateway, _) = await _build(learnedToday: true);
      await service.bootstrap();
      expect(gateway.dailyBody, contains('next nudge is tomorrow'));
    });

    test('opening a lesson arms a three-hour comeback reminder', () async {
      final (service, gateway, _) = await _build();
      await service.onLessonOpened('Practice: Your First Output');

      expect(gateway.comebackAfter, const Duration(hours: 3));
      expect(gateway.comebackTitle, contains('Your First Output'));
    });

    test(
      'finishing a step clears the comeback and re-schedules tomorrow',
      () async {
        final (service, gateway, _) = await _build();
        await service.onStepCompleted();

        expect(gateway.cancelledComeback, isTrue);
        expect(gateway.dailyHour, 18);
      },
    );

    test('turning reminders off cancels everything still pending', () async {
      final (service, gateway, settings) = await _build();
      await service.setEnabled(false);

      expect(settings.reminderEnabled, isFalse);
      expect(gateway.cancelledAll, isTrue);
      expect(gateway.dailyHour, isNull);
    });

    test(
      'changing the time re-schedules without asking permission again',
      () async {
        final (service, gateway, settings) = await _build(
          prefs: <String, Object>{'reminder_permission_asked': true},
        );
        await service.setTime(hour: 7, minute: 30);

        expect(settings.reminderHour, 7);
        expect(settings.reminderMinute, 30);
        expect(gateway.dailyHour, 7);
        expect(gateway.dailyMinute, 30);
        expect(gateway.permissionAsked, isFalse);
      },
    );

    test('foreground announcements post a heads-up with their id', () async {
      final (service, gateway, _) = await _build();
      await service.showHeadsUp(
        id: 2042,
        title: 'New announcement',
        body: 'Read it now',
        payload: 'ann-42',
      );

      expect(gateway.shownId, 2042);
      expect(gateway.shownPayload, 'ann-42');
    });

    test('learnedOn only matches the same calendar day', () {
      final now = DateTime(2026, 11, 16, 20);
      expect(
        ReminderService.learnedOn(<DateTime>[DateTime(2026, 11, 16)], now),
        isTrue,
      );
      expect(
        ReminderService.learnedOn(<DateTime>[DateTime(2026, 11, 15)], now),
        isFalse,
      );
    });
  });
}
