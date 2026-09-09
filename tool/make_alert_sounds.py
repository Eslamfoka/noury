#!/usr/bin/env python3
"""Generates Nouri's alert tones into android/app/src/main/res/raw/.

**Synthesised rather than downloaded, deliberately.** There is no licence to
honour, no attribution to track, nothing that can be taken down, and any tone
can be retuned by editing one function here and re-running. Each file is about
30-90 KB rather than the megabyte a stock recording would cost, which matters
when nineteen of them ship in the APK.

**Thematic, as of 9 September 2026.** The first version of this file summed
sine waves, so every tone was an abstract arrangement of beeps that contrasted
with its neighbours but did not *mean* anything. The user asked for the other
thing: «كل صوت لازم يبقى واضح إنه بتاع المهمة دي» — water should sound like
water, walking like footsteps. So the primitives below are the ones that make
physical sounds rather than musical ones: filtered noise for water and page
turns, damped noise bursts for footsteps and wooden knocks, inharmonic partials
for bells and coins, and pitch sweeps for birdsong.

The design rule is unchanged and is what the feature is *for*: the user must
know which task is calling **by ear, without looking at the screen**. Sounding
like the thing is the strongest way to do that, but distinctness still wins any
tie — see `_DISTINCTNESS` at the bottom for the pairs that were deliberately
pushed apart.

An adhan is deliberately **not** here. A synthesised approximation of a muezzin
would be worse than the placeholder it replaced; real recitations are
performances with rights holders, and which one to use is a matter of taste and
religious preference. See tool/install_adhan_sound.sh.

Changing a sound here is only half the job. **Android freezes a channel's sound
at creation**, so a retuned tone that keeps its old channel id ships new audio
and keeps playing the old sound, silently, on every device that already has the
channel. Bump that kind's channel version in `lib/core/notifications/
task_alert.dart` in the same commit.

Run:  python tool/make_alert_sounds.py
"""

import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join("android", "app", "src", "main", "res", "raw")

rng = np.random.default_rng(20260909)  # Fixed: reruns must be byte-identical.


# ---------------------------------------------------------------- primitives


def silence(dur):
    return np.zeros(int(RATE * dur))


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(RATE * dur))


