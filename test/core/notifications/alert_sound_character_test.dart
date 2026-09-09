import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/task_alert.dart';

/// Guards the *audio*, not the filenames.
///
/// There was a test called «water sounds like water» that asserted
/// `TaskAlertKind.water.sound == 'alert_water'`. It passed while every tone
/// was an interchangeable arrangement of sine beeps, and it would have gone on
/// passing if all nineteen files had held the same recording. A name is not a
/// sound.
///
/// The feature exists so the user can tell **which task is calling by ear,
/// without looking at the screen** — his words: «من الصوت أعرف المهمة دي
/// إيه». That is a claim about waveforms, so this reads the waveforms.
///
/// Four cheap measures, no FFT, all computed straight off the PCM:
///
/// - **duration**
/// - **onsets** — how many separate hits the ear gets
/// - **sustain** — the fraction of the sound that is continuously loud, which
///   is what separates something running (water) from something struck (a bell)
/// - **zero-crossing rate** — a decent proxy for brightness, and the cheapest
///   way to tell a dull knock from a bright bead
///
/// Retuning a tone into something already in the set fails this file.
void main() {
  final tones = {
    for (final kind in TaskAlertKind.values)
      kind.sound: _measure(File('android/app/src/main/res/raw/${kind.sound}.wav')),
  };

  group('every tone is audibly its own thing', () {
    test('no two tones measure alike', () {
      // 0.15 is set just under the closest legitimate pair rather than at a
      // round number, so the guard bites on the first genuine collision. When
      // it fails, the fix is to retune the newcomer in tool/make_alert_sounds.py
      // — never to lower this number.
      final names = tones.keys.toList();
      final collisions = <String>[];

      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final d = tones[names[i]]!.distanceTo(tones[names[j]]!);
          if (d < 0.15) {
            collisions.add('${names[i]} vs ${names[j]} (${d.toStringAsFixed(3)})');
          }
        }
      }

      expect(collisions, isEmpty,
          reason: 'these would be indistinguishable by ear:\n${collisions.join('\n')}');
    });

    test('the iqama and the tasbeeh are nothing like each other', () {
      // The most important pair in the set: they arrive minutes apart, and the
      // whole point of giving the iqama its own sound was that it must not be
      // mistaken for anything else. One is a firm low knock, the other three
      // small bright beads.
      final iqama = tones['alert_iqama']!;
      final tasbeeh = tones['alert_tasbeeh']!;

      expect(iqama.brightness, lessThan(tasbeeh.brightness / 2),
          reason: 'the iqama must be the duller of the two');
      expect(iqama.onsets, lessThan(tasbeeh.onsets),
          reason: 'two knocks against three beads');
    });
  });

  group('the tones that carry the shape of their task', () {
    test('water runs rather than being struck', () {
      // A stream is the one continuous sound in the set. If this drops it has
      // become a beep again, and «مياه» stops meaning water.
      expect(tones['alert_water']!.sustain, greaterThan(0.7));
    });

    test('walking lands as separate steps', () {
      expect(tones['alert_walk']!.onsets, greaterThanOrEqualTo(3));
      // And it is footfall, not a bell: a step does not ring on.
      expect(tones['alert_walk']!.sustain, lessThan(0.3));
    });

    test('the telephone rings in bursts rather than once', () {
      // The 20 Hz gating of a landline ring is the point; a single tone would
      // just be another chime.
      expect(tones['alert_calls']!.onsets, greaterThan(6));
    });

    test('the night tones do not startle', () {
      // قيام arrives around 01:30 and أذكار النوم at bedtime. Both must
      // build rather than hit, so neither may open like a struck bell.
      for (final name in ['alert_qiyam', 'alert_athkar_sleep']) {
        expect(tones[name]!.attackFraction, greaterThan(0.01),
            reason: '$name opens too abruptly for the hour it arrives at');
      }
    });

    test('the follow-up is the shortest thing here', () {
      // «مشيت؟» is only asking. It must not nag, and length is nagging.
      final followUp = tones['alert_followup']!.seconds;
      for (final entry in tones.entries) {
        if (entry.key == 'alert_followup') continue;
        expect(followUp, lessThanOrEqualTo(entry.value.seconds),
            reason: 'alert_followup should be no longer than ${entry.key}');
      }
    });
  });
}

