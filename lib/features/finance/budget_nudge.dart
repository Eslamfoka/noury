import 'budget_categories.dart';
import 'financial_month.dart';

/// How far past an even pace counts as worth mentioning.
///
/// Not "any amount over pace" — that would fire most evenings of most months
/// and stop meaning anything by the third one. A quarter of the whole budget
/// ahead of where an even rate would have you is a real signal.
const _aheadThreshold = 0.25;

/// One quiet line about money, or nothing at all.
///
/// §5.4 asks for a soft alert "when a category nears its limit ... so
/// month-end isn't a surprise". [BudgetStatus] already knew how to tell a
/// worrying number from an ordinary one — `pacedAllowance` exists precisely so
/// that 60% of the food budget reads as fine on day 18 and worth noticing on
/// day 4 — and none of it ever reached the user anywhere but the finance
/// screen.
///
/// Three rules hold it to being a note rather than a nag:
///
/// - **One line, whatever the month is doing.** Three separate notifications
///   about money in one evening is nagging, so several stretched categories
///   are named together.
/// - **Nothing unbudgeted is judged.** A limit of zero means "not budgeted",
///   not "overspent by everything spent".
/// - **صدقة is never flagged for being early.** Giving ahead of pace is not
///   overspending, and a nudge that read as "slow down on the charity" would
///   be Nouri saying something it has no business saying.
///
/// Returns null when there is nothing to say, which is most days.
String? budgetNudgeFor(Map<BudgetCategory, BudgetStatus> statuses) {
  final over = <BudgetCategory>[];
  final ahead = <BudgetCategory>[];

  for (final entry in statuses.entries) {
    final s = entry.value;
    if (s.limit <= 0) continue;
    if (entry.key == BudgetCategory.charity) continue;

    if (s.isOver) {
      over.add(entry.key);
    } else if (s.spent - s.pacedAllowance > s.limit * _aheadThreshold) {
      ahead.add(entry.key);
    }
  }

  if (over.isEmpty && ahead.isEmpty) return null;

  String names(List<BudgetCategory> cs) =>
      cs.map((c) => c.arabicLabel).join(' و');

  // States the number and leaves the decision where it belongs. No verb of
  // blame anywhere in either line.
  if (over.isNotEmpty) {
    return 'ميزانية ${names(over)} خلصت. باقي من الشهر شوية — '
        'تحب تراجعها؟';
  }
  return '${names(ahead)} ماشية أسرع من الشهر. لسه فيه وقت تظبطها.';
}

/// The hour the note arrives.
///
/// Evening, after the day's spending has happened and while there is still a
/// month left to do something about it. Deliberately not the morning: a note
/// about yesterday's total, before the day has started, is information without
/// a use.
const kBudgetNudgeHour = 20;
