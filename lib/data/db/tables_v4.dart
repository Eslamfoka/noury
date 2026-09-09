import 'package:drift/drift.dart';

/// Schema v4 — reminders, walking, workouts and challenges.
///
/// Split into its own file rather than growing `tables.dart` past the point
/// where the religious core is readable in one screen. Both are exported from
/// `nouri_database.dart`, so nothing downstream knows the difference.

/// How often a reminder comes back.
///
/// Appended, never reordered: drift stores this by index, so inserting a value
/// in the middle would silently turn every «مرة واحدة» reminder into a daily
/// one. Same rule as [PrayerState] and [MealFeeling].
enum ReminderRepeat { once, daily, weekly, monthly }

/// Something the user asked to be reminded of, on a day they picked.
///
/// The time is stored as minutes past midnight rather than a `DateTime`: the
/// reminder is "09:30 on this day", a wall-clock intent, and a repeat has to
/// keep meaning 09:30 across a DST boundary. Storing an instant and adding
/// days to it is exactly the bug that moved the pay cycle an hour.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Midnight local on the day the user picked — the first occurrence for a
  /// repeat, and the only one for a one-off.
  DateTimeColumn get onDate => dateTime()();

  /// Minutes past midnight, 0–1439.
  IntColumn get minutes => integer()();

  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  IntColumn get repeat => intEnum<ReminderRepeat>()();

  /// Marked done by the user. A done reminder is never rearmed, and it is
  /// shown muted rather than struck out — nothing in Nouri is a failure.
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}

/// One completed walking session.
///
/// Metres and kcal are stored as integers, computed once at the end from the
/// step count. Recomputing them later from steps would silently change history
/// the day the user adjusts their stride.
class WalkSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get seconds => integer()();
  IntColumn get steps => integer()();
  IntColumn get metres => integer()();
  IntColumn get kcal => integer()();

  /// What the user set out to do, in minutes — kept so a 12-minute session
  /// against a 30-minute target still reads as an honest attempt rather than
  /// an unexplained short walk.
  IntColumn get targetMinutes => integer()();
}

/// One workout session, complete or partial.
///
/// A partial session is written too. Five exercises out of twenty is real
/// work, and discarding it would be the app telling the user it did not count.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get routineId => text()();
  IntColumn get doneCount => integer()();
  IntColumn get totalCount => integer()();
  IntColumn get seconds => integer()();
}

/// The user having joined a challenge on a given day.
///
/// Progress is never stored — it is derived from the prayer, athkar and walk
/// logs on every read. Two sources of truth for "did I pray in the mosque on
/// the 3rd" is one too many, and the derived one can never drift.
class ChallengeEnrollments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get challengeId => text()();

  /// Midnight local. Days before this never count toward the challenge.
  DateTimeColumn get startedOn => dateTime()();

  /// Set when the user steps away from a challenge. Kept rather than deleted:
  /// an abandoned forty days is still something they did.
  DateTimeColumn get abandonedOn => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {challengeId, startedOn}
      ];
}

/// Glasses of water drunk on a day.
///
/// One row per day rather than one per glass. The user taps a plus button; the
/// interesting number is the day's total, and a row per tap would be a lot of
/// rows to say the same thing.
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Midnight local.
  DateTimeColumn get date => dateTime()();
  IntColumn get glasses => integer().withDefault(const Constant(0))();
  IntColumn get targetGlasses => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date}
      ];
}

/// A day the user has said they are fasting.
///
/// Set by the user, never inferred. Nouri suggests the sunnah fasts but has no
/// way of knowing whether one was kept, and guessing would be the difference
/// between a helpful app and one that tells a fasting person to drink water at
/// noon. A row here is the user saying so.
class FastingDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date}
      ];
}

/// The three faces of "knowledge time".
///
/// Appended, never reordered: stored by index like every other enum here.
enum KnowledgeKind { reading, skill, religiousContent }

/// A session of knowledge time.
///
/// The brief treats reading, skill learning and religious content as **one
/// flexible block** that rotates rather than three daily items, so this is one
/// table with a kind rather than three tables. What Nouri *recommends* — which
/// book, which skill — is AI work and belongs with Slice 5; recording that the
/// time happened does not, and the planner already schedules it.
/// Time spent on the phone and on social apps, as the user reports it.
///
/// §5.5 asks Nouri to reserve a slot for this and to say when the cap is
/// passed. **Nouri does not read device usage.** Doing so needs
/// PACKAGE_USAGE_STATS — a special-access permission granted through a system
/// settings page — and it would make Nouri infer where every other pillar
/// asks: a fasting day is the user's word, a prayer is logged rather than
/// detected. The user starts the slot and Nouri times it.
///
/// Reversible in both directions: a usage-stats source could replace the
/// writer later without touching this table, and the cap is a setting.
class PhoneSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Midnight local.
  DateTimeColumn get date => dateTime()();
  IntColumn get minutes => integer()();

  DateTimeColumn get loggedAt => dateTime()();
}

class KnowledgeLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Midnight local.
  DateTimeColumn get date => dateTime()();
  IntColumn get kind => intEnum<KnowledgeKind>()();
  IntColumn get minutes => integer()();

  /// What was read or learned. Optional, and free text — Nouri has no library
  /// and does not pretend to.
  TextColumn get note => text().nullable()();

  DateTimeColumn get loggedAt => dateTime()();
}

/// Who the user is, in the terms a plan has to be built from.
///
/// **One row, like [SettingsRows].** It is a profile, not a log: there is
/// exactly one person using this app and nothing here is historical.
///
/// Kept separate from settings even so, because the two answer different
/// questions. Settings is *how Nouri should behave*; this is *who it is
/// behaving for*, and it is the payload that gets summarised and sent when the
/// user presses «ابني خطتي». Keeping them apart is what lets a test assert
/// that nothing from the logging tables ever leaves the device.
///
/// Every column is nullable and the screen never demands anything. A half-
/// filled profile still builds a plan — a worse one, and Nouri says so —
/// because a form that must be completed before the app is useful is the
/// stress this app exists to remove.
class ProfileRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get name => text().nullable()();

  /// Free text rather than an enum. The user asked for «النوع» without saying
  /// what the options were, and inventing a closed list on his behalf is the
  /// kind of guess this project has already paid for twice.
  TextColumn get gender => text().nullable()();

  DateTimeColumn get birthDate => dateTime().nullable()();

  /// `employee` · `student` · `both` · null.
  ///
  /// The branch the whole plan turns on: it decides whether the day is built
  /// around shifts or around lectures. Stored as text, not an enum index,
  /// because an enum's order is a migration hazard and this one is read by
  /// name when the summary is assembled.
  TextColumn get occupation => text().nullable()();

  /// How long one shift is, in hours.
  ///
  /// **Separate from the shift *type*, which lives in settings**, and the pair
  /// is what the user actually asked for: «نوع دوامك ايه وعدد ساعاتك دوامك
  /// ايه». The type says *when* a shift falls; this says *how much of the day
  /// it eats*, and nothing else in Nouri knew it.
  ///
  /// A plain number rather than an enum, because 8, 12, 16 and 24 are the
  /// common answers but not the only ones — a seven-hour shift is what this
  /// user actually works, and a closed list would have no room for it.
  IntColumn get dutyHours => integer().nullable()();

  /// A second job. Time that has to come out of the same day.
  TextColumn get secondJob => text().nullable()();

  /// The stage a student is at — «تانية ثانوي», «سنة تالتة هندسة».
  TextColumn get studyStage => text().nullable()();

  /// Lectures or classes in a normal week.
  IntColumn get weeklyLectures => integer().nullable()();

  /// Private-lesson hours in a normal week. Named separately from
  /// [weeklyLectures] because they sit at different times of day and the
  /// planner has to place them differently.
  IntColumn get weeklyPrivateLessons => integer().nullable()();

  /// How he eats and drinks, and how he sleeps, in his own words.
  ///
  /// Nouri already holds the *numbers* — the 16/8 window, the water target,
  /// the sleep length. These are the sentences around them: «بصوم الاتنين
  /// والخميس», «مبعرفش أنام قبل الفجر». Claude can read those; a column of
  /// integers cannot express them.
  TextColumn get eatingNotes => text().nullable()();
  TextColumn get sleepNotes => text().nullable()();

  /// What he is interested in. **The only input to the book recommendations**,
  /// which is the one thing he asked for that nothing else in the app knows.
  TextColumn get interests => text().nullable()();

  /// Where the profile photo is on disk.
  ///
  /// A path, not the bytes. A few hundred KB of JPEG in a row that every read
  /// of this table touches would slow every one of those reads down for the
  /// sake of one screen.
  TextColumn get photoPath => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// The fields the user added himself.
///
/// His words: «وحاجة كمان ممكن المستخدم يضيف … انا مش عارف احصرها» — he
/// could not enumerate them, so neither should the schema. A label and a
/// value, in his own language, passed through to Claude verbatim under a
/// heading that says these are the user's own.
///
/// Nouri deliberately does **not** try to interpret them. Reading an arbitrary
/// sentence is the thing the model is for, and a keyword matcher here would be
/// a worse version of the part being called.
class ProfileFieldRows extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text()();
  TextColumn get value => text()();

  /// Ordering is the user's, and stable: he sees them where he put them.
  IntColumn get position => integer().withDefault(const Constant(0))();

  DateTimeColumn get addedAt => dateTime()();
}
