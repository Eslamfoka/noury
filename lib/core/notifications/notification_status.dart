/// How precisely Android will honour a scheduled time.
enum NotificationMode {
  /// Fires at the exact second, even in Doze. Requires the exact-alarm
  /// permission.
  exact,

  /// Android may batch and delay it. Still delivered — just not punctual.
  inexact,
}

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
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;

  /// True when the OS is still applying battery optimisation to Nouri — the
  /// most common cause of alarms being silently killed by OEM power managers.
  final bool batteryOptimised;

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
  }) =>
      NotificationStatus(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
        batteryOptimised: batteryOptimised ?? this.batteryOptimised,
      );
}
