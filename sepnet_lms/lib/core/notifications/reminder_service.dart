import 'package:skillbridge_python_lab/core/storage/settings_repository.dart';

import 'reminder_gateway.dart';

/// Decides *when* the learner should be reminded, and keeps the two scheduled
/// notifications in step with what they actually did.
///
/// Rules:
///
/// * **Daily reminder.** If reminders are on, always exactly one is scheduled
///   for the learner's study time. It moves to tomorrow as soon as they finish
///   something today, so a learner who studies at 9am is not nudged at 6pm.
/// * **Comeback reminder.** Opening a lesson schedules a nudge for three hours
///   later; finishing the step cancels it. Stopping halfway is exactly the case
///   the learner asked to be reminded about.
/// * Nothing is scheduled when the switch is off, and switching off cancels
///   what is already pending.
class ReminderService {
  ReminderService({
    required this.gateway,
    required this.settings,
    bool Function()? learnedToday,
  }) : _learnedToday = learnedToday ?? _defaultLearnedToday;

  final ReminderGateway gateway;
  final SettingsRepository settings;
  final bool Function() _learnedToday;

  /// The only reminder body that does not depend on state.
  static const String _dailyTitle = 'Time for Python';

  static bool _defaultLearnedToday() => false;

  /// Whether [activity] contains a session on the same calendar day as [now].
  static bool learnedOn(List<DateTime> activity, DateTime now) => activity.any(
    (day) =>
        day.year == now.year && day.month == now.month && day.day == now.day,
  );

  bool get enabled => settings.reminderEnabled;

  String get timeLabel {
    final hour = settings.reminderHour % 24;
    final minute = settings.reminderMinute % 60;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Prepares the notification plugin, asks for permission once, and schedules
  /// the daily reminder. Safe to call on every launch.
  Future<void> bootstrap() async {
    if (!gateway.supported) return;
    await gateway.initialize();
    if (!settings.reminderEnabled) {
      await gateway.cancelAll();
      return;
    }
    if (!settings.reminderPermissionAsked) {
      await gateway.requestPermission();
      await settings.setReminderPermissionAsked(true);
    }
    await rescheduleDaily();
  }

  /// Re-schedules the daily reminder for the next study time.
  Future<void> rescheduleDaily() async {
    if (!gateway.supported) return;
    if (!settings.reminderEnabled) {
      await gateway.cancelAll();
      return;
    }
    final learned = _learnedToday();
    await gateway.scheduleDaily(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      title: _dailyTitle,
      body: learned
          ? 'You learned today — the next nudge is tomorrow at $timeLabel.'
          : 'You have not learned yet today. One step takes about three '
                'minutes, and your streak is waiting.',
    );
  }

  /// Called when a lesson is opened: nudge the learner if they stop halfway.
  Future<void> onLessonOpened(String stepTitle) async {
    if (!gateway.supported || !settings.reminderEnabled) return;
    await gateway.scheduleComeback(
      after: const Duration(hours: 3),
      title: 'Still working on $stepTitle?',
      body:
          'You stopped before finishing. Two minutes now is easier than '
          'starting over — your code is saved exactly where you left it.',
    );
  }

  /// Called after a step is finished: the comeback nudge is no longer needed and
  /// today is done, so the next daily reminder belongs to tomorrow.
  Future<void> onStepCompleted() async {
    if (!gateway.supported) return;
    await gateway.cancelComeback();
    await rescheduleDaily();
  }

  Future<void> setEnabled(bool value) async {
    await settings.setReminderEnabled(value);
    if (!gateway.supported) return;
    if (!value) {
      await gateway.cancelAll();
      return;
    }
    await gateway.initialize();
    if (!settings.reminderPermissionAsked) {
      await gateway.requestPermission();
      await settings.setReminderPermissionAsked(true);
    }
    await rescheduleDaily();
  }

  Future<void> setTime({required int hour, required int minute}) async {
    await settings.setReminderTime(hour: hour, minute: minute);
    await rescheduleDaily();
  }
}
