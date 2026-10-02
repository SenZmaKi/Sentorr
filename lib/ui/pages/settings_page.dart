import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/models.dart';
import '../../settings/notifier.dart';
import '../components/navigation.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';
import 'page_scaffold.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    return PageScaffold(
      maxWidth: 720,
      children: [
        Surface(
          depth: SurfaceDepth.raised,
          padding: const EdgeInsets.all(Space.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: context.type.subtitle.copyWith(color: c.foreground),
              ),
              Text(
                'Follow the system or keep one mode.',
                style: context.type.bodySmall.copyWith(
                  color: c.foregroundSecondary,
                ),
              ),
              const SizedBox(height: Space.s16),
              SegmentedTabs(
                value: settings.themeMode,
                segments: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                onChanged: (mode) => ref
                    .read(settingsProvider.notifier)
                    .save(
                      AppSettings(
                        themeMode: mode,
                        window: settings.window,
                        imageCacheMaxBytes: settings.imageCacheMaxBytes,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
