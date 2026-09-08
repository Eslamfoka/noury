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
/// **Five real recitations are installed**, one per prayer, all of them
/// freely licensed — see `adhanCredits` for who made each and under what
/// licence. `tool/install_adhan_sound.sh <prayer> <file>` replaces any of them
/// and prints the two changes it needs.
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
  'fajr': 2,
  'dhuhr': 2,
  'asr': 2,
  'maghrib': 2,
  'isha': 2,
};

/// The raw resource name for one prayer's adhan.
String adhanSoundFor(String prayer) => _adhanSounds[prayer] ?? 'chime';

/// The channel id for one prayer's adhan.
String adhanChannelFor(String prayer) =>
    'adhan_${prayer}_v${_adhanChannelVersions[prayer] ?? 1}';

/// Every adhan channel id.
List<String> get adhanChannelIds =>
    [for (final p in adhanPrayers) adhanChannelFor(p)];

/// Whether [channelId] is one of the adhan channels.
///
/// The adhan is the only thing in Nouri that gets a full-screen intent, alarm
/// category and max importance, so several places need to ask this. Asking by
/// membership rather than by equality is what let one channel become five
/// without any of them losing those properties.
bool isAdhanChannel(String channelId) => adhanChannelIds.contains(channelId);

/// True while no real recitation has been installed for any prayer.
///
/// The settings screen reads this rather than letting the user believe a
/// 1.90-second chime is the adhan they will hear at fajr.
bool get adhanIsPlaceholder =>
    adhanPrayers.every((p) => adhanSoundFor(p) == 'chime');

/// Who recorded each adhan, and under what licence.
///
/// **CC BY and CC BY-SA both require attribution**, so this is not a courtesy
/// — it is the condition of use, and the About screen prints it. All five came
/// from Wikimedia Commons, chosen because their licences can actually be
/// stated: a famous recitation off an aggregator site cannot.
///
/// Keep this in step with [_adhanSounds]. A recording swapped in without its
/// credit swapped too would leave the app claiming the wrong author.
const adhanCredits = <String, String>{
  'fajr': 'Adam-synagda — CC0',
  'dhuhr': 'Andrewler — CC BY-SA 4.0',
  'asr': 'Jarih — CC BY-SA 3.0',
  'maghrib': 'Atcovi — CC BY-SA 4.0',
  'isha': 'ejaz215 — CC BY 3.0',
};
