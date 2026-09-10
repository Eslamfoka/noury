// Dev utility — prints computed prayer times so they can be eyeballed against
// a real local timetable. Not part of the app.
//
// ignore_for_file: avoid_print — this is a command-line tool; printing is its job.
//
//   dart run tool/print_prayer_times.dart
//   dart run tool/print_prayer_times.dart 2026-12-21

import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/hijri_date.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

/// Kuwait is UTC+3 with no DST. Printing in Kuwait wall-clock makes the output
/// comparable to a Kuwaiti timetable no matter where this machine is.
const kuwaitOffset = Duration(hours: 3);

String hhmm(DateTime t) {
  final k = t.toUtc().add(kuwaitOffset);
  return '${k.hour.toString().padLeft(2, '0')}:'
      '${k.minute.toString().padLeft(2, '0')}';
}

void main(List<String> args) {
  final date = args.isEmpty ? DateTime.now() : DateTime.parse(args.first);
  const cfg = GeoConfig.kuwaitCity;
  final times = const PrayerTimesService().forDate(date, cfg);

  final hijri = hijriFor(date);
  print('Kuwait City  ${cfg.latitude}, ${cfg.longitude}  '
      '(method: ${cfg.method}, asr: ${cfg.madhab})');
  print('${date.toIso8601String().substring(0, 10)}   ${hijri.formatted}');
  print('all times shown in Kuwait local time (UTC+3)');
  print('');
  print('  الفجر    ${hhmm(times.fajr)}');
  print('  الشروق   ${hhmm(times.sunrise)}');
  print('  الظهر    ${hhmm(times.dhuhr)}');
  print('  العصر    ${hhmm(times.asr)}');
  print('  المغرب   ${hhmm(times.maghrib)}');
  print('  العشاء   ${hhmm(times.isha)}');
}
