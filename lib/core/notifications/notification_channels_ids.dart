/// Channel identifiers, kept free of any plugin import so the scheduler and
/// its tests never pull in a platform channel.
///
/// IDs are **versioned** because Android freezes a channel's sound at creation
/// and ignores later changes to the same ID. Swapping the adhan sound means
/// creating `adhan_v2` and deleting `adhan_v1` — never mutating one in place.
library;

const channelAdhan = 'adhan_v1';
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
