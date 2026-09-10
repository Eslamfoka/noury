import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';

/// The row vocabulary the settings pages are built from.
///
/// Lifted out of `settings_screen.dart` when الإعدادات became a menu of
/// sub-pages: the index and every section now draw from the same set, so a
/// switch looks the same wherever it appears. Nothing about any row changed in
/// the move — only where it lives.

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  /// Null on a section page, where the app bar already names it. Repeating the
  /// title immediately under itself reads as a mistake.
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 2),
              child: Text(title!,
                  style: cairo(size: 14, weight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: NouriColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: NouriColors.gold,
              inactiveThumbColor: NouriColors.muted,
            ),
          ],
        ),
      );
}

class ValueRow extends StatelessWidget {
  const ValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: cairo(size: 13.5)),
            Text(value, style: cairo(size: 13, color: NouriColors.muted)),
          ],
        ),
      );
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            Text(value, style: cairo(size: 13, color: NouriColors.muted)),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action,
                  style: cairo(size: 12.5, color: NouriColors.gold)),
            ),
          ],
        ),
      );
}

class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final chosen = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: NouriColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Text(label,
                        style: cairo(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final e in options.entries)
                      ListTile(
                        title: Text(e.value, style: cairo(size: 14)),
                        onTap: () => Navigator.of(ctx).pop(e.key),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
          if (chosen != null) onSelected(chosen);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: cairo(size: 13.5)),
              Row(
                children: [
                  Text(value,
                      style: cairo(size: 13, color: NouriColors.muted)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left,
                      size: 18, color: NouriColors.muted),
                ],
              ),
            ],
          ),
        ),
      );
}

class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            IconButton(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 18),
              color: NouriColors.muted,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 52,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: cairo(size: 13.5, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 18),
              color: NouriColors.gold,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

/// Asks for a stride in centimetres.
///
/// A plain number field rather than a slider: the user is copying a figure
/// they measured, not exploring a range.
Future<int?> askStride(BuildContext context, int current) async {
  final controller = TextEditingController(text: '$current');
  final value = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NouriColors.surface,
      title: Text('طول الخطوة بالسنتيمتر',
          style: cairo(size: 15, weight: FontWeight.w700)),
      content: TextField(
        key: const ValueKey('stride-field'),
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: cairo(size: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('إلغاء', style: cairo(size: 13)),
        ),
        TextButton(
          key: const ValueKey('stride-save'),
          onPressed: () =>
              Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
          child: Text('احفظ',
              style: cairo(size: 13, color: NouriColors.gold)),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
