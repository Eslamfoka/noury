import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_status.dart';

void main() {
  test('everything granted reads as fully reliable', () {
    const s = NotificationStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: true,
      batteryOptimised: false,
    );
    expect(s.mode, NotificationMode.exact);
    expect(s.isFullyReliable, isTrue);
    expect(s.warnings, isEmpty);
  });

  test('no exact alarms degrades the mode and says so', () {
    const s = NotificationStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: false,
      batteryOptimised: false,
    );
    expect(s.mode, NotificationMode.inexact);
    expect(s.isFullyReliable, isFalse);
    expect(s.warnings, contains(NotificationWarning.exactAlarmsUnavailable));
  });

  test('battery optimisation is reported even when all else is granted', () {
    const s = NotificationStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: true,
      batteryOptimised: true,
    );
    expect(s.warnings, contains(NotificationWarning.batteryOptimised));
    expect(s.isFullyReliable, isFalse);
    expect(s.mode, NotificationMode.exact,
        reason: 'battery optimisation does not change the scheduling mode');
  });

  test('notifications disabled is the most severe warning and comes first', () {
    const s = NotificationStatus(
      notificationsEnabled: false,
      exactAlarmsAllowed: false,
      batteryOptimised: true,
    );
    expect(s.warnings.first, NotificationWarning.notificationsDisabled);
    expect(s.warnings, hasLength(3));
  });

  test('warnings are ordered most to least severe', () {
    const s = NotificationStatus(
      notificationsEnabled: false,
      exactAlarmsAllowed: false,
      batteryOptimised: true,
    );
    expect(s.warnings, [
      NotificationWarning.notificationsDisabled,
      NotificationWarning.exactAlarmsUnavailable,
      NotificationWarning.batteryOptimised,
    ]);
  });

  test('the fallback is a degraded mode, never a silent failure', () {
    // Nouri still schedules when exact alarms are refused — it just says so.
    const s = NotificationStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: false,
      batteryOptimised: false,
    );
    expect(s.mode, NotificationMode.inexact);
    expect(s.schedulesAtAll, isTrue);
  });

  test('with notifications off, nothing can be delivered at all', () {
    const s = NotificationStatus(
      notificationsEnabled: false,
      exactAlarmsAllowed: true,
      batteryOptimised: false,
    );
    expect(s.schedulesAtAll, isFalse);
  });
}