/// What one tone measures, reduced to the four numbers above.
class _Tone {
  _Tone({
    required this.seconds,
    required this.onsets,
    required this.sustain,
    required this.brightness,
    required this.attackFraction,
  });

  final double seconds;
  final int onsets;

  /// Fraction of the tone spent above a quarter of its own peak.
  final double sustain;

  /// Zero-crossing rate over the loud parts — bright sounds cross more often.
  final double brightness;

  /// How far into the tone its peak arrives. A struck sound peaks at once; a
  /// swelled one takes its time, which is what makes it gentle.
  final double attackFraction;

  /// Scaled so no single measure dominates: a tone twice as long, or twice as
  /// bright, moves about as far as one with two extra onsets.
  List<double> get _vector =>
      [seconds / 2, onsets / 4, sustain * 2, brightness * 4];

  double distanceTo(_Tone other) {
    var sum = 0.0;
    final a = _vector, b = other._vector;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return math.sqrt(sum);
  }
}

_Tone _measure(File file) {
  final samples = _pcm(file);
  final rate = 22050;
  final frame = rate ~/ 100; // 10 ms

  // RMS envelope, normalised to the tone's own peak so a quiet tone is judged
  // on its shape rather than punished for being quiet.
  final envelope = <double>[];
  for (var i = 0; i + frame < samples.length; i += frame) {
    var sum = 0.0;
    for (var j = i; j < i + frame; j++) {
      sum += samples[j] * samples[j];
    }
    envelope.add(math.sqrt(sum / frame));
  }
  final peak = envelope.fold<double>(0, math.max);
  final norm = [for (final v in envelope) peak == 0 ? 0.0 : v / peak];

  // An onset is a rise past 0.35 that has first fallen back below 0.12, which
  // is what stops one ringing bell being counted as several.
  var onsets = 0;
  var armed = true;
  for (final v in norm) {
    if (armed && v > 0.35) {
      onsets++;
      armed = false;
    } else if (v < 0.12) {
      armed = true;
    }
  }

  final sustain = norm.where((v) => v > 0.25).length / norm.length;

  // Zero crossings, counted only where the signal is actually audible —
  // silence crosses zero constantly on noise alone and would swamp this.
  var crossings = 0, counted = 0;
  double? previous;
  for (final s in samples) {
    if (s.abs() <= 0.02) continue;
    if (previous != null && (s < 0) != (previous < 0)) crossings++;
    previous = s;
    counted++;
  }

  var peakFrame = 0;
  for (var i = 0; i < norm.length; i++) {
    if (norm[i] >= 0.999) {
      peakFrame = i;
      break;
    }
  }

  return _Tone(
    seconds: samples.length / rate,
    onsets: onsets,
    sustain: sustain,
    brightness: counted > 1 ? crossings / counted : 0,
    attackFraction: norm.isEmpty ? 0 : peakFrame / norm.length,
  );
}

/// Reads mono 16-bit PCM out of a RIFF/WAVE file as doubles in [-1, 1].
///
/// Walks the chunk list rather than assuming the 44-byte canonical header:
/// the Python `wave` module is free to emit others, and a wrong offset here
/// would make every measurement above quietly meaningless rather than fail.
List<double> _pcm(File file) {
  final bytes = file.readAsBytesSync();
  final view = ByteData.sublistView(bytes);

  var offset = 12; // past 'RIFF' <size> 'WAVE'
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final end = math.min(offset + 8 + size, bytes.length);
      final out = <double>[];
      for (var i = offset + 8; i + 1 < end; i += 2) {
        out.add(view.getInt16(i, Endian.little) / 32768.0);
      }
      return out;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('no data chunk in ${file.path}');
}
