import '../../data/db/nouri_database.dart';

/// Which of today's planned tasks the user has already done.
///
/// **Derived, never stored.** Every one of these is read back out of a log the
/// user was already keeping — a meal row, a walk session, the athkar
/// `completedAt`, the wird's pages. There is no `task_completions` table and
/// no second place for the truth to live, which is the same choice the
/// challenges made and for the same reason: two records of one fact drift.
///
/// It exists to stop Nouri asking about something it can already see happened.
/// The «عملتها؟» that follows a task half an hour later is useful when the
/// answer is unknown and is nagging when it is not, and the whole tone of this
/// app depends on knowing the difference.
///
/// Conservative on purpose: a task counts as done only when there is a
/// positive record of it. An empty log means "not known to have happened", not
/// "skipped", and Nouri would rather ask a question the user has already
/// answered than go silent about something they still meant to do.
Future<Set<String>> completedTaskIdsFor(NouriDatabase db, DateTime date) async {
  final done = <String>{};

  // --- الديني ---------------------------------------------------------------

  final athkar = {
    for (final row in await db.athkarDao.forDate(date)) row.type: row,
  };
  if (athkar['morning']?.completedAt != null) done.add('morning-athkar');
  if (athkar['evening']?.completedAt != null) done.add('evening-athkar');
  if (athkar['sleep']?.completedAt != null) done.add('sleep-athkar');
  if (athkar['tasbeeh']?.completedAt != null) done.add('tasbeeh');

  final quran = await db.quranDao.forDate(date);
  if ((quran?.pagesRead ?? 0) > 0) done.add('quran-wird');

  // --- البدني ---------------------------------------------------------------

  // Two meals, one log. The first meal counts as eaten once anything is
  // logged; the second only once there are two. Ordering by count rather than
  // by clock deliberately — the 16/8 window owns *when* food is allowed, and
  // guessing which row was "the last meal" from its hour would put Nouri in
  // the business of judging a meal by its time.
  final meals = await db.bodyDao.mealsOn(date);
  if (meals.isNotEmpty) done.add('first-meal');
  if (meals.length >= 2) done.add('last-meal');

  if ((await db.stepsDao.sessionsOn(date)).isNotEmpty) done.add('walk');
  if ((await db.workoutDao.sessionsOn(date)).isNotEmpty) done.add('workout');

  // --- تطوير الذات ----------------------------------------------------------

  // Any of the three faces satisfies the block: the planner rotates them and
  // treats them as one thing, so logging a reading session answers the
  // question a "learn a skill" reminder was going to ask.
  if (await db.knowledgeDao.minutesOn(date) > 0) {
    done
      ..add('knowledge-read')
      ..add('knowledge-listen')
      ..add('knowledge-skill');
  }

  // --- الوقت والدوام --------------------------------------------------------

  if (await db.phoneDao.minutesOn(date) > 0) done.add('phone-time');

  // مكالمات is deliberately absent: Nouri does not read the call log, and
  // there is nothing else that could tell it whether a call happened. Asking
  // would be guessing, so مكالمات has no follow-up at all.

  return done;
}
