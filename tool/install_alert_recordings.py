#!/usr/bin/env python3
"""Installs the user's own alert recordings into android/app/src/main/res/raw/.

On 13 September 2026 the user sent eleven recordings of his own choosing to
replace eleven of the nineteen synthesised tones — «انا بعتلك ملف فيه
الاشعارات اللي عايزها تتعدل واللي مش باعته سيبه زي ما هو». The eight he did
not send stay exactly as `make_alert_sounds.py` made them.

This script is the record of which file became which tone. The mapping is by
the name he gave each file, so a second batch can be dropped into the same
folder and installed the same way.

What it does, per recording:

- copies an MP3 as it is — his file, byte for byte, nothing re-encoded;
- converts anything else to MP3 first. The one he named `قيام الصلاه .m4a` is
  really a WebM container holding Opus audio (the first bytes are the EBML
  header, not `ftyp`), and Android's ringtone player is not reliable with
  that on every OEM skin. MP3 is what the rest of the set already uses;
- deletes the synthesised `.wav` of the same name. Android resource names
  are the file stem, so `alert_water.wav` beside `alert_water.mp3` is a
  duplicate-resource build error;
- prints the channel bump each one needs, because **Android freezes a
  channel's sound at creation** — a new file under an old channel id ships
  new audio and keeps playing the old sound. `task_alert.dart` carries the
  version; `notification_channels_ids.dart` retires the old one.

Run:  python tool/install_alert_recordings.py [notifications/]

Needs PyAV (`pip install av`) only for the conversion; plain copies need
nothing.
"""

import os
import shutil
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "notifications"
OUT = os.path.join("android", "app", "src", "main", "res", "raw")

# His filename → the tone it replaces. The keys are exactly as he named them,
# trailing spaces included, because renaming his files is how a batch drifts
# from what he sent.
RECORDINGS = {
    "water.mp3": "alert_water",
    "walking .mp3": "alert_walk",
    "تسبيح .mp3": "alert_tasbeeh",
    "ورد القرآن .mp3": "alert_wird",
    "اذكار الصباح .mp3": "alert_athkar_morning",
    "اذكار المساء .mp3": "alert_athkar_evening",
    "اذكار النوم .mp3": "alert_athkar_sleep",
    "قيام الليل .mp3": "alert_qiyam",
    "page turn for reading or another skill.mp3": "alert_knowledge",
    "stopwatch for phone time use.mp3": "alert_phone",
    # «قيام الصلاة» is the iqama — the call that the prayer is starting.
    "قيام الصلاه .m4a": "alert_iqama",
}


def peak_of(src):
    import av
    import numpy as np

    peak = 0.0
    with av.open(src) as inp:
        for frame in inp.decode(inp.streams.audio[0]):
            peak = max(peak, float(np.abs(frame.to_ndarray()).max()))
    return peak


def convert_to_mp3(src, dst, peak_target=0.9):
    """Re-encodes [src] as mono MP3, lifted so its loudest moment sits at
    [peak_target].

    The lift is only applied to files that are being re-encoded anyway. His
    MP3s are copied untouched, whatever their level. The one file that needed
    converting — the iqama — decoded at a peak of 0.28, quieter than every
    other recording in the batch but two, and it is the one tone that most
    has to be heard: it says the prayer is starting. 0.9 is where most of his
    own recordings already peak.
    """
    import av  # PyAV bundles FFmpeg, including the LAME encoder.
    import numpy as np

    peak = peak_of(src)
    gain = (peak_target / peak) if peak > 0 else 1.0

    with av.open(src) as inp, av.open(dst, "w", format="mp3") as out:
        in_stream = inp.streams.audio[0]
        # Mono at the source rate: a notification tone gains nothing from
        # stereo, and 128 kb/s is what his own MP3s use.
        out_stream = out.add_stream("libmp3lame", rate=in_stream.rate)
        out_stream.bit_rate = 128_000
        out_stream.layout = "mono"
        to_float = av.AudioResampler(format="fltp", layout="mono",
                                     rate=in_stream.rate)
        to_encoder = av.AudioResampler(format="s16p", layout="mono",
                                       rate=in_stream.rate)
        for frame in inp.decode(in_stream):
            for mono in to_float.resample(frame):
                samples = np.clip(mono.to_ndarray() * gain, -1.0, 1.0)
                lifted = av.AudioFrame.from_ndarray(
                    samples.astype(np.float32), format="fltp", layout="mono")
                lifted.sample_rate = in_stream.rate
                lifted.pts = mono.pts
                lifted.time_base = mono.time_base
                for ready in to_encoder.resample(lifted):
                    for packet in out_stream.encode(ready):
                        out.mux(packet)
        for packet in out_stream.encode(None):
            out.mux(packet)


def main():
    os.makedirs(OUT, exist_ok=True)
    installed = []
    for filename, tone in RECORDINGS.items():
        src = os.path.join(SRC, filename)
        if not os.path.exists(src):
            print(f"  missing: {filename!r} — skipped")
            continue

        dst = os.path.join(OUT, tone + ".mp3")
        if filename.lower().endswith(".mp3"):
            shutil.copyfile(src, dst)
            how = "copied"
        else:
            convert_to_mp3(src, dst)
            how = "converted, lifted to peak 0.9"

        stale = os.path.join(OUT, tone + ".wav")
        if os.path.exists(stale):
            os.remove(stale)
            how += ", old .wav removed"

        installed.append(tone)
        print(f"  {tone}.mp3  {os.path.getsize(dst) // 1024} KB  ({how})")

    print(f"\n{len(installed)} recordings installed into {OUT}")
    print("\nNow bump each of these kinds' channelId in")
    print("lib/core/notifications/task_alert.dart and retire the old id in")
    print("lib/core/notifications/notification_channels_ids.dart:")
    for tone in installed:
        print(f"  {tone}")


if __name__ == "__main__":
    main()
