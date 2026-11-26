import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/notifier.dart';
import '../../../smart_downloads/controller.dart';
import '../../../smart_downloads/models.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'download_groups.dart';

/// Smart downloads: how full the reserve is, what it is doing, and each
/// pick with why it was picked.
class SmartTab extends ConsumerWidget {
  const SmartTab({super.key, required this.views, required this.compact});

  final List<DownloadView> views;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider.select((s) => s.smart));
    final reserve = ref.watch(smartReserveProvider);
    final status = ref.watch(smartStatusProvider);
    final c = context.colors;
    final summary = [
      '${durationLabel(reserve.ready)} ready',
      if (reserve.pending > Duration.zero)
        '${durationLabel(reserve.pending)} on its way',
      'Keep ready ${durationLabel(settings.target)}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: context.type.label.copyWith(color: c.foreground),
              ),
              const SizedBox(height: Space.s4),
              Text(
                _describe(settings.enabled ? status : SmartStatus.off),
                style: context.type.bodySmall.copyWith(
                  color: c.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        if (views.isEmpty)
          const DownloadsEmpty(
            icon: Icons.auto_awesome_outlined,
            title: 'No smart downloads yet',
            message:
                'Picks appear here: what you are partway through, the next '
                'episodes of your series and movies like ones you finished.',
          )
        else
          for (final group in seasonGroups(views)) ...[
            const SizedBox(height: Space.s16),
            DownloadRows(group, compact: compact),
          ],
      ],
    );
  }

  static String _describe(SmartStatus status) => switch (status) {
    SmartStatus.off => 'Off. Turn it on in Settings › Downloads.',
    SmartStatus.noHistory => 'Watch something to personalise smart downloads.',
    SmartStatus.filling => 'Picking what to download next.',
    SmartStatus.downloading => 'Downloading picks.',
    SmartStatus.full => 'Your reserve is full. Watched picks are replaced.',
    SmartStatus.waitingForPlayback => 'Waiting until you stop watching.',
    SmartStatus.waitingForDownloads => 'Waiting for your own downloads.',
    SmartStatus.offline => 'Waiting for the internet.',
    SmartStatus.waitingForWifi => 'Waiting for Wi-Fi.',
    SmartStatus.overBudget =>
      'Paused: downloads fill their space. Raise it in Settings › Downloads.',
    SmartStatus.nothingToPick =>
      'Nothing more to pick for now. Watch more for new picks.',
  };
}
