/// What [ReminderService] needs from a notification platform.
///
/// Kept separate from the implementation so the scheduling rules can be tested
/// without a device or a plugin channel.
abstract class ReminderGateway {
  /// Whether this platform can post notifications at all (false on web).
  bool get supported;

  Future<void> initialize();

  /// Returns true when the OS granted permission.
  Future<bool> requestPermission();

  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  Future<void> scheduleComeback({
    required Duration after,
    required String title,
    required String body,
  });

  Future<void> cancelComeback();

  Future<void> cancelAll();

  /// Posts an immediate, one-off notification.
  ///
  /// Used for foreground FCM announcements. Keeping it on this gateway means
  /// the local-notification plugin is initialized exactly once, by the same
  /// implementation that owns the learner's scheduled reminders.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Tapped notification payloads. Announcement heads-ups carry the announcement
  /// id; scheduled reminders carry no announcement payload.
  Stream<String> get opened;

  void dispose();
}
