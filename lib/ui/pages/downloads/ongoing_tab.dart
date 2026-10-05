import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../following/auto_downloads.dart';
import '../../../imdb/models.dart';
import '../../../sync/elsewhere.dart';
import '../../../titles/episodes.dart';
import '../../shared/theme/theme.dart';
import 'download_groups.dart';
import 'elsewhere_section.dart';
import 'review_section.dart';
import 'season_header.dart';

/// Downloads on their way: episodes waiting on a choice, seasons whose
/// torrents are being found, then transfers grouped by season.
class OngoingTab extends ConsumerWidget {
  const OngoingTab({
    super.key,
    required this.views,
    required this.planning,
    required this.seasons,
    this.elsewhere = const [],
    required this.compact,
  });

  final List<DownloadView> views;

  /// Items whose torrents are being found, not yet listed.
  final int planning;

  /// Seasons being found or queued, with their series.
  final Map<SeasonKey, ImdbTitle> seasons;

  /// Paired devices' downloads under way that this device lacks.
  final List<DeviceHoldings> elsewhere;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(autoDownloadReviewsProvider).isNotEmpty;
    final local =
        views.isNotEmpty || planning > 0 || seasons.isNotEmpty || reviews;
    if (!local) {
      if (elsewhere.any((d) => d.items.isNotEmpty)) {
        return ElsewhereSection(elsewhere, compact: compact, first: true);
      }
      return const DownloadsEmpty(
        icon: Icons.downloading_rounded,
        title: 'Nothing downloading',
        message:
            'Download movies and episodes from their pages to watch without '
            'waiting for the torrent. Following a series can download new '
            'episodes as they air.',
      );
    }
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReviewSection(),
        if (views.isNotEmpty || planning > 0 || seasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s12),
            child: Text(
              planning == 0
                  ? 'Downloads continue while Sentorr is open'
                  : 'Finding torrents for $planning more',
              style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
            ),
          ),
        for (final MapEntry(key: (_, season), value: series) in seasons.entries)
          if (!views.any(
            (v) =>
                v.entry.item.series?.id == series.id &&
                v.entry.item.season == season,
          ))
            SeasonHeader(series: series, season: season),
        for (final group in seasonGroups(views)) ...[
          if (group.first.entry.item.series case final series?)
            SeasonHeader(series: series, season: group.first.entry.item.season!)
          else
            const SizedBox(height: Space.s8),
          DownloadRows(group, compact: compact),
        ],
        ElsewhereSection(elsewhere, compact: compact),
      ],
    );
  }
}
