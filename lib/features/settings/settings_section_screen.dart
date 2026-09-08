import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'settings_screen.dart';
import 'settings_sections.dart';
import 'settings_widgets.dart';

/// One section of الإعدادات, on its own page.
///
/// Pushed from the index. It watches `settingsProvider` itself rather than
/// receiving a snapshot, so a control that writes and invalidates sees its own
/// change immediately — the row updates on the page it was tapped on, not the
/// next time the index is opened.
class SettingsSectionScreen extends ConsumerWidget {
  const SettingsSectionScreen({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);

    return Scaffold(
      backgroundColor: NouriColors.background,
      appBar: AppBar(
        backgroundColor: NouriColors.background,
        elevation: 0,
        title: Text(section.title,
            style: cairo(size: 15.5, weight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: NouriColors.text),
      ),
      body: settings.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NouriColors.gold),
        ),
        error: (e, _) => Center(
          child: Text('مش قادر أفتح الإعدادات دلوقتي.',
              style: cairo(size: 14, color: NouriColors.muted)),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 24),
          children: [
            SettingsGroup(
              // No title: the app bar above already carries it.
              children:
                  settingsSectionChildren(section, context, ref, s, controller),
            ),
          ],
        ),
      ),
    );
  }
}
