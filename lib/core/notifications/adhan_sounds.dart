/// One adhan per prayer, each on its own channel.
///
/// Kept free of any plugin import, like the other id files, so the scheduler
/// and its tests can reason about channels without a platform channel.
///
/// **Why five channels rather than one.** Android freezes a channel's sound at
/// creation and ignores later changes to the same id, so five different
/// recitations need five channels — the same fact that gives every task alert
/// its own. It also means the user can silence, say, the fajr adhan alone
/// without touching the other four, which a single channel could never offer.
///
/// **Five real recitations are installed**, one per prayer — see
/// [adhanCredits] for who recites each. `tool/install_adhan_sound.sh` replaces
/// any of them and prints the changes it needs.
///
/// **On rights, stated plainly.** These five are well-known recitations taken
/// from a public archive; unlike the Wikimedia set they replaced, their
/// licences are *not* individually verifiable. The repository owner asked for
/// famous reciters, was told that trade-off in writing, and accepted it for
/// **personal use on his own device**. Nothing here is distributed, and this
/// app is not published. If Nouri is ever put in front of anyone else, these
/// five are the first thing that has to be revisited — see
/// `docs/superpowers/handoffs/` for the full note.
///
/// Each prayer carries its own version number so a recitation can be replaced
/// one at a time — swapping fajr must not reset the channel the user has
/// tuned for isha.
library;

/// The five prayers, in the order they fall.
const adhanPrayers = <String>['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// The `res/raw` resource each prayer's adhan plays.
///
/// Edited by `tool/install_adhan_sound.sh` when a recitation is installed,
/// **together with** the matching bump in [_adhanChannelVersions]. Changing
/// one without the other ships new audio and keeps playing the old sound,
/// silently, because the channel already exists on the device.
const _adhanSounds = <String, String>{
  'fajr': 'adhan_fajr',
  'dhuhr': 'adhan_dhuhr',
  'asr': 'adhan_asr',
  'maghrib': 'adhan_maghrib',
  'isha': 'adhan_isha',
};

/// Bumped whenever that prayer's sound changes. Never edited downward.
const _adhanChannelVersions = <String, int>{
  'fajr': 3,
  'dhuhr': 3,
  'asr': 3,
  'maghrib': 3,
  'isha': 3,
};

/// The raw resource name for one prayer's adhan.
String adhanSoundFor(String prayer) => _adhanSounds[prayer] ?? 'chime';

/// Marks the variant of an adhan channel that bypasses Do Not Disturb.
///
/// **Why a second id rather than a flag on the first.** Android fixes a
/// channel's DND bypass when the channel is created, exactly as it fixes its
/// sound, and `setBypassDnd(true)` is ignored outright until the user has
/// granted notification-policy access on a system screen. A channel that
/// bypasses therefore cannot be the same channel that did not — it has to be
/// created afresh, under an id that has never been seen before.
///
/// The two variants never coexist on a device: whichever is not current is
/// deleted at startup, so the user sees five «الأذان» rows and not ten.
const adhanBypassSuffix = 'd';

/// The channel id for one prayer's adhan.
///
/// Pass [bypassing] when the user has granted policy access — see
/// [adhanBypassSuffix] for why that is a different channel and not a setting.
String adhanChannelFor(String prayer, {bool bypassing = false}) =>
    'adhan_${prayer}_v${_adhanChannelVersions[prayer] ?? 1}'
    '${bypassing ? adhanBypassSuffix : ''}';

/// Every adhan channel id, in the ordinary non-bypassing form.
List<String> get adhanChannelIds =>
    [for (final p in adhanPrayers) adhanChannelFor(p)];

/// Every adhan channel id in the form that bypasses Do Not Disturb.
List<String> get adhanBypassChannelIds =>
    [for (final p in adhanPrayers) adhanChannelFor(p, bypassing: true)];

/// The non-bypassing form of an adhan channel id.
///
/// Everything that describes what an adhan channel *is* — its name, its sound,
/// its importance, the full-screen intent — is written once against the base
/// id. Callers holding either variant normalise through here rather than the
/// two descriptions being written out twice and drifting, which is how this
/// project lost قيام and the budget note once already.
String adhanBaseChannel(String channelId) =>
    adhanBypassChannelIds.contains(channelId)
        ? channelId.substring(0, channelId.length - adhanBypassSuffix.length)
        : channelId;

/// Whether [channelId] is one of the adhan channels, in either variant.
///
/// The adhan is the only thing in Nouri that gets a full-screen intent, alarm
/// category and max importance, so several places need to ask this. Asking by
/// membership rather than by equality is what let one channel become five
/// without any of them losing those properties — and now what lets each of the
/// five have a DND-bypassing twin on the same terms.
bool isAdhanChannel(String channelId) =>
    adhanChannelIds.contains(channelId) ||
    adhanBypassChannelIds.contains(channelId);

/// True while no real recitation has been installed for any prayer.
///
/// The settings screen reads this rather than letting the user believe a
/// 1.90-second chime is the adhan they will hear at fajr.
bool get adhanIsPlaceholder =>
    adhanPrayers.every((p) => adhanSoundFor(p) == 'chime');

/// Who recites each adhan.
///
/// Printed in عن نوري and beside each «شغّل» in الأصوات. It was a licence
/// condition when the five came from Wikimedia under CC BY and CC BY-SA; with
/// the current set it is something better than a condition — it is the only
/// way the user can tell which voice he is about to hear, and the only record
/// of where these came from.
///
/// Keep this in step with [_adhanSounds]. A recording swapped in without its
/// credit swapped too would leave the app naming the wrong reciter.
const adhanCredits = <String, String>{
  'fajr': 'مشاري العفاسي — أذان الفجر',
  'dhuhr': 'عبد الباسط عبد الصمد',
  'asr': 'ناصر القطامي',
  'maghrib': 'المدينة المنورة، ١٩٥٢',
  'isha': 'مشاري العفاسي',
};
