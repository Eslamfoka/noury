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
/// **All five point at `chime` until real recitations are installed.** The
/// placeholder is 1.90 s and is not an adhan; Nouri says so plainly rather
/// than pretending otherwise. `tool/install_adhan_sound.sh <prayer> <file>`
/// installs one and prints the two changes it needs.
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
  'fajr': 'chime',
  'dhuhr': 'chime',
  'asr': 'chime',
  'maghrib': 'chime',
  'isha': 'chime',
};

/// Bumped whenever that prayer's sound changes. Never edited downward.
const _adhanChannelVersions = <String, int>{
  'fajr': 1,
  'dhuhr': 1,
  'asr': 1,
  'maghrib': 1,
  'isha': 1,
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
/// The settings screen says so rather than letting the user believe the
/// 1.90-second placeholder is the adhan they will hear at fajr.
bool get adhanIsPlaceholder =>
    adhanPrayers.every((p) => adhanSoundFor(p) == 'chime');
