import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../downloads/manager.dart';
import '../../../downloads/models.dart';
import '../../../downloads/queue.dart';
import '../../../imdb/models.dart';
import '../../../library/season_download.dart';
import '../../components/confirm_dialog.dart';
import '../../../shared/errors/error_reports.dart';
import '../../components/buttons.dart';
import '../../shared/theme/theme.dart';

/// One season's controls include finished episodes that are still seeding.
class SeasonControls extends ConsumerWidget {
  const SeasonControls({
    super.key,
    required this.series,
    required this.season,
    required this.downloads,
  });
  final ImdbTitle series;
  final int season;
  final List<DownloadItem> downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = '${series.id}:season:$season';
    final queue = ref.read(downloadQueueProvider);
    final paused =
        queue.batchPaused(batch) ||
        downloads.any((d) => d.status == DownloadStatus.paused);
    final planning = ref.watch(seasonDownloadsProvider).contains((
      series.id,
      season,
    ));
    final canCancel = planning || downloads.any((d) => !d.status.isTerminal);
    final canPause = downloads.any(
      (d) => !d.status.isTerminal && d.status != DownloadStatus.paused,
    );
    Future<void> change(bool pause) async {
      try {
        if (pause) {
          await queue.pauseBatch(
            batch,
            itemIds: downloads.map((d) => d.id).toSet(),
          );
        } else {
          await queue.resumeBatch(
            batch,
            itemIds: downloads.map((d) => d.id).toSet(),
          );
        }
      } catch (error) {
        ErrorReports.report("Couldn't update season downloads", error);
      }
    }

    Future<void> cancel() async {
      if (!await confirm(
        context,
        title: 'Cancel season $season?',
        message:
            'Stops queued downloads and finding remaining episodes. '
            'Files already downloaded are kept.',
        confirmLabel: 'Cancel season',
      )) {
        return;
      }
      try {
        ref.read(seasonDownloadsProvider.notifier).cancel(series.id, season);
        await queue.cancelBatch(
          batch,
          itemIds: downloads.map((d) => d.id).toSet(),
        );
      } catch (error) {
        ErrorReports.report("Couldn't cancel season downloads", error);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s12),
      child: Wrap(
        spacing: Space.s12,
        runSpacing: Space.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${series.title} · Season $season',
            style: context.type.subtitle,
          ),
          if (canPause)
            SButton.ghost(
              label: 'Pause season',
              icon: Icons.pause_rounded,
              onPressed: () => change(true),
            ),
          if (canCancel)
            SButton.ghost(
              label: 'Cancel season',
              icon: Icons.close_rounded,
              onPressed: cancel,
            ),
          if (paused)
            SButton.ghost(
              label: 'Resume season',
              icon: Icons.play_arrow_rounded,
              onPressed: () => change(false),
            ),
        ],
      ),
    );
  }
}
