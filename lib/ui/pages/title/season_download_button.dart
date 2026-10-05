import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../library/models.dart';
import '../../../library/notifier.dart';
import '../../../library/season_offline.dart';
import '../../../titles/episodes.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/download_button.dart';
import '../../components/menu.dart';
import '../../shared/download_actions.dart';
import '../downloads/downloads_page.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';

/// Downloads the shown season from the end of the season chips, reading
/// like each episode's [DownloadButton]: a download glyph, a spinning ring
/// while torrents are found, the season's share as a ring while it
/// downloads, then a check. A ghost button with words where there is room,
/// an icon button on compact widths. Once started it opens a menu.
class SeasonDownloadButton extends ConsumerWidget {
  const SeasonDownloadButton({
    super.key,
    required this.series,
    required this.season,
  });

  final ImdbTitle series;
  final int season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (series.id, season);
    final s = ref.watch(seasonOfflineProvider(key));
    final complete = ref.watch(_completeProvider(key));
    final c = context.colors;
    final percent = '${(s.progress * 100).floor()}%';
    void download() => ref.downloadSeason(context, series, season);
    void openDownloads() {
      ref.read(appDestinationProvider.notifier).go(AppDestination.downloads);
      ref
          .read(downloadsTabProvider.notifier)
          .pick(
            s.busy || s.active ? DownloadsTab.ongoing : DownloadsTab.complete,
          );
    }

    final (Widget glyph, String label, String tooltip) = s.busy
        ? (
            const DownloadRing(),
            s.finding ? 'Finding torrents' : 'Preparing',
            s.finding
                ? 'Finding torrents for season $season'
                : 'Preparing season $season',
          )
        : s.active
        ? (
            DownloadRing(
              value: s.progress,
              glyph: s.allPaused
                  ? Icons.pause_rounded
                  : Icons.arrow_downward_rounded,
            ),
            s.allPaused
                ? 'Paused $percent'
                : s.copying == s.transferring
                ? 'Copying $percent'
                : 'Downloading $percent',
            s.allPaused
                ? 'Season $season paused · $percent'
                : s.copying == s.transferring
                ? 'Copying season $season · $percent'
                : 'Downloading season $season · $percent',
          )
        : complete
        ? (
            Icon(
              Icons.download_done_rounded,
              size: IconSizes.control,
              color: c.success,
            ),
            'Downloaded',
            'Season $season downloaded',
          )
        : (
            Icon(
              Icons.download_for_offline_outlined,
              size: IconSizes.control,
              color: c.foreground,
            ),
            s.downloaded > 0 ? 'Download the rest' : 'Download season',
            s.downloaded > 0
                ? 'Download the rest of season $season'
                : 'Download season $season',
          );
    Widget trigger(VoidCallback onTap) => context.screen.compact
        ? SIconButton(
            icon: Icons.download_for_offline_outlined,
            glyph: glyph,
            tooltip: tooltip,
            onPressed: onTap,
          )
        : Tooltip(
            message: tooltip,
            child: SButton(
              variant: ButtonVariant.ghost,
              label: label,
              leading: glyph,
              onPressed: onTap,
            ),
          );
    if (!s.busy && !s.active && !complete) return trigger(download);
    final ids = s.downloadIds;
    return ActionMenu(
      title: 'Season $season',
      actions: [
        if (s.active)
          s.allPaused
              ? MenuAction(
                  'Resume season',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => ref.pauseSeason(key, ids, false),
                )
              : MenuAction(
                  'Pause season',
                  icon: Icons.pause_rounded,
                  onPressed: () => ref.pauseSeason(key, ids, true),
                ),
        if (!s.busy && !complete)
          MenuAction(
            'Download the rest',
            icon: Icons.download_rounded,
            onPressed: download,
          ),
        MenuAction(
          'Show in Downloads',
          icon: Icons.downloading_rounded,
          onPressed: openDownloads,
        ),
        if (s.busy || s.active)
          MenuAction(
            'Cancel season',
            icon: Icons.close_rounded,
            destructive: true,
            onPressed: () => ref.cancelSeason(context, key, ids),
          ),
      ],
      builder: (context, menu) =>
          trigger(() => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// Every aired episode of the season is on this device, as far as the
/// loaded pages tell; unknown while more pages remain.
final _completeProvider = Provider.autoDispose.family<bool, SeasonKey>((
  ref,
  key,
) {
  final episodes = ref.watch(seasonEpisodesProvider(key));
  if (episodes.loading || episodes.hasMore) return false;
  final today = DateTime.now();
  final aired = {
    for (final e in episodes.items)
      if (e.releaseDate?.dateTime?.isAfter(today) == false) e.title.id,
  };
  if (aired.isEmpty) return false;
  final states = {
    for (final id in aired) id: ref.watch(offlineStateProvider(id)),
  };
  return states.values.every((s) => s is Downloaded);
});
