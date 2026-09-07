import 'package:drift/drift.dart';

/// How a prayer was performed.
///
/// Ordered best to worst, but note that [none] is **not** a failure — it simply
/// has not been logged yet, and it is never counted against the user.
/// Appended, never reordered: drift stores these by index, so inserting a
/// value in the middle would silently rewrite every logged prayer.
enum PrayerState { mosque, congregation, onTime, late_, none, missed }

extension PrayerStateScore on PrayerState {
  int get score => switch (this) {
        PrayerState.mosque => 100,
        PrayerState.congregation => 85,
        PrayerState.onTime => 70,
        PrayerState.late_ => 40,
        // Scored as qada, like a late prayer. Honest self-reporting, not a
        // lower grade -- and Nouri never assigns it, the user chooses it.
        PrayerState.missed => 40,
        PrayerState.none => 0,
      };
}

class SettingsRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get locale => text().withDefault(const Constant('ar'))();

  RealColumn get latitude => real().withDefault(const Constant(29.3759))();
  RealColumn get longitude => real().withDefault(const Constant(47.9774))();
  TextColumn get cityLabel => text().withDefault(const Constant('الكويت'))();
  TextColumn get calculationMethod =>
      text().withDefault(const Constant('kuwait'))();
  TextColumn get madhab => text().withDefault(const Constant('shafi'))();

  /// The civil Hijri calculation can differ from local sighting by a day.
  IntColumn get hijriOffsetDays => integer().withDefault(const Constant(0))();

  TextColumn get iqamaOffsetsJson => text().withDefault(const Constant(
      '{"fajr":20,"dhuhr":15,"asr":15,"maghrib":10,"isha":15}'))();

  TextColumn get adhanSoundMode => text().withDefault(const Constant('chime'))();
  IntColumn get tasbeehTarget => integer().withDefault(const Constant(100))();
  IntColumn get khatmaTotalPages =>
      integer().withDefault(const Constant(604))();

  BoolColumn get notifyAdhan => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyIqama => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyAthkar => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyWird => boolean().withDefault(const Constant(true))();

  /// The evening-before offer for the sunnah fasts — Mondays, Thursdays and
  /// the white days. On by default like the other religious reminders.
  BoolColumn get notifyFasting =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();

  /// Payday. The brief says the salary lands between the 20th and the 25th,
  /// so the financial month starts there rather than on the 1st.
  IntColumn get financialMonthStartDay =>
      integer().withDefault(const Constant(25))();

  /// Monthly income in fils. Zero means "not set" — Nouri shows a dash for
  /// the savings rate rather than inventing one.
  IntColumn get monthlyIncomeFils =>
      integer().withDefault(const Constant(0))();

  /// When the 8-hour eating window opens. Noon by default, giving 12:00-20:00;
  /// a night-shift worker will want it later.
  IntColumn get eatingWindowStartHour =>
      integer().withDefault(const Constant(12))();

  /// The brief's target: 87 kg now, 74 kg goal. Stored in grams, like money in
  /// fils -- a trend built from accumulated floating-point error is worse than
  /// no trend at all.
  IntColumn get targetWeightGrams =>
      integer().withDefault(const Constant(74000))();

  /// Walking stride, centimetres. 72 cm is a common adult average; the whole
  /// distance readout is only as honest as this number, so it is adjustable
  /// rather than baked in.
  IntColumn get strideCm => integer().withDefault(const Constant(72))();

  /// Whether the walk screen may run its simulated step source.
  ///
  /// A debug aid, off by default and deliberately opt-in: the emulator has no
  /// step-counter hardware, and a walk that quietly invented steps on a real
  /// phone would be a lie told by the app about the user's own body.
  BoolColumn get allowSimulatedSteps =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PrayerLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get prayer => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  IntColumn get state => intEnum<PrayerState>()();
  IntColumn get score => integer()();
  DateTimeColumn get loggedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, prayer}
      ];
}

class AthkarLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();

  /// morning | evening | sleep | tasbeeh
  TextColumn get type => text()();
  IntColumn get progressCount => integer().withDefault(const Constant(0))();
  IntColumn get targetCount => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, type}
      ];
}

class QuranLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get pagesRead => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date}
      ];
}

/// A single logged spend. Amounts are stored in the smallest unit (fils) as
/// integers -- money must never be a double.
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  IntColumn get amountFils => integer()();
  TextColumn get note => text().nullable()();
}

/// A monthly limit per category, keyed by the financial month's start date so
/// last month's budget is preserved when this month's changes.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get monthStart => dateTime()();
  TextColumn get category => text()();
  IntColumn get limitFils => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {monthStart, category}
      ];
}

/// How the stomach felt after a meal.
///
/// The brief is explicit that this matters more than the weight: the user has
/// post-meal pain, bloating and gas, and the log exists to surface patterns for
/// him and his doctor. Calorie counting is deliberately absent.
///
/// Appended, never reordered -- stored by index, like [PrayerState].
/// Reordering these would silently rewrite the user's medical history.
enum MealFeeling { good, bloating, pain, gas }

/// A logged meal and how the stomach felt afterwards.
///
/// No calories, by design: the brief rules calorie counting out and says
/// calming the stomach matters more than the number. [feeling] is stored as an
/// enum index, so [MealFeeling] is append-only.
class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  TextColumn get description => text().nullable()();
  IntColumn get feeling => intEnum<MealFeeling>()();
}

/// A weight reading, in grams.
///
/// Integer grams rather than a double: the same reason money is stored in
/// fils. A trend built from accumulated floating-point error is worse than no
/// trend at all.
class Weights extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  IntColumn get grams => integer()();
}
