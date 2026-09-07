import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'exercise.dart';
import 'exercise_animation.dart';
import 'interval_timer.dart';
import 'workout_catalogue.dart';
import 'workout_providers.dart';

/// Pick a routine, then be walked through it.
///
/// The interval rules live in [IntervalTimer], which is driven by [tick] so it
/// can be tested without real time. This screen owns the actual clock and the
/// drawing, and nothing else.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  IntervalTimer? _timer;
  Timer? _ticker;
  DateTime? _startedAt;

  @override
  void dispose() {
    _ticker?.cancel();
    _timer?.dispose();
    super.dispose();
  }

  void _startRoutine(Routine routine) {
    final t = IntervalTimer(routine)..start();
    setState(() {
      _timer = t;
      _startedAt = DateTime.now();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      t.tick(const Duration(seconds: 1));
      if (t.phase == IntervalPhase.done) unawaited(_finish());
    });
  }

  Future<void> _finish() async {
    final t = _timer;
    if (t == null) return;

    _ticker?.cancel();
    _ticker = null;

    // Read before the first await: after one the widget may be gone, and
    // losing the session at the last step would throw away work already done.
    final db = ref.read(databaseProvider);

    // A partial session is written too. Five exercises out of twenty is real,
    // and discarding it would be Nouri telling the user it did not count.
    await db.workoutDao.addSession(
      startedAt: _startedAt ?? DateTime.now(),
      routineId: t.routine.id,
      doneCount: t.doneCount,
      totalCount: t.totalCount,
      seconds: t.elapsed.inSeconds,
    );

    if (!mounted) return;
    ref
      ..invalidate(todayWorkoutsProvider)
      ..invalidate(recentWorkoutsProvider);

    setState(() => _timer = null);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = _timer;
    return Scaffold(
      backgroundColor: NouriColors.background,
      appBar: AppBar(
        backgroundColor: NouriColors.background,
        elevation: 0,
        title: Text('تمارين البيت',
            style: cairo(size: 16, weight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: t == null ? _picker() : _session(t),
      ),
    );
  }

  // ------------------------------------------------------------- picker

  Widget _picker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          'اختار تمرين',
          style: cairo(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        for (final r in kRoutines) ...[
          _RoutineCard(routine: r, onTap: () => _startRoutine(r)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _RecentWorkouts(),
      ],
    );
  }

  // ------------------------------------------------------------ session

  Widget _session(IntervalTimer t) {
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final resting = t.phase == IntervalPhase.rest;
        // During a rest the figure shows what is coming, held still.
        final shown = resting ? (t.upNext ?? t.current) : t.current;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: NouriColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ExerciseAnimation(
                    key: ValueKey('${shown.id}-$resting'),
                    exercise: shown,
                    playing: !resting && !t.isPaused,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (resting)
                Text(
                  'راحة — الجاي: ${shown.nameAr}',
                  key: const ValueKey('workout-rest'),
                  textAlign: TextAlign.center,
                  style: cairo(
                      size: 15,
                      weight: FontWeight.w700,
                      color: NouriColors.success),
                )
              else
                Text(
                  shown.nameAr,
                  key: const ValueKey('workout-exercise-name'),
                  textAlign: TextAlign.center,
                  style: cairo(size: 18, weight: FontWeight.w700),
                ),
              const SizedBox(height: 6),
              Text(
                shown.cueAr,
                textAlign: TextAlign.center,
                style: cairo(size: 11.5, color: NouriColors.muted, height: 1.7),
              ),
              const SizedBox(height: 14),
              Text(
                toArabicDigits('${t.remaining.inSeconds}'),
                key: const ValueKey('workout-countdown'),
                textAlign: TextAlign.center,
                style: cairo(
                  size: 46,
                  weight: FontWeight.w700,
                  height: 1.0,
                  color: resting ? NouriColors.success : NouriColors.gold,
                ),
              ),
              Text(
                'ثانية',
                textAlign: TextAlign.center,
                style: cairo(size: 11, color: NouriColors.muted),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: t.fraction,
                  minHeight: 6,
                  backgroundColor: NouriColors.surface,
                  valueColor:
                      const AlwaysStoppedAnimation(NouriColors.gold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                toArabicDigits(
                  '${t.doneCount} من ${t.totalCount} — '
                  '${(t.fraction * 100).round()}٪',
                ),
                key: const ValueKey('workout-progress'),
                textAlign: TextAlign.center,
                style: cairo(size: 12, color: NouriColors.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('workout-pause'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: NouriColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: t.pause,
                      child: Text(
                        t.isPaused ? 'كمّل' : 'وقّف',
                        style: cairo(size: 13.5, color: NouriColors.text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('workout-skip'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: NouriColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        t.skip();
                        if (t.phase == IntervalPhase.done) unawaited(_finish());
                      },
                      child: Text('التالي',
                          style: cairo(size: 13.5, color: NouriColors.text)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('workout-finish'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NouriColors.gold,
                        foregroundColor: NouriColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _finish,
                      child: Text(
                        'كفاية',
                        style: cairo(
                          size: 14,
                          weight: FontWeight.w700,
                          color: NouriColors.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = (routine.totalDuration.inSeconds / 60).round();

    return Material(
      color: NouriColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('routine-${routine.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: ExerciseAnimation(
                  exercise: routine.exercises.first,
                  playing: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(routine.nameAr,
                        style: cairo(size: 14.5, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(routine.descriptionAr,
                        style: cairo(size: 11.5, color: NouriColors.muted)),
                    const SizedBox(height: 5),
                    Text(
                      toArabicDigits(
                        '${routine.totalCount} تمرين · حوالي $minutes دقيقة',
                      ),
                      style: cairo(size: 10.5, color: NouriColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: NouriColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentWorkouts extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(recentWorkoutsProvider).value ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('آخر تمارينك',
            style: cairo(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final r in rows.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: NouriColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    routineById(r.routineId)?.nameAr ?? r.routineId,
                    style: cairo(size: 12.5),
                  ),
                  Text(
                    toArabicDigits('${r.doneCount} من ${r.totalCount}'),
                    style: cairo(size: 12, color: NouriColors.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
