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

import 'adhan_sounds.dart';
import 'task_alert.dart';

/// **Retired.** The single adhan channel became five, one per prayer — see
/// `adhan_sounds.dart`. Kept only so the id can be named in
/// [retiredChannelIds] and deleted from devices that still carry it.
///
/// It was itself a v1 → v2 bump, to reset the importance MagicOS had locked
/// at DEFAULT and to adopt the full-screen intent.
const channelAdhan = 'adhan_v2';
const channelIqama = 'iqama_v1';
const channelAthkar = 'athkar_v1';
const channelWird = 'wird_v1';
const channelGeneral = 'general_v1';

/// The core ids. Every [TaskAlertKind] adds one more; `allChannelIds` below
/// is the union, and it is what startup creates and what the settings screen
/// reasons about.
const coreChannelIds = <String>[
  channelIqama,
  channelAthkar,
  channelWird,
  channelGeneral,
];

/// Every channel id Nouri owns.
///
/// Built from the registry rather than listed by hand: a kind added there and
/// forgotten here would create a channel nothing ever deletes, leaving a stray
/// row in the user's system notification settings.
final allChannelIds = <String>[
  ...adhanChannelIds,
  ...coreChannelIds,
  for (final kind in TaskAlertKind.values) kind.channelId,
];

/// Superseded channels, deleted at startup.
///
/// Without this the old row lingers in the system notification settings, so
/// the user sees two «الأذان» entries and cannot tell which one is live.
/// Superseded channels, deleted at startup.
///
/// `adhan_v2` joins the list because the single adhan channel became five,
/// one per prayer. Leaving it would show the user a sixth «الأذان» row in
/// system settings that nothing ever fires on.
const retiredChannelIds = <String>[
  'adhan_v1',
  'adhan_v2',
  // The per-prayer channels' own v1, created while all five still pointed at
  // the chime placeholder. Android freezes a channel's sound at creation, so
  // installing the real recitations meant a new id for each — and the old ones
  // have to go or the user sees ten «الأذان» rows.
  'adhan_fajr_v1',
  'adhan_dhuhr_v1',
  'adhan_asr_v1',
  'adhan_maghrib_v1',
  'adhan_isha_v1',
];
