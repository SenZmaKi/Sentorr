import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../library/budget.dart';
import '../../../../settings/notifier.dart';
import '../../../components/space_meter.dart';
import '../../../shared/theme/theme.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

/// The space every download and copy may take, and what fills it: the
/// viewer's own, which stay, and automatic ones, which make room.
class DownloadBudgetTile extends ConsumerWidget {
  const DownloadBudgetTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(
      settingsProvider.select((s) => s.downloads.budgetBytes),
    );
    final usage = ref.watch(budgetUsageProvider).value;
    return SettingsTile(
      icon: Icons.data_usage_rounded,
      title: 'Space for downloads',
      subtitle:
          'Downloads and copies together. Automatic ones make room by '
          "deleting what you've watched; Sentorr asks before yours go over",
      keywords: 'budget limit disk storage quota size full',
      trailing: LimitField(
        value: (budget / gigabyte).round(),
        presets: const {25: '25 GB', 50: '50 GB', 100: '100 GB', 250: '250 GB'},
        customDefault: 50,
        min: 1,
        unit: 'GB',
        semanticLabel: 'Space for downloads',
        onChanged: (n) => ref
            .read(settingsProvider.notifier)
            .update(
              (s) => s.copyWith(
                downloads: s.downloads.copyWith(budgetBytes: n * gigabyte),
              ),
            ),
      ),
      below: Padding(
        padding: const EdgeInsets.only(top: Space.s8),
        child: SpaceMeter(
          budget: budget,
          segments: [
            SpaceSegment('Yours', usage?.yours ?? 0, SpaceKind.kept),
            SpaceSegment(
              'Automatic',
              usage?.automatic ?? 0,
              SpaceKind.reclaimable,
            ),
          ],
        ),
      ),
    );
  }
}
