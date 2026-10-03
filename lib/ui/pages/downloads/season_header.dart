import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../library/season_offline.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/progress_track.dart';
import '../../components/title_link.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'transfer_stats.dart';

/// Heads a season's episodes on the Downloads page: its name, how far the
/// season has come as one track, and season-wide pause, resume and cancel
/// as icon buttons, so the rows below keep the space.
class SeasonHeader extends ConsumerWidget {
  const SeasonHeader({
    super.key,
    required this.series,
    required this.season,
    this.showSeries = true,
  });

  final ImdbTitle series;
  final int season;

  /// False under a heading that already names the series.
  final bool showSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final key = (series.id, season);
    final s = ref.watch(seasonOfflineProvider(key));
    final ids = s.downloadIds;
    final moving = s.active || s.busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.s12,
        Space.s16,
        Space.s4,
        Space.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.s2,
              children: [
                TitleLink(
                  title: series,
                  season: season,
                  child: Text(
                    showSeries
                        ? '${series.title} · Season $season'
                        : 'Season $season',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(color: c.foreground),
                  ),
                ),
                TransferStats(_facts(s)),
                if (moving) ...[
                  const SizedBox(height: Space.s4),
                  s.isEmpty
                      ? const _Indeterminate()
                      : ProgressTrack.value(s.progress),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          if (s.active)
            s.allPaused
                ? SIconButton(
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Resume season',
                    onPressed: () => ref.pauseSeason(key, ids, false),
                  )
                : SIconButton(
                    icon: Icons.pause_rounded,
                    tooltip: 'Pause season',
                    onPressed: () => ref.pauseSeason(key, ids, true),
                  ),
          // Failed episodes go with it too, so the season can be cleared.
          if (moving || s.failed > 0)
            SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cancel season',
              onPressed: () => ref.cancelSeason(context, key, ids),
            ),
        ],
      ),
    );
  }

  static List<MetaItem> _facts(SeasonOffline s) => [
    if (s.finding)
      const MetaItem('Finding torrents', icon: Icons.manage_search_rounded)
    else if (s.queueing)
      const MetaItem('Preparing episodes', icon: Icons.hourglass_empty_rounded),
    if (!s.isEmpty)
      MetaItem(
        s.downloaded == s.states.length
            ? '${s.downloaded} episode${s.downloaded == 1 ? '' : 's'}'
            : '${s.downloaded} of ${s.states.length} downloaded',
        technical: true,
      ),
    if (s.totalBytes > 0)
      MetaItem(
        s.active
            ? '${sizeLabel(s.downloadedBytes)} of ${sizeLabel(s.totalBytes)}'
            : sizeLabel(s.totalBytes),
        technical: true,
      ),
    if (s.active && !s.allPaused) ...[
      MetaItem(
        '${sizeLabel(s.bytesPerSecond.round())}/s',
        icon: Icons.arrow_downward_rounded,
        technical: true,
      ),
      MetaItem(
        '${sizeLabel(s.uploadBytesPerSecond.round())}/s',
        icon: Icons.arrow_upward_rounded,
        technical: true,
      ),
      MetaItem(
        '${s.seeds} seeds',
        icon: Icons.cloud_done_outlined,
        technical: true,
      ),
      MetaItem(
        '${s.peers} peers',
        icon: Icons.people_outline_rounded,
        technical: true,
      ),
      MetaItem(
        etaLabel(s.remainingBytes, s.bytesPerSecond) ?? 'Waiting for peers',
        icon: Icons.timer_outlined,
      ),
    ],
    if (s.active && s.allPaused)
      const MetaItem('Paused', icon: Icons.pause_rounded),
    if (s.failed > 0)
      MetaItem('${s.failed} failed', icon: Icons.error_outline_rounded),
  ];
}

/// A track with no amount yet, while a season's torrents are found.
class _Indeterminate extends StatelessWidget {
  const _Indeterminate();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.full),
    child: LinearProgressIndicator(
      minHeight: 4,
      color: context.colors.action,
      backgroundColor: context.colors.surfaceInset,
    ),
  );
}
