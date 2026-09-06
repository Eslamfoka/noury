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
