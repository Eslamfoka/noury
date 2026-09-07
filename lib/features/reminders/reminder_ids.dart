/// The notification ID space reminders live in.
///
/// Kept free of any plugin import, and of any import at all, for the same
/// reason `notification_channels_ids.dart` is: the scheduler and its tests
/// must be able to reason about IDs without pulling in a platform channel.
///
/// The rolling window numbers its alarms `daysSince2020 * 32 + slot`. That is
/// about 78,000 today and climbs roughly 11,700 a year, so it reaches
/// 1,000,000 some time around the year 2098 and never approaches the base
/// below. A reminder ID can therefore never collide with an adhan, and
/// cancelling one can never silence the other.
library;

import '../../core/notifications/notification_slot.dart';

/// The floor of the reminder range.
///
/// Defined in core as [kOutOfWindowIdBase], because the rolling window has to
/// know it too: it clears its own alarms with `cancelAllBelow` against exactly
/// this value, which is what stops a settings change from deleting every
/// reminder on the device.
const kReminderIdBase = kOutOfWindowIdBase;

/// A reminder's notification ID, derived purely from its database row id.
///
/// Reproducible from the row alone, which is the whole reliability strategy:
/// re-arming after a reboot, or after any edit, lands on exactly the same ID
/// and overwrites the previous alarm instead of duplicating it.
int reminderNotificationId(int rowId) => kReminderIdBase + rowId;

bool isReminderNotificationId(int id) => id >= kReminderIdBase;

/// The inverse, so a tapped notification can be routed back to its reminder
/// even if the payload were ever lost.
int rowIdFromReminderNotificationId(int id) => id - kReminderIdBase;