def band(x, lo, hi):
    """Zero out everything outside [lo, hi] Hz.

    An FFT brick wall rather than a designed filter: scipy is not a dependency
    of this repo and the artefacts of a brick wall are inaudible under noise,
    which is the only thing it is ever applied to here.
    """
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spec[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(spec, n=len(x))


def env(dur, attack=0.005, decay=8.0):
    """A struck envelope: near-instant attack, exponential decay."""
    t = t_axis(dur)
    e = np.exp(-decay * t)
    a = int(attack * RATE)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def swell(dur, peak=0.35):
    """A blown/bowed envelope: rises to `peak` of its length, then falls.

    The difference between a struck sound and a swelled one is most of what
    separates «قيام» (a bell, struck) from «صيام» (a gong, swelled) by ear.
    """
    t = t_axis(dur)
    p = peak * dur
    up = np.clip(t / p, 0, 1) ** 2
    down = np.exp(-2.5 * np.clip(t - p, 0, None))
    return up * down


def tone(freq, dur, decay=6.0, attack=0.005, partials=(1.0,)):
    """A pitched note. `partials` are amplitude multipliers on 1f, 2f, 3f..."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, amp in enumerate(partials, start=1):
        out += amp * np.sin(2 * np.pi * freq * i * t)
    return out * env(dur, attack, decay)


def metallic(freq, dur, decay=3.0, ratios=(1.0, 2.76, 5.40, 8.93)):
    """A bell. The ratios are inharmonic, which is what makes it metal.

    Roughly the modes of a struck bar; harmonic ratios (2, 3, 4) would give a
    warm organ-like note instead, which is why `tone` and `metallic` are two
    functions and not one with a flag.
    """
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, r in enumerate(ratios):
        # Higher modes die faster, as they do in a real bell.
        out += (0.8**i) * np.sin(2 * np.pi * freq * r * t) * np.exp(
            -decay * (1 + 0.7 * i) * t
        )
    e = env(dur, attack=0.002, decay=0.0)
    return out * e


def sweep(f0, f1, dur, decay=6.0, vibrato=0.0):
    """A glide from f0 to f1. Birdsong, and the falling pitch of a water drop."""
    t = t_axis(dur)
    f = np.linspace(f0, f1, len(t))
    if vibrato:
        f = f * (1 + vibrato * np.sin(2 * np.pi * 28 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(dur, 0.004, decay)


def thump(dur=0.16, lo=60, hi=220, decay=26.0, scuff=0.25):
    """One footstep: a low body plus a little high scuff of shoe on ground.

    Without the scuff it is a drum; with it, it is a step.
    """
    body = band(noise(dur), lo, hi) * env(dur, 0.001, decay)
    top = band(noise(dur), 3000, 8000) * env(dur, 0.001, decay * 4) * scuff
    return body + top


def knock(dur=0.14, freq=380, decay=40.0, lo_click=900, hi_click=5000):
    """Wood struck: a click with a short damped resonance under it.

    The click band is what makes a knock heavy or light: a fist on a door is
    dull and low, a bead against a bead is bright and small. It is the only
    thing keeping «إقامة» and «تسبيح» apart, so it is a parameter.
    """
    click = band(noise(dur), lo_click, hi_click) * env(dur, 0.0005, decay * 2.2)
    body = np.sin(2 * np.pi * freq * t_axis(dur)) * env(dur, 0.001, decay)
    return 0.55 * click + 0.75 * body


def swish(dur=0.45, lo=1800, hi=7000):
    """A page turning: broadband noise that swells and dies, no pitch at all."""
    return band(noise(dur), lo, hi) * swell(dur, peak=0.4)


def place(canvas, part, at):
    """Mixes `part` into `canvas` starting at `at` seconds, clipping the tail."""
    s = int(at * RATE)
    n = min(len(part), len(canvas) - s)
    if n > 0:
        canvas[s : s + n] += part[:n]
    return canvas


# ------------------------------------------------------------------- sounds
#
# Each builder returns a mono float array. The name of the task is in the
# function name; the sentence above it says what the user should hear.


def s_water():
    """Water running, with three drops falling into it. Pitch falls, as water does.

    The stream carries the whole length rather than swelling and dying: running
    water is the one sound in this set that is *continuous*, and that alone is
    what keeps it from being confused with the evening birds, which occupy a
    similar band in similar bursts. Measured, not guessed — see the distinctness
    note at the bottom of this file.
    """
    out = silence(1.8)
    # The stream: mid-band noise, gently gurgling via slow amplitude modulation.
    stream = band(noise(1.8), 450, 5000)
    t = t_axis(1.8)
    gurgle = 0.62 + 0.38 * np.sin(2 * np.pi * 6.5 * t) * np.sin(2 * np.pi * 2.3 * t)
    # Flat through the middle: on from the first moment, off only at the end.
    hold = np.clip(np.minimum(t / 0.12, (1.8 - t) / 0.25), 0, 1)
    place(out, stream * gurgle * hold * 0.85, 0.0)
    # Three drops. A falling drop's resonance rises as the cavity closes, so
    # each of these sweeps *up* briefly — the classic "plink".
    for at, f in ((0.22, 900), (0.74, 1150), (1.24, 760)):
        place(out, sweep(f, f * 1.9, 0.13, decay=22) * 0.38, at)
    return out


def s_walk():
    """Four footsteps at a walking pace. Low thumps, alternating slightly."""
    out = silence(1.35)
    for i, at in enumerate((0.0, 0.30, 0.60, 0.90)):
        # Left and right are never identical, so alternate the body pitch.
        lo, hi = (60, 200) if i % 2 == 0 else (75, 240)
        place(out, thump(0.20, lo, hi, decay=24) * 0.95, at)
    return out


def s_workout():
    """A coach's whistle: two short blasts with the warble a pea whistle makes."""
    out = silence(1.0)
    for at in (0.0, 0.34):
        t = t_axis(0.22)
        # ~2.8 kHz with a fast warble, plus breath noise through the same band.
        warble = 2800 * (1 + 0.045 * np.sin(2 * np.pi * 38 * t))
        body = np.sin(2 * np.pi * np.cumsum(warble) / RATE)
        breath = band(noise(0.22), 2200, 5200) * 0.35
        place(out, (body + breath) * env(0.22, 0.012, 5.0) * 0.75, at)
    return out


def s_meal():
    """A spoon rung twice against a glass. Bright, warm, an invitation."""
    out = silence(1.4)
    place(out, metallic(660, 1.1, decay=2.6) * 0.8, 0.0)
    place(out, metallic(880, 1.0, decay=2.8) * 0.6, 0.45)
    return out


def s_tasbeeh():
    """Three prayer beads passing between the fingers. Light, wooden, even."""
    out = silence(1.0)
    for at in (0.0, 0.24, 0.48):
        place(out, knock(0.11, freq=1020, decay=58, lo_click=1800,
                        hi_click=8000) * 0.7, at)
    return out


def s_wird():
    """A page of the mushaf turning, then one calm low note. Never hurried."""
    out = silence(1.6)
    place(out, swish(0.5, 1600, 6500) * 0.6, 0.0)
    place(out, tone(294, 1.0, decay=3.2, partials=(1.0, 0.35, 0.12)) * 0.5, 0.42)
    return out


def s_athkar_morning():
    """Birds at first light: three short chirps, rising."""
    out = silence(1.2)
    for at, f0, f1 in ((0.0, 1900, 3100), (0.26, 2200, 3500), (0.54, 2500, 3900)):
        place(out, sweep(f0, f1, 0.13, decay=16, vibrato=0.05) * 0.55, at)
    return out


def s_athkar_evening():
    """The mirror of the morning: the same birds, settling. Lower, falling."""
    out = silence(1.3)
    for at, f0, f1 in ((0.0, 1900, 1050), (0.32, 1600, 880), (0.66, 1350, 720)):
        place(out, sweep(f0, f1, 0.20, decay=10, vibrato=0.04) * 0.55, at)
    return out


def s_athkar_sleep():
    """A hum in a dark room. Two low notes falling, no metal anywhere in it."""
    out = silence(2.0)
    place(out, tone(233, 1.1, decay=1.6, attack=0.15, partials=(1.0, 0.3)) * 0.6, 0.0)
    place(out, tone(175, 1.2, decay=1.3, attack=0.20, partials=(1.0, 0.25)) * 0.6, 0.75)
    return out


def s_qiyam():
    """A single distant bell in the night. It must invite, never startle.

    Struck bells begin at full loudness — that is what being struck means, and
    it is exactly wrong for a sound that arrives around 01:30 beside a sleeping
    man. So the strike is faded in over a quarter of a second: the bell seems
    to come from another room rather than from the pillow. `alert_sound_
    character_test` measures this and fails if the attack sharpens again.
    """
    out = silence(2.4)
    bell = metallic(392, 2.3, decay=0.9) * 0.42
    rise = np.clip(t_axis(2.3) / 0.25, 0, 1) ** 2
    place(out, bell * rise, 0.0)
    return out


def s_knowledge():
    """A page turning, then one bright small chime. The sound of catching on."""
    out = silence(1.3)
    place(out, swish(0.34, 2400, 7000) * 0.5, 0.0)
    place(out, metallic(1046, 0.85, decay=3.4) * 0.5, 0.30)
    return out


def s_phone():
    """Deliberately the plainest sound here. It is a cap, not a treat."""
    out = silence(0.85)
    for at in (0.0, 0.30):
        t = t_axis(0.20)
        # A dull gated buzz: the texture of a notification you are not glad to get.
        buzz = np.sign(np.sin(2 * np.pi * 165 * t)) * 0.5
        gate = (np.sin(2 * np.pi * 42 * t) > 0).astype(float)
        place(out, band(buzz * gate, 90, 900) * env(0.20, 0.01, 9.0) * 0.55, at)
    return out


def s_calls():
    """An old telephone ringing. Two bursts of the two-tone warble."""
    out = silence(1.6)
    for at in (0.0, 0.62):
        t = t_axis(0.42)
        pair = np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 480 * t)
        # 20 Hz gating is what gives a landline ring its distinctive rasp.
        gate = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 20 * t))
        place(out, pair * gate * env(0.42, 0.02, 3.0) * 0.42, at)
    return out


