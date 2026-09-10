import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import 'profile_providers.dart';

/// The fields the user adds himself.
///
/// His words, and the reason this is not a fixed form: *«وحاجة كمان ممكن
/// المستخدم يضيف داش بورد من عنده يضيف خاصية انا مش عارف احصرها»* — he could
/// not enumerate them, so the schema does not try to either.
///
/// A label and a value, in whatever language and whatever shape he wants.
/// They are passed to Claude verbatim under a heading that says they are the
/// user's own words. **Nouri does not interpret them**: reading an arbitrary
/// sentence is exactly what the model is for, and a keyword matcher here would
/// be a worse version of the thing being called.
class CustomFieldsSection extends ConsumerWidget {
  const CustomFieldsSection({super.key, required this.fields});

  final List<ProfileFieldRow> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(profileDaoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, right: 2),
          child:
              Text('حاجات تانية', style: cairo(size: 13, weight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 2),
          child: Text(
            'أي حاجة تانية نوري لازم يعرفها عشان يظبط يومك — نادي، مشوار '
            'ثابت، مسؤولية في البيت. اكتبها بكلامك.',
            style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: NouriColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              if (fields.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'لسه مضفتش حاجة.',
                    key: const ValueKey('custom-fields-empty'),
                    style: cairo(size: 12, color: NouriColors.muted),
                  ),
                ),
              for (final f in fields)
                Padding(
                  key: ValueKey('custom-field-${f.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label,
                                style: cairo(size: 13, weight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(f.value,
                                style: cairo(
                                    size: 12, color: NouriColors.muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('remove-custom-field-${f.id}'),
                        icon: const Icon(Icons.close,
                            size: 18, color: NouriColors.muted),
                        onPressed: () async {
                          await dao.removeCustomField(f.id);
                          ref.invalidate(profileCustomFieldsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              const Divider(color: NouriColors.border, height: 1),
              TextButton.icon(
                key: const ValueKey('add-custom-field'),
                onPressed: () async {
                  await _addSheet(context, dao);
                  ref.invalidate(profileCustomFieldsProvider);
                },
                icon: const Icon(Icons.add, size: 18, color: NouriColors.gold),
                label: Text('زوّد حاجة',
                    style: cairo(size: 13, color: NouriColors.gold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addSheet(BuildContext context, ProfileDao dao) async {
    final label = TextEditingController();
    final value = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NouriColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حاجة من عندك',
                style: cairo(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('custom-field-label'),
              controller: label,
              style: cairo(size: 13),
              decoration: _decor('اسمها — «النادي»'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('custom-field-value'),
              controller: value,
              style: cairo(size: 13),
              maxLines: 2,
              minLines: 1,
              decoration: _decor('تفاصيلها — «كل جمعة بعد العصر»'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('save-custom-field'),
              style: FilledButton.styleFrom(
                backgroundColor: NouriColors.gold,
                foregroundColor: NouriColors.background,
              ),
              onPressed: () async {
                final l = label.text.trim();
                final v = value.text.trim();
                // Both or neither. A field with a label and no value tells
                // Claude nothing and takes up a line of the summary.
                if (l.isEmpty || v.isEmpty) {
                  Navigator.of(sheetContext).pop();
                  return;
                }
                await dao.addCustomField(label: l, value: v);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
              child: Text('زوّدها',
                  style: cairo(size: 13.5, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    label.dispose();
    value.dispose();
  }

  static InputDecoration _decor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: cairo(size: 12, color: NouriColors.muted),
        isDense: true,
        filled: true,
        fillColor: NouriColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.gold),
        ),
      );
}
