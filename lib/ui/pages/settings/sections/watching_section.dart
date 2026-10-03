import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../watching/models.dart';
import '../../../../watching/notifier.dart';
import '../../../components/buttons.dart';
import '../../../components/confirm_dialog.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/title_format.dart';
import '../../../shared/title_icons.dart';
import '../settings_group.dart';

/// "S1 E3 · Pilot · 32 min left · Today".
String _progressLine(WatchEntry e) => [
  if (e.isEpisode) ...[episodeCode(e.season, e.episode), e.title.title],
  '${durationLabel(e.remaining)} left',
  relativeDay(e.updatedAt),
].join(' · ');

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
          SettingsTile(
            icon: kindIcon(e.series ?? e.title),
            title: (e.series ?? e.title).title,
            subtitle: _progressLine(e),
            below: _ProgressBar(e.progress),
            trailing: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Remove from Continue watching',
              onPressed: () => history.remove(e.key),
            ),
          ),
      ],
    );
  }
}

/// A recessed track with the watched share filled.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.progress);

  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: SizedBox(
          height: 4,
          width: 240,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.surfaceInset)),
              FractionallySizedBox(
                widthFactor: progress,
                child: ColoredBox(color: c.action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