def s_budget():
    """Coins set down on a table. Small, bright, and over quickly."""
    out = silence(1.0)
    for at, f in ((0.0, 1500), (0.13, 1850), (0.29, 1320)):
        place(out, metallic(f, 0.45, decay=9.0, ratios=(1.0, 3.1, 6.7)) * 0.42, at)
    return out


def s_reminder():
    """A plain gentle bell. Generic on purpose — it announces the user's own words."""
    out = silence(1.4)
    place(out, metallic(784, 1.3, decay=1.9, ratios=(1.0, 2.76, 5.40)) * 0.6, 0.0)
    return out


def s_fasting():
    """A low gong, swelled rather than struck. Offered in the evening, unhurried."""
    out = silence(2.2)
    t = t_axis(2.1)
    body = (
        np.sin(2 * np.pi * 146 * t)
        + 0.5 * np.sin(2 * np.pi * 146 * 2.1 * t)
        + 0.25 * np.sin(2 * np.pi * 146 * 3.4 * t)
    )
    place(out, body * swell(2.1, peak=0.18) * 0.6, 0.0)
    return out


def s_review():
    """Three notes closing downward. The day is being put away."""
    out = silence(1.6)
    for at, f in ((0.0, 587), (0.26, 494), (0.52, 392)):
        place(out, tone(f, 0.8, decay=4.0, partials=(1.0, 0.25)) * 0.5, at)
    return out


