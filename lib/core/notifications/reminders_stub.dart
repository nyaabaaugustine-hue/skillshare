import 'reminder_gateway.dart';

/// Web / unsupported-platform reminders: deliberately do nothing.
///
/// The web build still calls every method in [ReminderService], so the API has
/// to exist; it simply cannot put anything in the operating system's
/// notification tray.
class Reminders implements ReminderGateway {
  Reminders();

  static Future<Reminders> create() async => Reminders();

  @override
  bool get supported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleComeback({
    required Duration after,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelComeback() async {}

  @override
  Future<void> cancelAll() async {}
}
