#!/usr/bin/env bash
# Installs an adhan recording as one prayer's notification-channel sound.
#
# Usage: tool/install_adhan_sound.sh <prayer|all> path/to/adhan.ogg
#          prayer: fajr | dhuhr | asr | maghrib | isha | all
#
# Validates the file, copies it into res/raw under a per-prayer name, and
# prints the exact source changes needed. It deliberately does NOT edit the
# Dart itself: bumping a channel version has a user-visible consequence — the
# old channel is deleted and any per-channel settings the user tuned are lost —
# so it stays a human's call.
#
# NOTE ON RIGHTS. This tool copies whatever file it is given. Adhan recordings
# are performances and are usually somebody's copyright; using one is the
# repository owner's decision and their risk, not this script's. Nothing here
# downloads anything.
set -euo pipefail

RAW_DIR="android/app/src/main/res/raw"
SOUNDS="lib/core/notifications/adhan_sounds.dart"

die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
note() { printf '\033[33m%s\033[0m\n' "$1"; }

[ $# -eq 2 ] || die "usage: $0 <fajr|dhuhr|asr|maghrib|isha|all> path/to/adhan.ogg"
PRAYER="$1"
SRC="$2"

case "$PRAYER" in
  fajr|dhuhr|asr|maghrib|isha) PRAYERS="$PRAYER" ;;
  all) PRAYERS="fajr dhuhr asr maghrib isha" ;;
  *) die "unknown prayer '$PRAYER' (fajr|dhuhr|asr|maghrib|isha|all)" ;;
esac

[ -f "$SRC" ] || die "no such file: $SRC"
[ -d "$RAW_DIR" ] || die "run this from the repo root (missing $RAW_DIR)"
[ -f "$SOUNDS" ] || die "missing $SOUNDS"

EXT="${SRC##*.}"
EXT="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

case "$EXT" in
  ogg|mp3) ;;
  wav) note "warning: WAV is uncompressed. A 2-minute file adds ~10 MB per prayer. Prefer OGG." ;;
  *) die "unsupported extension '.$EXT' (use .ogg)" ;;
esac

BYTES=$(wc -c < "$SRC" | tr -d ' ')
MB=$(awk "BEGIN{printf \"%.1f\", $BYTES/1048576}")
[ "$BYTES" -gt 0 ] || die "file is empty"
awk "BEGIN{exit !($BYTES > 5242880)}" && \
  note "warning: ${MB} MB is large for a bundled resource; consider a lower bitrate."

if [ "$PRAYER" = "all" ]; then
  note "note: installing the same recording for all five means five copies of"
  note "      ${MB} MB in the APK. If they are meant to be identical, consider"
  note "      installing it for one prayer and pointing the others at that name."
fi

echo
for P in $PRAYERS; do
  NAME="adhan_$P"
  cp "$SRC" "$RAW_DIR/$NAME.$EXT"
  printf 'installed -> %s/%s.%s (%s MB)\n' "$RAW_DIR" "$NAME" "$EXT" "$MB"
done

echo
cat <<'EOF'
Two source changes are required, and both of them. Android freezes a channel's
sound at creation and ignores a later change to the same id, so without the
version bump you would ship the new audio and keep hearing the old sound.

In lib/core/notifications/adhan_sounds.dart:
EOF

for P in $PRAYERS; do
  CURRENT=$(grep -oE "'$P': [0-9]+," "$SOUNDS" | grep -oE '[0-9]+' | head -1)
  NEXT=$(( ${CURRENT:-1} + 1 ))
  cat <<EOF

  1. _adhanSounds
       '$P': 'adhan_$P',

  2. _adhanChannelVersions
       '$P': $NEXT,        (was ${CURRENT:-1})

  3. retiredChannelIds in notification_channels_ids.dart
       add 'adhan_${P}_v${CURRENT:-1}'
EOF
done

cat <<'EOF'

Then: flutter test && flutter analyze && flutter build apk --release

The test 'all five still play the placeholder, and say so' in
test/core/notifications/notification_channels_test.dart will fail once a real
recitation is installed — that is the tripwire working. Update it to expect the
new resource for the prayers you changed.
EOF
