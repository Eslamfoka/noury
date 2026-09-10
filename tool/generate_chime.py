"""Generates Nouri's default notification chime.

Run:  python tool/generate_chime.py

Deliberately synthesised rather than downloaded: no licensing question, no
audio of unknown provenance shipped in the APK, and fully reproducible.

The sound is a calm two-note bell (A5 then E5, a descending fourth) with a
soft exponential decay. It is meant to be noticeable at Fajr without being
startling. To replace it with a real adhan or takbir recording, see the
"Adhan sound" section of docs/setup.md.
"""

import math
import struct
import wave

SAMPLE_RATE = 44100
DURATION = 1.9
OUT_APP = "android/app/src/main/res/raw/chime.wav"
OUT_ASSET = "assets/audio/chime.wav"

# (start second, frequency Hz, peak amplitude)
NOTES = [
    (0.00, 880.00, 0.42),   # A5
    (0.45, 659.25, 0.38),   # E5
]

# A quiet octave above each note gives the bell a little shimmer.
OVERTONE_RATIO = 2.0
OVERTONE_GAIN = 0.22

DECAY = 3.1          # higher = shorter tail
FADE_OUT = 0.12      # seconds of linear fade at the very end


def sample_at(t: float) -> float:
    value = 0.0
    for start, freq, amp in NOTES:
        if t < start:
            continue
        age = t - start
        envelope = amp * math.exp(-DECAY * age)
        value += envelope * math.sin(2 * math.pi * freq * age)
        value += envelope * OVERTONE_GAIN * math.sin(
            2 * math.pi * freq * OVERTONE_RATIO * age
        )

    # Linear fade so the file never ends on a click.
    remaining = DURATION - t
    if remaining < FADE_OUT:
        value *= max(0.0, remaining / FADE_OUT)

    return max(-1.0, min(1.0, value))


def main() -> None:
    frames = bytearray()
    total = int(SAMPLE_RATE * DURATION)
    for i in range(total):
        v = sample_at(i / SAMPLE_RATE)
        frames += struct.pack("<h", int(v * 32767))

    for path in (OUT_APP, OUT_ASSET):
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(bytes(frames))
        print(f"wrote {path} ({len(frames)} bytes of audio)")


if __name__ == "__main__":
    main()
