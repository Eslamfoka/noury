import 'dart:io';
import 'dart:typed_data';

import 'package:nouri/core/notifications/task_alert.dart';

/// Where one alert kind's audio lives on disk.
///
/// Two formats since 13 September 2026. The tones Nouri synthesises are WAV,
/// written by `tool/make_alert_sounds.py`; the recordings the user supplied
/// are MP3, installed by `tool/install_alert_recordings.py`. The kind says
/// which it is, and the file on disk has to agree — a test asserts that,
/// because a flag that drifted from the file would make the sound screen
/// credit the wrong author and this helper open the wrong path.
File alertSoundFile(TaskAlertKind kind) => File(
      'android/app/src/main/res/raw/${kind.sound}'
      '${kind.recorded ? '.mp3' : '.wav'}',
    );

/// Length of an MP3 in seconds, by walking its frames.
///
/// No decoder in the test toolchain, and none needed: an MPEG audio frame
/// header states its bitrate and sample rate, from which its byte length and
/// its sample count both follow. Walk the frames, sum the samples. An ID3v2
/// tag at the front is skipped by its declared size; anything that is not a
/// valid header is stepped over a byte at a time, which is how every decoder
/// resynchronises too.
double mp3Seconds(File file) {
  final b = file.readAsBytesSync();
  var offset = 0;

  if (b.length > 10 &&
      b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
    // ID3v2: a synchsafe 28-bit size follows the 10-byte header.
    final size = ((b[6] & 0x7f) << 21) |
        ((b[7] & 0x7f) << 14) |
        ((b[8] & 0x7f) << 7) |
        (b[9] & 0x7f);
    offset = 10 + size;
  }

  var seconds = 0.0;
  while (offset + 4 <= b.length) {
    final frame = _frameAt(b, offset);
    if (frame == null) {
      offset += 1;
      continue;
    }
    seconds += frame.samples / frame.rate;
    offset += frame.length;
  }
  return seconds;
}

class _Frame {
  const _Frame({required this.length, required this.samples, required this.rate});
  final int length;
  final int samples;
  final int rate;
}

const _bitrateV1L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _bitrateV1L2 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384];
const _bitrateV1L1 = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448];
const _bitrateV2L1 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256];
const _bitrateV2L23 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];

_Frame? _frameAt(Uint8List b, int i) {
  if (b[i] != 0xff || (b[i + 1] & 0xe0) != 0xe0) return null;

  final version = (b[i + 1] >> 3) & 3; // 0 = v2.5, 2 = v2, 3 = v1
  final layerBits = (b[i + 1] >> 1) & 3; // 1 = III, 2 = II, 3 = I
  final bitrateIndex = (b[i + 2] >> 4) & 15;
  final rateIndex = (b[i + 2] >> 2) & 3;
  final padding = (b[i + 2] >> 1) & 1;

  if (version == 1 || layerBits == 0 || bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) {
    return null;
  }

  final layer = 4 - layerBits;
  final isV1 = version == 3;

  final rate = switch (version) {
        3 => const [44100, 48000, 32000],
        2 => const [22050, 24000, 16000],
        _ => const [11025, 12000, 8000],
      }[rateIndex];

  final table = isV1
      ? (layer == 1 ? _bitrateV1L1 : layer == 2 ? _bitrateV1L2 : _bitrateV1L3)
      : (layer == 1 ? _bitrateV2L1 : _bitrateV2L23);
  final bitrate = table[bitrateIndex] * 1000;

  final samples = layer == 1 ? 384 : (layer == 2 || isV1) ? 1152 : 576;

  final length = layer == 1
      ? (12 * bitrate ~/ rate + padding) * 4
      : samples ~/ 8 * bitrate ~/ rate + padding;

  if (length <= 4) return null;
  return _Frame(length: length, samples: samples, rate: rate);
}
