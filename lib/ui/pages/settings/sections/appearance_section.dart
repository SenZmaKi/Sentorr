import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/notifier.dart';
import '../../../components/navigation.dart';
import '../settings_group.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return SettingsGroup(
      title: 'Theme',
      description: 'How Sentorr looks',
      children: [
        SettingsTile(
          icon: Icons.contrast_rounded,
          title: 'Mode',
          subtitle: 'Follow your system, or always use light or dark',
          keywords: 'colors night',
          trailing: SegmentedTabs(
            value: mode,
            segments: const {
              ThemeMode.system: 'System',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            },
            onChanged: (m) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(themeMode: m)),
          ),
        ),
      ],
    );
  }
}
