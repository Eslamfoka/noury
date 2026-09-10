import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/nouri_colors.dart';
import '../shared/nouri_avatar.dart';

/// Not an error state and not an empty state — a calm promise.
///
/// Same navy/gold language as the rest of the app, with Nouri speaking
/// colloquially. It must never read as broken or unfinished.
class FinancePlaceholder extends StatelessWidget {
  const FinancePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NouriAvatar(size: 64),
            const SizedBox(height: 22),
            Text(
              l.nouriComingSoon,
              style: const TextStyle(
                color: NouriColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.nouriFinancePlaceholder,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NouriColors.muted,
                fontSize: 13,
                height: 1.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
