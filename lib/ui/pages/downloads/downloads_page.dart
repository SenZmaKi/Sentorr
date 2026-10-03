import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../downloads/manager.dart';
import '../../../downloads/models.dart';
import '../../../following/models.dart';
import '../../../library/models.dart';
import '../../../library/notifier.dart';
import '../../../library/season_download.dart';
import '../../components/buttons.dart';
import '../../components/section_header.dart';
import '../../shared/open_folder.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../page_scaffold.dart';
import 'download_row.dart';
import 'review_section.dart';
import 'season_controls.dart';
import '../../shared/layout/adaptive.dart';

typedef _View = ({
  LibraryEntry entry,
  DownloadItem? download,
  OfflineState state,
});

/// Everything downloaded or on its way: transfers first, then what is on
/// this device, a series' episodes together in order.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  /// Rows stop growing here so progress tracks and actions stay near the
  /// name on wide windows; the rest becomes margin.
  static const _listMax = 1040.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(libraryProvider);
    final downloads = {
      for (final d in ref.watch(downloadsProvider).value ?? <DownloadItem>[])
        d.id: d,
    };
    final planning = ref.watch(planningProvider).length;
    final planningSeasons = ref.watch(seasonDownloadsProvider);
    final views = <_View>[
      for (final e in entries)
        (
          entry: e,
          download: downloads[e.downloadId],
          state: offlineStateOf(e, downloads[e.downloadId]),
        ),
    ];
    final active = [
      for (final v in views)
        if (v.state is! Downloaded) v,
    ];
    final done = [
      for (final v in views)
        if (v.state is Downloaded) v,
    ];
    final empty = views.isEmpty && planning == 0 && planningSeasons.isEmpty;
    return LayoutBuilder(
      builder: (context, box) {
        final compact = LayoutSize(box.biggest).compact;
        Widget rows(List<_View> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, v) in list.indexed) ...[
              if (i > 0) const Divider(),
              DownloadRow(
                entry: v.entry,
                state: v.state,
                download: v.download,
                compact: compact,
              ),
            ],
          ],
        );
        return PageScaffold(
          maxWidth: _listMax,
          children: [
            const ReviewSection(),
            if (empty) const _Empty(),
            if (active.isNotEmpty ||
                planning > 0 ||
                planningSeasons.isNotEmpty) ...[
              SectionHeader(
                icon: Icons.downloading_rounded,
                title: 'Downloading',
                subtitle: planning == 0
                    ? 'Downloads continue while Sentorr is open'
                    : 'Finding torrents for $planning more',
                count: active.isEmpty ? null : '${active.length}',
              ),
              const SizedBox(height: Space.s12),
              for (final key in planningSeasons)
                if (!views.any(
                  (v) =>
                      v.entry.item.series?.id == key.$1 &&
                      v.entry.item.season == key.$2,
                ))
                  SeasonControls(
                    series: ref
                        .read(seasonDownloadsProvider.notifier)
                        .seriesFor(key),
                    season: key.$2,
                    downloads: const [],
                  ),
              for (final group in _seasons(active)) ...[
                if (group.first.entry.item.series != null)
                  SeasonControls(
                    series: group.first.entry.item.series!,
                    season: group.first.entry.item.season!,
                    downloads: _seasonDownloads(group.first.entry, views),
                  ),
                rows(group),
              ],
              const SizedBox(height: Space.s48),
            ],
            if (done.isNotEmpty) ...[
              SectionHeader(
                icon: Icons.download_done_rounded,
                title: 'On this device',
                subtitle:
                    '${sizeLabel(_bytes(done))} · plays without waiting for '
                    'peers',
                count: '${done.length}',
                action: SButton.ghost(
                  label: 'Open folder',
                  icon: Icons.folder_open_rounded,
                  onPressed: () =>
                      openFolder(ref.read(downloadsDirectoryProvider)),
                ),
              ),
              for (final (name, group) in _grouped(done)) ...[
                const SizedBox(height: Space.s16),
                if (name != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s12),
                    child: Text(
                      name,
                      style: context.type.subtitle.copyWith(
                        color: context.colors.foreground,
                      ),
                    ),
                  ),
                for (final season in _seasons(group)) ...[
                  if (season.first.entry.item.series != null)
                    SeasonControls(
                      series: season.first.entry.item.series!,
                      season: season.first.entry.item.season!,
                      downloads: _seasonDownloads(season.first.entry, views),
                    ),
                  rows(season),
                ],
              ],
            ],
          ],
        );
      },
    );
  }

  static List<DownloadItem> _seasonDownloads(
    LibraryEntry entry,
    List<_View> views,
  ) => [
    for (final v in views)
      if (v.entry.item.series?.id == entry.item.series?.id &&
          v.entry.item.season == entry.item.season &&
          v.download != null)
        v.download!,
  ];

  static List<List<_View>> _seasons(List<_View> views) {
    final groups = <String, List<_View>>{};
    for (final v in views) {
      final item = v.entry.item;
      final key = item.series == null
          ? item.id
          : '${item.series!.id}:season:${item.season}';
      groups.putIfAbsent(key, () => []).add(v);
    }
    for (final group in groups.values) {
      group.sort(
        (a, b) =>
            (a.entry.item.episode ?? 0).compareTo(b.entry.item.episode ?? 0),
      );
    }
    return groups.values.toList();
  }

  static int _bytes(List<_View> views) =>
      views.fold(0, (sum, v) => sum + (v.download?.totalBytes ?? 0));

  /// Movies first, ungrouped; then each series, its episodes in order.
  static List<(String?, List<_View>)> _grouped(List<_View> views) {
    final movies = [
      for (final v in views)
        if (!v.entry.item.isEpisode) v,
    ];
    final series = <String, List<_View>>{};
    for (final v in views) {
      final s = v.entry.item.series;
      if (s != null) series.putIfAbsent(s.title, () => []).add(v);
    }
    return [
      if (movies.isNotEmpty) (null, movies),
      for (final MapEntry(:key, :value) in series.entries)
        (
          key,
          value..sort(
            (a, b) => compareEpisodes(
              (
                season: a.entry.item.season ?? 0,
                episode: a.entry.item.episode ?? 0,
              ),
              (
                season: b.entry.item.season ?? 0,
                episode: b.entry.item.episode ?? 0,
              ),
            ),
          ),
        ),
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s96),
      child: Column(
        children: [
          Icon(Icons.download_rounded, size: 40, color: c.foregroundMuted),
          const SizedBox(height: Space.s16),
          Text(
            'Nothing downloaded yet',
            style: context.type.title.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'Download movies and episodes from their pages to watch '
              'without waiting for the torrent. Following a series can '
              'download new episodes as they air.',
              textAlign: TextAlign.center,
              style: context.type.body.copyWith(color: c.foregroundSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
