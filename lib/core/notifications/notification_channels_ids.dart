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

/// **Retired.** The iqama moved to `alert_iqama_v2`, which carries a sound of
/// its own rather than the system default — see the note at that call site.
/// Kept only so the id can be named in [retiredChannelIds].
const channelIqama = 'iqama_v1';

/// Still live, but only when the day plan is *not* announcing the athkar
/// itself. See the gate in `rolling_window_scheduler.dart`.
const channelAthkar = 'athkar_v1';
const channelWird = 'wird_v1';
const channelGeneral = 'general_v1';

/// The core ids. Every [TaskAlertKind] adds one more; `allChannelIds` below
/// is the union, and it is what startup creates and what the settings screen
/// reasons about.
const coreChannelIds = <String>[
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
///
/// `adhan_v2` joins the list because the single adhan channel became five,
/// one per prayer. Leaving it would show the user a sixth «الأذان» row in
/// system settings that nothing ever fires on.
///
/// **Deleting is the only way to change a sound.** Android freezes a channel's
/// sound at creation and ignores every later edit, so a retuned tone means a
/// new channel id and the old id named here. Nothing else about this list is
/// optional: skip it and the user keeps hearing the sound they asked to have
/// changed, with no error anywhere to explain why.
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
  // The iqama's own channel, superseded by `alert_iqama_v2`. It had the
  // system default sound, which was the whole problem: the one notification
  // that has to be told apart from the adhan sounded like every other app on
  // the phone.
  'iqama_v1',
  // All nineteen task tones were retuned on 9 September 2026, from abstract
  // arrangements of sine beeps to sounds that resemble the task they announce
  // — water runs, footsteps land, a telephone rings. Every one of them
  // therefore needed a new channel, and every previous id belongs here.
  'alert_water_v1',
  'alert_walk_v1',
  'alert_workout_v1',
  'alert_meal_v1',
  'alert_tasbeeh_v1',
  // The wird was already on v2 by then; v1 is listed because a build carrying
  // it may have reached a device, and deleting a channel that was never
  // created is a no-op — the cheaper side of the bet.
  'alert_wird_v1',
  'alert_wird_v2',
  'alert_athkar_morning_v1',
  'alert_athkar_evening_v1',
  'alert_athkar_sleep_v1',
  'alert_qiyam_v1',
  'alert_knowledge_v1',
  'alert_phone_v1',
  'alert_calls_v1',
  'alert_budget_v1',
  'alert_reminder_v1',
  'alert_fasting_v1',
  'alert_review_v1',
  'alert_followup_v1',
  'alert_iqama_v2',
  // The Wikimedia-sourced recitations, replaced on 9 September 2026 by the
  // famous reciters the user asked for. Both variants of each: by then the
  // adhan channels already came in a plain and a DND-bypassing form, and a
  // device could be carrying either.
  'adhan_fajr_v2', 'adhan_fajr_v2d',
  'adhan_dhuhr_v2', 'adhan_dhuhr_v2d',
  'adhan_asr_v2', 'adhan_asr_v2d',
  'adhan_maghrib_v2', 'adhan_maghrib_v2d',
  'adhan_isha_v2', 'adhan_isha_v2d',
];
