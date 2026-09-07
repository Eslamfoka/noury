import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'step_source.dart';
import 'steps_providers.dart';
import 'walk_session.dart';

/// A walking session: pick a length, start, watch it count.
///
/// The steps come from the OS's cumulative counter, so the number shown is
/// `current - atStart` and survives the app being backgrounded — Android keeps
/// counting while Nouri is not looking. What it does **not** survive is the app
/// being killed, and there is no foreground service yet: the session is honest
/// about being a thing you start and finish, not a pedometer running all day.
class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  static const _targets = <int>[15, 30, 45, 60];

  int _target = 30;
  bool _running = false;
  bool _paused = false;

  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  StepSource? _source;
  StreamSubscription<int>? _steps;
  int? _stepsAtStart;
  int _stepsNow = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _steps?.cancel();
    super.dispose();
  }

  int get _sessionSteps {
    final start = _stepsAtStart;
    if (start == null) return 0;
    // Clamped in walkStats: a reboot resets the OS counter to zero and this
    // delta goes negative.
    return _stepsNow - start;
  }

  Future<void> _start({required bool simulated}) async {
    final source = simulated
        ? SimulatedStepSource(startAt: 0, stepsPerTick: 2)
        : ref.read(stepSourceProvider);

    _source = source;
    _stepsAtStart = null;
    _stepsNow = 0;

    _steps = source.cumulativeSteps().listen((total) {
      if (!mounted) return;
      setState(() {
        // The first reading is the baseline, not a jump of several thousand
        // steps the user just took.
        _stepsAtStart ??= total;
        _stepsNow = total;
      });
    });

    setState(() {
      _running = true;
      _paused = false;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();

    // Deliberately not awaited. Cancelling the sensor subscription is cleanup,
    // and making the save wait on it would tie "did my walk get recorded" to
    // "did the platform acknowledge the cancel" -- on a real EventChannel that
    // is a round trip that can hang, and inside a widget test's fake-async
    // zone it never completes at all, which is how this was found.
    unawaited(_steps?.cancel() ?? Future<void>.value());
    _steps = null;

    if (_source is SimulatedStepSource) {
      (_source! as SimulatedStepSource).dispose();
    }

    // Every `ref` read happens before the first await. After one, the widget
    // may have been unmounted and `ref` throws -- which would lose the walk
    // at the last step, after the user had already done it.
    final db = ref.read(databaseProvider);
    final weightFuture = ref.read(latestWeightGramsProvider.future);
    final settingsFuture = ref.read(settingsProvider.future);

    final weight = await weightFuture;
    final settings = await settingsFuture;

    final stats = walkStats(
      steps: _sessionSteps,
      elapsed: _elapsed,
      strideCm: settings.strideCm,
      weightGrams: weight,
    );

    // Written even when short of the target. Twelve minutes of a thirty-minute
    // walk is real, and discarding it would be Nouri telling the user it did
    // not count.
    await db.stepsDao.addSession(
      startedAt: _startedAt ?? DateTime.now(),
      seconds: _elapsed.inSeconds,
      steps: stats.steps,
      metres: stats.metres,
      kcal: stats.kcal,
      targetMinutes: _target,
    );

    if (!mounted) return;

    ref
      ..invalidate(todayWalksProvider)
      ..invalidate(todayStepsProvider)
      ..invalidate(recentWalksProvider);

    setState(() {
      _running = false;
      _paused = false;
    });
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NouriColors.background,
      appBar: AppBar(
        backgroundColor: NouriColors.background,
        elevation: 0,
        title: Text('المشي', style: cairo(size: 16, weight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _running ? _liveFace() : _setupFace(),
      ),
    );
  }

  // ------------------------------------------------------------ before

  Widget _setupFace() {
    final available = ref.watch(stepSensorAvailableProvider);
    final settings = ref.watch(settingsProvider);
    final allowSimulated = settings.value?.allowSimulatedSteps ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'هتمشي قد إيه؟',
            textAlign: TextAlign.center,
            style: cairo(size: 17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in _targets)
                GestureDetector(
                  key: ValueKey('walk-target-$m'),
                  onTap: () => setState(() => _target = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _target == m
                          ? NouriColors.gold
                          : NouriColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NouriColors.border),
                    ),
                    child: Text(
                      toArabicDigits('$m دقيقة'),
                      style: cairo(
                        size: 13,
                        weight:
                            _target == m ? FontWeight.w700 : FontWeight.w400,
                        color: _target == m
                            ? NouriColors.background
                            : NouriColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          available.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: NouriColors.gold),
            ),
            error: (_, _) => _noSensor(allowSimulated),
            data: (ok) => ok
                ? _startButton(
                    key: const ValueKey('walk-start'),
                    label: 'يلا نمشي',
                    onTap: () => _start(simulated: false),
                  )
                : _noSensor(allowSimulated),
          ),
          const SizedBox(height: 18),
          _TodaySoFar(),
        ],
      ),
    );
  }

  Widget _noSensor(bool allowSimulated) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NouriColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'جهازك مافيهوش حسّاس خطوات، فمش هقدر أعدّها.',
            key: const ValueKey('no-step-sensor'),
            textAlign: TextAlign.center,
            style: cairo(size: 13, color: NouriColors.muted, height: 1.8),
          ),
        ),
        if (allowSimulated) ...[
          const SizedBox(height: 14),
          _startButton(
            key: const ValueKey('walk-start-simulated'),
            label: 'جرّب بخطوات تجريبية',
            onTap: () => _start(simulated: true),
          ),
          const SizedBox(height: 8),
          Text(
            'الأرقام دي تجريبية، مش خطوات حقيقية.',
            textAlign: TextAlign.center,
            style: cairo(size: 11, color: NouriColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _startButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        backgroundColor: NouriColors.gold,
        foregroundColor: NouriColors.background,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: cairo(
          size: 16,
          weight: FontWeight.w700,
          color: NouriColors.background,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- during

  Widget _liveFace() {
    final weight = ref.watch(latestWeightGramsProvider).value ?? 0;
    final strideCm = ref.watch(settingsProvider).value?.strideCm ?? 72;

    final stats = walkStats(
      steps: _sessionSteps,
      elapsed: _elapsed,
      strideCm: strideCm,
      weightGrams: weight,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: walkFraction(_elapsed, _target),
                      strokeWidth: 9,
                      backgroundColor: NouriColors.surface,
                      valueColor:
                          const AlwaysStoppedAnimation(NouriColors.gold),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toArabicDigits('${stats.steps}'),
                        key: const ValueKey('walk-steps'),
                        style: cairo(
                            size: 44, weight: FontWeight.w700, height: 1.1),
                      ),
                      Text(
                        'خطوة',
                        style: cairo(size: 12, color: NouriColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatWalkClock(_elapsed),
                        style: cairo(
                          size: 14,
                          weight: FontWeight.w600,
                          color: NouriColors.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'المسافة',
                  value: formatDistance(stats.metres),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'السرعة',
                  value: formatPace(stats.metres, _elapsed),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'سعرات تقريبية',
                  value: weight == 0
                      ? '—'
                      : toArabicDigits('${stats.kcal}'),
                ),
              ),
            ],
          ),
          if (weight == 0) ...[
            const SizedBox(height: 8),
            Text(
              'سجّل وزنك في البدن عشان أقدر أقدّر السعرات.',
              textAlign: TextAlign.center,
              style: cairo(size: 10.5, color: NouriColors.muted),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('walk-pause'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: NouriColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => setState(() => _paused = !_paused),
                  child: Text(
                    _paused ? 'كمّل' : 'وقّف شوية',
                    style: cairo(size: 14, color: NouriColors.text),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('walk-finish'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NouriColors.gold,
                    foregroundColor: NouriColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _finish,
                  child: Text(
                    'خلّصت',
                    style: cairo(
                      size: 15,
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
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: cairo(size: 15, weight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: cairo(size: 10.5, color: NouriColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TodaySoFar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walks = ref.watch(todayWalksProvider);
    final rows = walks.value ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final steps = rows.fold<int>(0, (a, r) => a + r.steps);
    final metres = rows.fold<int>(0, (a, r) => a + r.metres);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مشيت النهاردة',
              style: cairo(size: 12.5, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            toArabicDigits('$steps خطوة · ${formatDistance(metres)}'),
            key: const ValueKey('walk-today-total'),
            style: cairo(size: 12, color: NouriColors.muted),
          ),
        ],
      ),
    );
  }
}
