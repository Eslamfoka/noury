import '../planner/shift.dart';

/// The earliest a قيام reminder may arrive before fajr.
///
/// Any closer and it stops being an invitation to the last third and becomes a
/// second fajr alarm — two notifications minutes apart, saying different
/// things, at the hour the user is least able to tell them apart.
const _floorBeforeFajr = Duration(minutes: 45);

/// A little way into the last third rather than at its opening.
///
/// The opening is often barely past midnight, which is a strange hour to be
/// woken and is usually still the first part of a night's sleep.
const _pastTheOpening = Duration(minutes: 20);

/// The shortest night worth dividing into thirds.
const _shortestNight = Duration(hours: 3);

/// When to offer قيام الليل, or null when the night does not allow it.
///
/// §5.1 of the brief: "Qiyam al-layl: a reminder, timed around the user's
/// sleep schedule." The sunnah time is the last third of the night, which runs
/// from `isha + ⅔ × (fajr − isha)` to fajr — so it moves with the sun through
/// the year instead of sitting on a clock hour.
///
/// Returns null on a night shift. The user is at work from 22:00 to 07:00, so
/// every minute of the last third is duty time; a reminder there is noise, not
/// an invitation, and Nouri would be asking for something it knows cannot be
/// done. Also null when the night is too short to divide sensibly.
///
/// The result is built from the two prayer times rather than by offsetting a
/// date, so the midnight crossing carries the right day even across a DST
/// boundary — this project has already had one alarm moved by an hour that
/// way.
DateTime? qiyamTimeFor({
  required DateTime isha,
  required DateTime fajrTomorrow,
  required ShiftType shift,
}) {
  if (shift == ShiftType.night) return null;

  final night = fajrTomorrow.difference(isha);
  if (night <= _shortestNight) return null;

  final lastThirdOpens = isha.add(night * (2 / 3));
  final at = lastThirdOpens.add(_pastTheOpening);
  final latest = fajrTomorrow.subtract(_floorBeforeFajr);

  // The floor wins on a short night: better a little early in the last third
  // than crowding fajr.
  if (!at.isBefore(latest)) {
    return latest.isAfter(lastThirdOpens) ? latest : null;
  }
  return at;
}

/// What the reminder says.
///
/// An invitation with a way out written into it. «لو قدرت» is the whole tone:
/// قيام is voluntary, and a notification that implied otherwise would be
/// scolding someone at two in the morning.
const qiyamTitle = 'قيام الليل';
const qiyamBody = 'الثلث الأخير — لو قدرت';
