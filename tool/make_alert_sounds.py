#!/usr/bin/env python3
"""Generates Nouri's alert tones into android/app/src/main/res/raw/.

**Synthesised rather than downloaded, deliberately.** There is no licence to
honour, no attribution to track, nothing that can be taken down, and any tone
can be retuned by editing one line here and re-running. Each file is about
20-60 KB rather than the megabyte a stock recording would cost, which matters
when eighteen of them ship in the APK.

The point of the feature is that the user can tell **which task is calling by
ear**, without looking at the screen. So the tones are designed to contrast
with each other rather than to sound realistic, and several of them carry the
shape of the thing they announce: water falls, walking alternates, the morning
athkar rise and the evening athkar are their mirror.

An adhan is deliberately **not** here. A synthesised approximation of a muezzin
would be worse than the placeholder it replaced; real recitations are
performances with rights holders, and which one to use is a matter of taste and
religious preference. See tool/install_adhan_sound.sh.

Run:  python tool/make_alert_sounds.py
"""

import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join("android", "app", "src", "main", "res", "raw")


def render(notes, length_s):
    """Sums a list of (freq_hz, start_s, dur_s, decay) into one buffer."""
    n = int(RATE * length_s)
    buf = [0.0] * n
    for freq, start, dur, decay in notes:
        s = int(start * RATE)
        for i in range(int(dur * RATE)):
            if s + i >= n:
                break
            t = i / RATE
            buf[s + i] += math.sin(2 * math.pi * freq * t) * math.exp(-decay * t)
    return buf


def normalise(buf, peak=0.7):
    """Peak-normalise to about -3 dBFS so no tone is louder than another."""
    m = max(abs(v) for v in buf) or 1.0
    return [v / m * peak for v in buf]


def fade(buf, in_s=0.015, out_s=0.06):
    """Without this every tone starts and ends on a click."""
    a, b = int(in_s * RATE), int(out_s * RATE)
    for i in range(min(a, len(buf))):
        buf[i] *= i / a
    for i in range(min(b, len(buf))):
        buf[len(buf) - 1 - i] *= i / b
    return buf


def write(name, notes, length_s):
    buf = fade(normalise(render(notes, length_s)))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in buf
            )
        )
    return os.path.getsize(path)


SOUNDS = {
    # Three descending drops. Water falls, so the pitch falls.
    "alert_water": ([(880, 0.00, 0.35, 12), (660, 0.28, 0.35, 12),
                     (550, 0.56, 0.45, 10)], 1.1),
    # Four alternating steps, evenly spaced. It sounds like walking.
    "alert_walk": ([(440, 0.00, 0.18, 18), (330, 0.22, 0.18, 18),
                    (440, 0.44, 0.18, 18), (330, 0.66, 0.22, 16)], 1.0),
    # Three rising drives, like reps starting. Brisker than the walk.
    "alert_workout": ([(392, 0.00, 0.16, 20), (523, 0.18, 0.16, 20),
                       (659, 0.36, 0.30, 14)], 0.9),
    # Warm and rising — an invitation to the table.
    "alert_meal": ([(392, 0.00, 0.30, 8), (523, 0.26, 0.50, 6)], 0.9),
    # Three even taps, like beads passing between the fingers.
    "alert_tasbeeh": ([(660, 0.00, 0.22, 16), (660, 0.24, 0.22, 16),
                       (660, 0.48, 0.30, 14)], 0.9),
    # A calm ascending triad. Unhurried, because the wird is not urgent.
    "alert_wird": ([(392, 0.00, 0.45, 5), (494, 0.22, 0.45, 5),
                    (587, 0.44, 0.70, 4)], 1.3),
    "alert_athkar_morning": ([(523, 0.00, 0.35, 7), (784, 0.28, 0.60, 5)], 1.0),
    # Deliberately the exact mirror of the morning: same two notes, reversed.
    "alert_athkar_evening": ([(784, 0.00, 0.35, 7), (523, 0.28, 0.60, 5)], 1.0),
    # Low and slow, sinking. It is the last thing before sleep.
    "alert_athkar_sleep": ([(330, 0.00, 0.60, 3), (220, 0.45, 0.90, 2)], 1.5),
    # Arrives around 01:30. One soft low tone: it must invite, never startle.
    "alert_qiyam": ([(262, 0.00, 1.20, 2)], 1.4),
    "alert_knowledge": ([(294, 0.00, 0.40, 4), (587, 0.35, 0.60, 5)], 1.1),
    # Deliberately the plainest sound here. It is a cap, not a treat.
    "alert_phone": ([(700, 0.00, 0.14, 22), (700, 0.20, 0.14, 22)], 0.5),
    "alert_calls": ([(480, 0.00, 0.20, 14), (440, 0.18, 0.20, 14),
                     (480, 0.44, 0.20, 14), (440, 0.62, 0.24, 12)], 1.0),
    # Two low ticks, like coins set down.
    "alert_budget": ([(300, 0.00, 0.25, 14), (300, 0.30, 0.30, 12)], 0.8),
    "alert_reminder": ([(660, 0.00, 0.70, 5)], 0.9),
    "alert_fasting": ([(349, 0.00, 0.80, 3)], 1.0),
    "alert_review": ([(440, 0.00, 0.30, 7), (494, 0.26, 0.50, 5)], 0.9),
    # The quietest and shortest: it is only asking, and it must not nag.
    "alert_followup": ([(587, 0.00, 0.25, 12)], 0.4),
    "alert_iqama": ([(294, 0.00, 0.22, 16), (294, 0.26, 0.28, 14)], 0.7),
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, (notes, length) in sorted(SOUNDS.items()):
        size = write(name, notes, length)
        total += size
        print(f"  {name}.wav  {size // 1024} KB")
    print(f"\n{len(SOUNDS)} sounds, {total // 1024} KB total, written to {OUT}")
