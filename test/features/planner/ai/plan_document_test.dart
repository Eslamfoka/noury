import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/planner/ai/plan_document.dart';

/// Parsing what a language model actually sends back.
///
/// Every case below is a real shape a model reply takes, not a hypothetical:
/// fenced JSON, a courteous sentence before the object, `"30"` where `30` was
/// asked for, a truncated reply because `max_tokens` ran out, an invented task
/// id. The parser's job is to keep whatever is well-formed and drop the rest
/// **without ever throwing**, because the alternative is an exception on the
/// path that draws the user's day.
void main() {
  const allowed = {'walk', 'first-meal', 'tasbeeh', 'knowledge'};

  PlanParseResult parse(String raw) =>
      PlanDocument.parse(raw, allowedTaskIds: allowed);

  group('the shapes a reply actually arrives in', () {
    test('plain JSON', () {
      final r = parse('''
{"days":[{"date":"2026-09-10","tasks":[
  {"id":"walk","at":"17:30","minutes":30}]}],
 "books":[{"title":"الرحيق المختوم","why":"سيرة، ويهتم بالتاريخ"}],
 "note":"يومك فيه وقت أكتر مما تفتكر."}
''');

      expect(r.ok, isTrue);
      expect(r.document!.days, hasLength(1));
      expect(r.document!.days.first.tasks.first.id, 'walk');
      expect(r.document!.days.first.tasks.first.at,
          DateTime(2026, 9, 10, 17, 30));
      expect(r.document!.books.first.title, 'الرحيق المختوم');
      expect(r.document!.note, contains('وقت أكتر'));
    });

    test('wrapped in a ```json fence', () {
      final r = parse('''
```json
{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30"}]}]}
```
''');
      expect(r.ok, isTrue);
      expect(r.document!.days.first.tasks, hasLength(1));
    });

    test('with a sentence of preamble the prompt asked it not to add', () {
      // Models are polite. Throwing away an otherwise perfect plan over a
      // greeting would be a failure the user pays for in a wasted API call.
      final r = parse('''
اتفضل الخطة:
{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30"}]}]}
أتمنى تكون مناسبة.
''');
      expect(r.ok, isTrue);
      expect(r.document!.days.first.tasks.first.id, 'walk');
    });

    test('minutes as a string, which is as common as the number', () {
      final r = parse(
          '{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30","minutes":"45"}]}]}');
      expect(r.document!.days.first.tasks.first.minutes, 45);
    });

    test('minutes missing falls back rather than dropping the task', () {
      final r = parse(
          '{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30"}]}]}');
      expect(r.document!.days.first.tasks.first.minutes, 30);
    });
  });

  group('drop, never invent', () {
    test('a task id Nouri cannot ring is discarded, however plausible', () {
      // The decisive rule. A task with no alert never fires, and a silent row
      // in المهام reads as a promise Nouri made and did not keep.
      final r = parse('''
{"days":[{"date":"2026-09-10","tasks":[
  {"id":"walk","at":"17:30"},
  {"id":"meditation","at":"18:00"},
  {"id":"tasbeeh","at":"19:00"}]}]}
''');

      expect(r.document!.days.first.tasks.map((t) => t.id),
          ['walk', 'tasbeeh']);
      expect(r.droppedTaskIds, ['meditation'],
          reason: 'a model inventing the same id repeatedly is a prompt to fix');
    });

    test('a day whose tasks all fell away is not kept as an empty day', () {
      // Keeping it would blank المهام for that date and read as a plan that
      // said "do nothing today".
      final r = parse(
          '{"days":[{"date":"2026-09-10","tasks":[{"id":"meditation","at":"18:00"}]}]}');
      expect(r.document!.days, isEmpty);
    });

    test('an impossible date is rejected, not silently rolled over', () {
      // DateTime(2026, 13, 40) is a real DateTime in Dart — it becomes
      // February 2027. A plan for a day the user will never see is worse than
      // no plan for that day.
      final r = parse(
          '{"days":[{"date":"2026-13-40","tasks":[{"id":"walk","at":"17:30"}]}]}');
      expect(r.document!.days, isEmpty);
    });

    test('an impossible time is rejected the same way', () {
      final r = parse(
          '{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"29:70"}]}]}');
      expect(r.document!.days, isEmpty);
    });
  });

  group('nothing throws, whatever arrives', () {
    test('an empty reply', () {
      final r = parse('');
      expect(r.ok, isFalse);
      expect(r.failure, isNotNull);
    });

    test('prose with no JSON in it at all', () {
      final r = parse('معلش، مش قادر أساعد في ده.');
      expect(r.ok, isFalse);
    });

    test('a reply truncated halfway because max_tokens ran out', () {
      final r = parse(
          '{"days":[{"date":"2026-09-10","tasks":[{"id":"walk","at":"17:');
      expect(r.ok, isFalse);
      expect(r.failure, isNotNull);
    });

    test('a JSON array where an object was asked for', () {
      final r = parse('[1, 2, 3]');
      expect(r.ok, isFalse);
    });

    test('the right shape with every field the wrong type', () {
      // Must produce an empty plan, not an exception on the path that draws
      // the user's day.
      final r = parse(
          '{"days":"tomorrow","books":42,"note":{"a":1}}');
      expect(r.ok, isTrue);
      expect(r.document!.isEmpty, isTrue);
      expect(r.document!.note, isNull);
    });
  });

  group('partial plans are used as far as they go', () {
    test('a malformed day does not cost the well-formed ones', () {
      // §5 of the design: "The days that parsed are used; the rest fall back
      // per day." Rejecting the whole fortnight over one bad row would waste
      // a call the user paid for.
      final r = parse('''
{"days":[
  {"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30"}]},
  {"date":"not-a-date","tasks":[{"id":"walk","at":"17:30"}]},
  {"date":"2026-09-11","tasks":[{"id":"tasbeeh","at":"19:00"}]}]}
''');

      expect(r.document!.days.map((d) => d.date),
          [DateTime(2026, 9, 10), DateTime(2026, 9, 11)]);
    });

    test('days and tasks come back in order whatever order they were sent', () {
      final r = parse('''
{"days":[
  {"date":"2026-09-12","tasks":[{"id":"walk","at":"19:00"},{"id":"tasbeeh","at":"06:00"}]},
  {"date":"2026-09-10","tasks":[{"id":"walk","at":"17:30"}]}]}
''');

      expect(r.document!.days.first.date, DateTime(2026, 9, 10));
      expect(r.document!.days.last.tasks.map((t) => t.id),
          ['tasbeeh', 'walk']);
    });

    test('books survive even when every day was unusable', () {
      // He asked for the recommendations by name, and they do not depend on
      // the schedule parsing.
      final r = parse('''
{"days":[{"date":"bad","tasks":[]}],
 "books":[{"title":"مقدمة ابن خلدون"}]}
''');
      expect(r.document!.days, isEmpty);
      expect(r.document!.books.single.title, 'مقدمة ابن خلدون');
      expect(r.document!.books.single.why, isNull);
    });
  });
}
