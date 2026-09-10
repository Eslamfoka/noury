import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'body_providers.dart';

/// Records a weight reading in kilograms.
///
/// One number, no trend talk, no comment on whether it went up or down. The
/// brief puts the stomach ahead of the scale, and a companion that reacts to
/// the number is how a scale becomes something to avoid.
Future<void> showLogWeightSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _LogWeight(parentRef: ref),
    ),
  );
}

class _LogWeight extends StatefulWidget {
  const _LogWeight({required this.parentRef});

  final WidgetRef parentRef;

  @override
  State<_LogWeight> createState() => _LogWeightState();
}

class _LogWeightState extends State<_LogWeight> {
  final _kg = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grams = parseWeightKg(_kg.text);
    if (grams == null) {
      setState(() => _invalid = true);
      return;
    }

    await widget.parentRef
        .read(databaseProvider)
        .bodyDao
        .addWeight(at: DateTime.now(), grams: grams);
    widget.parentRef.invalidate(latestWeightProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: NouriColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('وزنك النهاردة',
                style: cairo(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 14),

            TextField(
              controller: _kg,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫]')),
              ],
              textAlign: TextAlign.center,
              style: cairo(size: 20, weight: FontWeight.w700),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                suffixText: 'كجم',
                suffixStyle: cairo(size: 13, color: NouriColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                filled: true,
                fillColor: NouriColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            if (_invalid) ...[
              const SizedBox(height: 9),
              Text('اكتب رقم زي ٨٧٫٤',
                  textAlign: TextAlign.center,
                  style: cairo(size: 11.5, color: NouriColors.attention)),
            ],

            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NouriColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _save,
              child: Text('احفظ',
                  style: cairo(
                    size: 16,
                    weight: FontWeight.w700,
                    color: NouriColors.background,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
