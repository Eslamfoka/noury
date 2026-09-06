#!/usr/bin/env bash
# Installs an adhan recording as the notification channel sound.
#
# Usage: tool/install_adhan_sound.sh path/to/adhan.ogg
#
# Validates the file, copies it into res/raw, and prints the exact source
# changes needed. It deliberately does NOT edit the Dart itself: bumping the
# channel version is a decision with a user-visible consequence (the old
# channel is deleted and its settings are lost), so it stays a human's call.
set -euo pipefail

RAW_DIR="android/app/src/main/res/raw"
IDS="lib/core/notifications/notification_channels_ids.dart"
CHANNELS="lib/core/notifications/notification_channels.dart"

die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
note() { printf '\033[33m%s\033[0m\n' "$1"; }

[ $# -eq 1 ] || die "usage: $0 path/to/adhan.ogg"
SRC="$1"
[ -f "$SRC" ] || die "no such file: $SRC"
[ -d "$RAW_DIR" ] || die "run this from the repo root (missing $RAW_DIR)"

BASE="$(basename "$SRC")"
NAME="${BASE%.*}"
EXT="${BASE##*.}"

# Android resource names are not filenames. An illegal character here does not
# fail the build; it fails at playback, silently, on a user's phone at fajr.
case "$NAME" in
  *[!a-z0-9_]*) die "resource name '$NAME' must be lowercase a-z, 0-9 and _ only" ;;
  [0-9]*)       die "resource name '$NAME' cannot start with a digit" ;;
esac

case "$EXT" in
  ogg|mp3) ;;
  wav) note "warning: WAV is uncompressed. A 2-minute file adds ~10 MB to the APK. Prefer OGG." ;;
  *) die "unsupported extension '.$EXT' (use .ogg)" ;;
esac

BYTES=$(wc -c < "$SRC" | tr -d ' ')
MB=$(awk "BEGIN{printf \"%.1f\", $BYTES/1048576}")
[ "$BYTES" -gt 0 ] || die "file is empty"
awk "BEGIN{exit !($BYTES > 5242880)}" && \
  note "warning: ${MB} MB is large for a bundled resource; consider a lower bitrate."

cp "$SRC" "$RAW_DIR/$NAME.$EXT"
printf 'installed %s -> %s/%s.%s (%s MB)\n' "$SRC" "$RAW_DIR" "$NAME" "$EXT" "$MB"

CURRENT_ID=$(grep -oE "const channelAdhan = 'adhan_v[0-9]+'" "$IDS" | grep -oE 'adhan_v[0-9]+')
CURRENT_N=${CURRENT_ID##*_v}
NEXT_ID="adhan_v$((CURRENT_N + 1))"

cat <<EOF

Two source changes are required. Android freezes a channel's sound at creation
and ignores a later change to the same id, so without the bump you would ship
this audio and keep hearing the old one.

  1. $CHANNELS
       const adhanSoundResource = '$NAME';

  2. $IDS
       const channelAdhan = '$NEXT_ID';
       const retiredChannelIds = <String>[..., '$CURRENT_ID'];

  3. Update the tripwire in
     test/core/notifications/notification_channels_test.dart
     ('the adhan sound and the channel version move together') to
       ['$NEXT_ID', '$NAME']

Then: flutter test && flutter analyze
EOF
