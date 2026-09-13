import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/task_alert.dart';

import '../../support/alert_sound_files.dart';

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
/// **Two kinds of file since 13 September 2026.** Eleven of the nineteen are
/// now recordings the user chose himself and sent as MP3; the other eight are
/// still the tones `tool/make_alert_sounds.py` synthesises as WAV. The
/// waveform measures below run on the WAVs, which are plain PCM. The
/// recordings are his by choice — nothing here second-guesses what water
/// should sound like to him — so for those the guard is the cheaper and
/// more literal one: no two of them may be the same file, and each must be
/// long enough to be a sound at all.
///
/// Four cheap measures on the synthesised set, no FFT, all computed straight
/// off the PCM:
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
  final synthesised = TaskAlertKind.values.where((k) => !k.recorded).toList();
  final recorded = TaskAlertKind.values.where((k) => k.recorded).toList();

  final tones = {
    for (final kind in synthesised) kind.sound: _measure(alertSoundFile(kind)),
  };

  group('every tone is audibly its own thing', () {
    test('no two synthesised tones measure alike', () {
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

    test('no two recordings are the same file', () {
      // The literal version of the same promise. He sent eleven files; if two
      // of them were one recording under two names, two tasks would call in
      // the same voice and nothing else here would notice.
      final bytes = {
        for (final kind in recorded)
          kind.sound: alertSoundFile(kind).readAsBytesSync(),
      };
      final names = bytes.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          expect(listEquals(bytes[names[i]], bytes[names[j]]), isFalse,
              reason: '${names[i]} is byte-for-byte ${names[j]}');
        }
      }
    });

    test('every recording is long enough to be heard', () {
      // A truncated upload would still be a valid MP3. Half a second is
      // shorter than anything he sent by a factor of seven.
      for (final kind in recorded) {
        expect(mp3Seconds(alertSoundFile(kind)), greaterThan(0.5),
            reason: kind.sound);
      }
    });

    test('the kinds marked as recordings are the ones with an MP3 on disk', () {
      // `recorded` decides the extension the channel resolves and the credit
      // the sound screen prints. If it drifts from the file, the build fails
      // on a missing resource with a message that does not name the file —
      // so it is caught here first.
      for (final kind in TaskAlertKind.values) {
        expect(alertSoundFile(kind).existsSync(), isTrue,
            reason: '${kind.sound} says recorded=${kind.recorded} '
                'but the matching file is not there');
      }
    });
  });

  group('the tones that carry the shape of their task', () {
    test('the telephone rings in bursts rather than once', () {
      // The 20 Hz gating of a landline ring is the point; a single tone would
      // just be another chime.
      expect(tones['alert_calls']!.onsets, greaterThan(6));
    });

    test('the follow-up is the shortest thing here', () {
      // «مشيت؟» is only asking. It must not nag, and length is nagging. The
      // comparison runs across both kinds of file: his recordings are all
      // several seconds long, and the follow-up has to stay under every one.
      final followUp = tones['alert_followup']!.seconds;
      for (final kind in TaskAlertKind.values) {
        if (kind == TaskAlertKind.followUp) continue;
        final seconds = kind.recorded
            ? mp3Seconds(alertSoundFile(kind))
            : tones[kind.sound]!.seconds;
        expect(followUp, lessThanOrEqualTo(seconds),
            reason: 'alert_followup should be no longer than ${kind.sound}');
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
