/// Arabic names for the five prayers, keyed by the internal slot name.
///
/// These are structural labels, so they stay in MSA — the colloquial register
/// belongs to lines where Nouri speaks to the user, not to the names of the
/// prayers themselves.
const _arabicPrayerNames = <String, String>{
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

String arabicPrayerName(String slot) => _arabicPrayerNames[slot] ?? slot;

/// The five prayers in daily order.
const orderedPrayerNames = <String>[
  'fajr',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];