def s_followup():
    """The quietest and shortest thing here. It is only asking, and must not nag."""
    out = silence(0.5)
    place(out, tone(880, 0.22, decay=14.0) * 0.30, 0.0)
    return out


def s_iqama():
    """Two firm knocks — the call to stand and straighten the rows.

    Lower and firmer than the three light beads of «تسبيح», and nothing like
    the adhan, which is a recitation. Telling these two apart is the single
    most important distinction in the whole set: they arrive minutes apart.
    """
    out = silence(0.9)
    for at in (0.0, 0.26):
        place(out, knock(0.24, freq=190, decay=20, lo_click=300,
                        hi_click=1600) * 0.95, at)
    return out


SOUNDS = {
    "alert_water": s_water,
    "alert_walk": s_walk,
    "alert_workout": s_workout,
    "alert_meal": s_meal,
    "alert_tasbeeh": s_tasbeeh,
    "alert_wird": s_wird,
    "alert_athkar_morning": s_athkar_morning,
    "alert_athkar_evening": s_athkar_evening,
    "alert_athkar_sleep": s_athkar_sleep,
    "alert_qiyam": s_qiyam,
    "alert_knowledge": s_knowledge,
    "alert_phone": s_phone,
    "alert_calls": s_calls,
    "alert_budget": s_budget,
    "alert_reminder": s_reminder,
    "alert_fasting": s_fasting,
    "alert_review": s_review,
    "alert_followup": s_followup,
    "alert_iqama": s_iqama,
}

# Pairs that a first draft made too alike, and what now separates them. Written
# down because the fix is invisible in the code — it lives in one constant each
# — and because the next person to retune one of these needs to know what it is
# being kept apart from.
_DISTINCTNESS = """
sleep / qiyam / fasting  all three are low and soft, which is required: none
                         may startle. Separated by texture, not pitch — sleep
                         is a pure hum with no metal, qiyam is a struck bell
                         with a long shimmering tail, fasting is a swelled
                         gong with no attack at all.
tasbeeh / iqama / walk    all three are percussive. tasbeeh is three light
                         high beads, iqama two firm low knocks, walk four
                         thumps with a scuff of shoe on top and no pitch.
meal / budget / reminder all three are metal. meal is two warm low strikes,
                         budget three small bright clinks in quick succession,
                         reminder one clean bell alone.
water / wird / knowledge all three contain filtered noise. water runs for its
                         whole length and has drops in it, wird is one swish
                         then a low note, knowledge one swish then a high chime.
"""


def peak_normalise(buf, peak=0.72):
    """To about -3 dBFS, so no tone is louder than another. Loudness is the
    channel's job, not the file's — a file that is hot for its own sake makes
    the volume slider lie."""
    m = float(np.max(np.abs(buf))) or 1.0
    return buf / m * peak


def fade(buf, in_s=0.008, out_s=0.06):
    """Without this every tone starts and ends on a click."""
    a, b = int(in_s * RATE), int(out_s * RATE)
    if a > 0:
        buf[:a] *= np.linspace(0, 1, a)
    if b > 0:
        buf[-b:] *= np.linspace(1, 0, b)
    return buf


def write(name, buf):
    buf = fade(peak_normalise(np.asarray(buf, dtype=np.float64)))
    pcm = np.clip(buf, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return os.path.getsize(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, build in sorted(SOUNDS.items()):
        size = write(name, build())
        total += size
        print(f"  {name}.wav  {size // 1024} KB")
    print(f"\n{len(SOUNDS)} sounds, {total // 1024} KB total, written to {OUT}")
    print("\nRemember: a changed sound needs its channel version bumped in")
    print("lib/core/notifications/task_alert.dart, or devices that already have")
    print("the channel keep playing the old file. Android freezes it at creation.")
