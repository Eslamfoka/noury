import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/athkar/athkar_item.dart';
import '../../data/athkar/athkar_repository.dart';
import '../home/home_providers.dart';
import '../tasks/task_done.dart';
import '../shared/nouri_avatar.dart';
import 'athkar_controller.dart';
import 'tasbeeh_controller.dart';
import 'widgets/dhikr_card.dart';
import 'widgets/tasbeeh_ring.dart';

final athkarRepositoryProvider = Provider<AthkarRepository>(
  (ref) => AthkarRepository(),
);

final athkarSetProvider = FutureProvider.family<AthkarSet, String>((
  ref,
  category,
) async {
  return ref.watch(athkarRepositoryProvider).load(category);
});

/// الأذكار والتسبيح — four tabs: التسبيح · الصباح · المساء · النوم
class AthkarScreen extends ConsumerStatefulWidget {
  const AthkarScreen({super.key});

  @override
  ConsumerState<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends ConsumerState<AthkarScreen> {
  static const _tabs = <(String, String)>[
    ('tasbeeh', 'التسبيح'),
    ('morning', 'الصباح'),
    ('evening', 'المساء'),
    ('sleep', 'النوم'),
  ];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 18, 15, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الأذكار والتسبيح',
                    style: cairo(size: 17, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'وردك اليومي',
                    style: cairo(size: 11.5, color: NouriColors.muted),
                  ),
                ],
              ),
              const NouriAvatar(size: 36),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 0),
          child: _TabBar(
            tabs: [for (final t in _tabs) t.$2],
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: _tab == 0
              ? const _TasbeehTab()
              : _AthkarTab(
                  key: ValueKey(_tabs[_tab].$1),
                  category: _tabs[_tab].$1,
                ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? NouriColors.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: cairo(
                      size: 12,
                      weight: i == selected ? FontWeight.w700 : FontWeight.w400,
                      color: i == selected
                          ? NouriColors.background
                          : NouriColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- tasbeeh

class _TasbeehTab extends ConsumerStatefulWidget {
  const _TasbeehTab();

  @override
  ConsumerState<_TasbeehTab> createState() => _TasbeehTabState();
}

class _TasbeehTabState extends ConsumerState<_TasbeehTab> {
  final _controller = TasbeehController();
  bool _restored = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    // Once the target is reached the tasbeeh is done, so its reminder and its
    // question have been answered.
    if (_controller.count >= _controller.target) {
      await silenceTaskAlarms(ref, const ['tasbeeh']);
    }

    await ref
        .read(databaseProvider)
        .athkarDao
        .upsert(
          date: DateTime.now(),
          type: 'tasbeeh',
          progress: _controller.count,
          target: _controller.target,
        );
    ref.invalidate(todayAthkarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayAthkarProvider);

    // Restore once, after both the target and today's progress are known.
    if (!_restored && settings.hasValue && today.hasValue) {
      final row = today.value!['tasbeeh'];
      _controller.restore(
        count: row?.progressCount ?? 0,
        target: row?.targetCount ?? settings.value!.tasbeehTarget,
      );
      _restored = true;
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: NouriColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'سُبْحَانَ اللهِ وَبِحَمْدِهِ\nسُبْحَانَ اللهِ الْعَظِيمِ',
                textAlign: TextAlign.center,
                style: NouriText.dhikr,
              ),
            ),
            const SizedBox(height: 18),
            TasbeehRing(
              count: _controller.count,
              target: _controller.target,
              onTap: () {
                _controller.increment();
                _persist();
              },
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _controller.fraction,
                minHeight: 6,
                backgroundColor: NouriColors.surface,
                valueColor: const AlwaysStoppedAnimation(NouriColors.gold),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: NouriColors.gold,
                      foregroundColor: NouriColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      _controller.increment();
                      _persist();
                    },
                    child: Text(
                      'سبّح',
                      style: cairo(
                        size: 17,
                        weight: FontWeight.w700,
                        color: NouriColors.background,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _IconButton(
                  icon: Icons.refresh,
                  tooltip: 'إعادة',
                  onTap: () {
                    _controller.reset();
                    _persist();
                  },
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              toArabicDigits('الهدف ${_controller.target} — تقدر تزوّده'),
              style: cairo(size: 11.5, color: NouriColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: NouriColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: NouriColors.border),
          ),
          child: Icon(icon, color: NouriColors.muted, size: 20),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ athkar

class _AthkarTab extends ConsumerStatefulWidget {
  const _AthkarTab({super.key, required this.category});

  final String category;

  @override
  ConsumerState<_AthkarTab> createState() => _AthkarTabState();
}

class _AthkarTabState extends ConsumerState<_AthkarTab> {
  AthkarController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _persist(AthkarController c) async {
    await ref
        .read(databaseProvider)
        .athkarDao
        .upsert(
          date: DateTime.now(),
          type: widget.category,
          progress: c.completedItems,
          target: c.items.length,
        );
    ref.invalidate(todayAthkarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final set = ref.watch(athkarSetProvider(widget.category));

    return set.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NouriColors.gold),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'مش قادر أفتح الأذكار دلوقتي.',
            textAlign: TextAlign.center,
            style: cairo(size: 14, color: NouriColors.muted),
          ),
        ),
      ),
      data: (data) {
        _controller ??= AthkarController(data.items);
        final c = _controller!;

        // The dhikr scrolls; the action row stays pinned. A long text like
        // آية الكرسي would otherwise push «تمّ» below the fold and make the
        // screen's primary action unreachable without scrolling.
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      toArabicDigits(
                        'الذكر ${c.currentIndex + 1} من ${c.items.length}',
                      ),
                      style: cairo(size: 12, color: NouriColors.muted),
                    ),
                    _StepDots(controller: c),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
                  child: DhikrCard(
                    item: c.current,
                    repeatsDone: c.currentRepeats,
                    onTap: () {},
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.fraction,
                        minHeight: 6,
                        backgroundColor: NouriColors.surface,
                        valueColor: AlwaysStoppedAnimation(
                          c.isComplete ? NouriColors.success : NouriColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _IconButton(
                          icon: Icons.chevron_right,
                          tooltip: 'السابق',
                          onTap: c.previous,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: NouriColors.gold,
                              foregroundColor: NouriColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () {
                              c.tap();
                              _persist(c);
                            },
                            child: Text(
                              'تمّ',
                              style: cairo(
                                size: 17,
                                weight: FontWeight.w700,
                                color: NouriColors.background,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _IconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'التالي',
                          onTap: c.next,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.isComplete
                          ? 'خلّصت الورد. تقبّل الله.'
                          : 'لو مشغول دلوقتي، نوري هيفكّرك تاني بعدين.',
                      textAlign: TextAlign.center,
                      style: cairo(size: 11.5, color: NouriColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.controller});

  final AthkarController controller;

  /// Caps the dots so a 17-item set does not turn the row into a smear.
  static const maxDots = 12;

  @override
  Widget build(BuildContext context) {
    final total = controller.items.length;
    final shown = total <= maxDots ? total : maxDots;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _colorFor(i, total, shown),
              ),
            ),
          ),
      ],
    );
  }

  Color _colorFor(int dot, int total, int shown) {
    // Map the dot back to the item it represents when the set is long.
    final index = shown == total ? dot : (dot * total / shown).floor();
    if (controller.isDoneAt(index)) return NouriColors.success;
    if (index == controller.currentIndex) return NouriColors.gold;
    return NouriColors.surfaceActive;
  }
}
