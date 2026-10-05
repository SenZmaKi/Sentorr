import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../watching/notifier.dart';
import '../../../components/buttons.dart';
import '../../../components/confirm_dialog.dart';
import '../settings_group.dart';
import 'watch_progress_row.dart';

class WatchingSection extends ConsumerWidget {
  const WatchingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(inProgressProvider);
    final history = ref.read(watchHistoryProvider.notifier);
    return SettingsGroup(
      title: 'In progress',
      description:
          'Continue watching on Home. Progress saves as you watch, and '
          'finished titles leave on their own',
      keywords: 'continue watching history resume progress',
      trailing: entries.isEmpty
          ? null
          : SButton.ghost(
              label: 'Clear all',
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Clear watch progress?',
                  message:
                      'Everything leaves Continue watching and plays from '
                      'the start next time.',
                  confirmLabel: 'Clear',
                );
                if (ok) await history.clear();
              },
            ),
      children: [
        if (entries.isEmpty)
          const SettingsTile(
            icon: Icons.history_rounded,
            title: 'Nothing in progress',
            subtitle: 'Titles you start appear here',
          ),
        for (final e in entries)
          WatchProgressRow(entry: e, onRemove: () => history.remove(e.key)),
      ],
    );
  }
}
