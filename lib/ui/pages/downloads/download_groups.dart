import 'package:flutter/material.dart';

import '../../../downloads/models.dart';
import '../../../following/models.dart';
import '../../../library/models.dart';
import '../../shared/theme/theme.dart';
import 'download_row.dart';

/// A library entry with its download and where it stands.
typedef DownloadView = ({
  LibraryEntry entry,
  DownloadItem? download,
  OfflineState state,
});

/// [views] by season, each in episode order; a movie is its own group.
List<List<DownloadView>> seasonGroups(List<DownloadView> views) {
  final groups = <String, List<DownloadView>>{};
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

/// Movies first, ungrouped; then each series, its episodes in order.
List<(String?, List<DownloadView>)> seriesGroups(List<DownloadView> views) {
  final movies = [
    for (final v in views)
      if (!v.entry.item.isEpisode) v,
  ];
  final series = <String, List<DownloadView>>{};
  for (final v in views) {
    final s = v.entry.item.series;
    if (s != null) series.putIfAbsent(s.title, () => []).add(v);
  }
  int season(DownloadView v) => v.entry.item.season ?? 0;
  int episode(DownloadView v) => v.entry.item.episode ?? 0;
  return [
    if (movies.isNotEmpty) (null, movies),
    for (final MapEntry(:key, :value) in series.entries)
      (
        key,
        value..sort(
          (a, b) => compareEpisodes(
            (season: season(a), episode: episode(a)),
            (season: season(b), episode: episode(b)),
          ),
        ),
      ),
  ];
}

int totalBytes(List<DownloadView> views) =>
    views.fold(0, (sum, v) => sum + (v.download?.totalBytes ?? 0));

/// [views] as rows on the page plane, divided.
class DownloadRows extends StatelessWidget {
  const DownloadRows(this.views, {super.key, required this.compact});

  final List<DownloadView> views;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, v) in views.indexed) ...[
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
}

/// A tab with nothing in it: a glyph, what is missing and how to start.
class DownloadsEmpty extends StatelessWidget {
  const DownloadsEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s96),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.foregroundMuted),
          const SizedBox(height: Space.s16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.type.title.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.type.body.copyWith(color: c.foregroundSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
