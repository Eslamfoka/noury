/// How precisely Android will honour a scheduled time.
enum NotificationMode {
  /// Fires at the exact second, even in Doze. Requires the exact-alarm
  /// permission.
  exact,

  /// Android may batch and delay it. Still delivered — just not punctual.
  inexact,
}

/// The ways an alarm can fail to *arrive*, or to arrive on time.
///
/// Do Not Disturb is deliberately **not** among them. It does not delay or
/// drop anything: the notification arrives punctually and silently. That is a
/// different failure with a different fix, and folding it in here would put a
/// permanent warning about lateness in front of every user who has DND
/// switched off and nothing wrong. It has its own row in the panel instead.
enum NotificationWarning {
  notificationsDisabled,
  exactAlarmsUnavailable,
  batteryOptimised,
}

/// A plain, honest reading of whether the adhan will actually arrive on time.
///
/// Nouri never claims a reliability it does not have: when exact alarms are
/// unavailable it degrades to inexact scheduling **and says so** in the
/// settings panel, rather than failing silently.
class NotificationStatus {
  const NotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.batteryOptimised,
    this.adhanBypassesDnd = false,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;

  /// True when the OS is still applying battery optimisation to Nouri — the
  /// most common cause of alarms being silently killed by OEM power managers.
  final bool batteryOptimised;

  /// Whether the adhan is on a channel that Do Not Disturb cannot silence.
  ///
  /// Read back from the live channel rather than from what the app requested:
  /// `setBypassDnd(true)` is accepted and ignored without notification-policy
  /// access, so asking for it proves nothing about whether it happened.
  ///
  /// Not part of [warnings] or [isFullyReliable] — see the note on
  /// [NotificationWarning]. A silenced adhan still arrived on time.
  final bool adhanBypassesDnd;

  NotificationMode get mode =>
      exactAlarmsAllowed ? NotificationMode.exact : NotificationMode.inexact;

  /// Whether anything can be delivered at all.
  bool get schedulesAtAll => notificationsEnabled;

  bool get isFullyReliable => warnings.isEmpty;

  /// Ordered most to least severe, so the UI can lead with what matters.
  List<NotificationWarning> get warnings => [
        if (!notificationsEnabled) NotificationWarning.notificationsDisabled,
        if (!exactAlarmsAllowed) NotificationWarning.exactAlarmsUnavailable,
        if (batteryOptimised) NotificationWarning.batteryOptimised,
      ];

  NotificationStatus copyWith({
    bool? notificationsEnabled,
    bool? exactAlarmsAllowed,
    bool? batteryOptimised,
    bool? adhanBypassesDnd,
  }) =>
      NotificationStatus(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
        batteryOptimised: batteryOptimised ?? this.batteryOptimised,
        adhanBypassesDnd: adhanBypassesDnd ?? this.adhanBypassesDnd,
      );
}
