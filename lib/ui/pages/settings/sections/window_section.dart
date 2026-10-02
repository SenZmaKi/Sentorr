import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/toggle.dart';
import '../settings_group.dart';

class WindowSection extends ConsumerWidget {
  const WindowSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(settingsProvider.select((s) => s.window));
    void edit(WindowPreferences Function(WindowPreferences) change) => ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(window: change(s.window)));
    SettingsTile tile(
      IconData icon,
      String title,
      String subtitle,
      bool value,
      WindowPreferences Function(WindowPreferences, bool) change, {
      String keywords = '',
    }) => SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      trailing: SToggle(
        value: value,
        semanticLabel: title,
        onChanged: (v) => edit((w) => change(w, v)),
      ),
    );
    return SettingsGroup(
      title: 'Window',
      description: 'How Sentorr opens and stays around',
      keywords: 'desktop',
      children: [
        tile(
          Icons.rocket_launch_outlined,
          'Launch at startup',
          'Open Sentorr when you sign in to this computer',
          w.launchAtStartup,
          (w, v) => w.copyWith(launchAtStartup: v),
        ),
        tile(
          Icons.move_to_inbox_outlined,
          'Close to tray',
          'Keep Sentorr running when the window is closed',
          w.closeToTray,
          (w, v) => w.copyWith(closeToTray: v),
        ),
        tile(
          Icons.vertical_align_top_rounded,
          'Always on top',
          'Keep Sentorr above other windows',
          w.alwaysOnTop,
          (w, v) => w.copyWith(alwaysOnTop: v),
        ),
        tile(
          Icons.crop_square_rounded,
          'Open maximized',
          'Fill the desktop when Sentorr starts',
          w.startMaximized,
          (w, v) =>
              w.copyWith(startMaximized: v, startFullScreen: v ? false : null),
        ),
        tile(
          Icons.fullscreen_rounded,
          'Open in full screen',
          'Use the entire screen when Sentorr starts',
          w.startFullScreen,
          (w, v) =>
              w.copyWith(startFullScreen: v, startMaximized: v ? false : null),
        ),
      ],
    );
  }
}
