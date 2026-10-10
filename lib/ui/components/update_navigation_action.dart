import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../updates/controller.dart';
import '../../updates/models.dart';
import '../pages/settings/settings_category.dart';
import '../pages/settings/settings_page.dart';
import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'buttons.dart';
import 'navigation.dart';

/// An update's status stays visible outside settings; installation remains
/// an explicit action on the Updates page.
class UpdateNavigationAction extends ConsumerWidget {
  const UpdateNavigationAction({super.key, this.rail = false});
  final bool rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updatesProvider);
    if (!state.isVisible) return const SizedBox.shrink();
    final label = switch (state.phase) {
      UpdatePhase.available => 'Update available',
      UpdatePhase.downloading =>
        state.progress == null
            ? 'Downloading update'
            : 'Update ${(state.progress! * 100).round()}%',
      UpdatePhase.verifying || UpdatePhase.preparing => 'Preparing update',
      UpdatePhase.ready => 'Update ready',
      UpdatePhase.installing => 'Installing update',
      UpdatePhase.failed => 'Update needs attention',
      _ => 'Update',
    };
    final icon = switch (state.phase) {
      UpdatePhase.failed => Icons.error_outline_rounded,
      UpdatePhase.ready => Icons.system_update_alt_rounded,
      UpdatePhase.downloading => Icons.downloading_rounded,
      _ => Icons.system_update_rounded,
    };
    void open() {
      ref.read(settingsRequestProvider.notifier).open(SettingsCategory.updates);
      ref.read(appDestinationProvider.notifier).go(AppDestination.settings);
    }

    if (rail) {
      return Tooltip(
        message: label,
        child: RailNavItem(
          icon: icon,
          label:
              state.phase == UpdatePhase.downloading && state.progress != null
              ? '${(state.progress! * 100).round()}%'
              : state.phase == UpdatePhase.ready
              ? 'Install'
              : 'Update',
          selected: false,
          onTap: open,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s8),
      child: SButton.ghost(label: label, icon: icon, onPressed: open),
    );
  }
}
