/// Channel identifiers, kept free of any plugin import so the scheduler and
/// its tests never pull in a platform channel.
///
/// IDs are **versioned** because Android freezes a channel's sound at creation
/// and ignores later changes to the same ID. Swapping the adhan sound means
/// creating a new version and deleting the old one — never mutating in place.
///
/// The freeze is wider than sound. A field the user (or an OEM) has changed is
/// recorded in `mUserLockedFields` and becomes permanently unwritable by the
/// app. Observed on a HONOR VNE-N41 running MagicOS: MagicOS downgraded the
/// adhan from `Importance.max` to `IMPORTANCE_DEFAULT` and locked it, so the
/// adhan could never wake the screen. `createNotificationChannel` cannot undo
/// that, and neither can reinstalling — only a new ID starts clean.
library;

/// Bumped v1 → v2 to reset the importance MagicOS locked at DEFAULT, and to
/// adopt the full-screen intent that lets the adhan behave like an alarm.
const channelAdhan = 'adhan_v2';
const channelIqama = 'iqama_v1';
const channelAthkar = 'athkar_v1';
const channelWird = 'wird_v1';
const channelGeneral = 'general_v1';

const allChannelIds = <String>[
  channelAdhan,
  channelIqama,
  channelAthkar,
  channelWird,
  channelGeneral,
];

/// Superseded channels, deleted at startup.
///
/// Without this the old row lingers in the system notification settings, so
/// the user sees two «الأذان» entries and cannot tell which one is live.
const retiredChannelIds = <String>['adhan_v1'];
