import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_gateway.dart';

/// Native reminders using the OS notification tray.
///
/// Two reminders are used, each with a stable id so a new one replaces the old
/// rather than stacking up:
///
/// * **daily** — the learner's chosen study time, rescheduled on every launch
///   and after every finished step. It fires on a day they have not learned.
/// * **comeback** — three hours after a lesson is opened, cancelled the moment
///   the step is finished. This is the "you stopped halfway" nudge.
///
/// The channel uses a bundled chime (`res/raw/reminder_chime.wav`). Android
/// fixes a channel's sound when it is created, so any change to the sound needs
/// a new channel id — hence `_channelId` carries a version suffix.
class Reminders implements ReminderGateway {
  Reminders();

  static const String _channelId = 'skillbridge_reminders_v1';
  static const String _channelName = 'Learning reminders';
  static const String _channelDescription =
      'Reminds you to keep learning when you skip or stop a lesson.';
  static const int _dailyId = 1001;
  static const int _comebackId = 1002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _timezoneReady = false;

  final StreamController<String> _opened = StreamController<String>.broadcast();

  static Future<Reminders> create() async => Reminders();

  @override
  Stream<String> get opened => _opened.stream;

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      // Bundled tone so a reminder is recognisably SkillBridge, not the
      // system default beep.
      sound: RawResourceAndroidNotificationSound('reminder_chime'),
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  @override
  Future<void> initialize() async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          // Reminders use the payload 'reminder'; only announcement heads-ups
          // carry an id the router can open.
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty && payload != 'reminder') {
            _opened.add(payload);
          }
        },
      );
      await _prepareTimezone();
      _ready = true;
    } catch (error) {
      debugPrint('Reminders unavailable on this device: $error');
    }
  }

  /// Sets the local zone from the device's current UTC offset.
  ///
  /// This deliberately avoids a timezone-lookup plugin (the previous choice
  /// compiled Kotlin 1.8 against this project's Java 11 target and broke the
  /// Android build). The cost is honest: in a region with daylight saving, a
  /// reminder scheduled before a clock change can land an hour out. For a fixed
  /// offset — which includes Ghana and most of the app's current users — it is
  /// exact.
  Future<void> _prepareTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inMinutes ~/ 60;
      // Etc/GMT signs are inverted: Etc/GMT-1 is UTC+1.
      final name = hours == 0
          ? 'Etc/GMT'
          : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
      tz.setLocalLocation(tz.getLocation(name));
      _timezoneReady = true;
    } catch (error) {
      // Fall back to UTC rather than dropping every reminder: the time may be
      // off, but the reminder still arrives.
      debugPrint('Timezone setup failed, using UTC: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _scheduleAt(
      id: _dailyId,
      when: _nextOccurrence(hour: hour, minute: minute),
      title: title,
      body: body,
    );
  }

  @override
  Future<void> scheduleComeback({
    required Duration after,
    required String title,
    required String body,
  }) async {
    await _scheduleAt(
      id: _comebackId,
      when: tz.TZDateTime.now(tz.local).add(after),
      title: title,
      body: body,
    );
  }

  Future<void> _scheduleAt({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'reminder',
      );
    } catch (error) {
      debugPrint('Could not schedule reminder $id: $error');
    }
  }

  /// Today at [hour]:[minute] if that is still ahead, otherwise tomorrow.
  tz.TZDateTime _nextOccurrence({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  @override
  Future<void> cancelComeback() async {
    if (!supported) return;
    try {
      await _plugin.cancel(_comebackId);
    } catch (error) {
      debugPrint('Could not cancel comeback reminder: $error');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!supported) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel reminders: $error');
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!supported) return;
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.show(id, title, body, _details, payload: payload);
    } catch (error) {
      debugPrint('Could not show announcement notification: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_opened.close());
  }
}
