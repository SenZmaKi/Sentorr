import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../downloads/manager.dart';
import '../../../downloads/models.dart';
import '../../../following/auto_downloads.dart';
import '../../../imdb/models.dart';
import '../../../library/download_review.dart';
import '../../../library/models.dart';
import '../../../library/notifier.dart';
import '../../../library/season_download.dart';
import '../../../titles/episodes.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/navigation.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/open_folder.dart';
import '../../shared/theme/theme.dart';
import '../page_scaffold.dart';
import 'complete_tab.dart';
import 'download_groups.dart';
import 'ongoing_tab.dart';

enum DownloadsTab { ongoing, complete }

/// The tab the viewer picked; null follows what there is. Opening the
/// Downloads page forgets the pick, so it lands where things are happening.
final downloadsTabProvider =
    NotifierProvider<DownloadsTabNotifier, DownloadsTab?>(
      DownloadsTabNotifier.new,
    );

class DownloadsTabNotifier extends Notifier<DownloadsTab?> {
  @override
  DownloadsTab? build() {
    ref.listen(appDestinationProvider, (previous, next) {
      if (next == AppDestination.downloads &&
          previous != AppDestination.downloads) {
        state = null;
      }
    });
    return null;
  }

  void pick(DownloadsTab tab) => state = tab;
}

/// Everything downloaded or on its way, in two tabs: Ongoing and Complete.
/// It opens on Ongoing while anything is, otherwise on Complete.
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
    final seasons = _planningSeasons(ref);
    final reviews = ref.watch(autoDownloadReviewsProvider).length;
    final copying = ref.watch(copyingProvider);
    final views = <DownloadView>[
      for (final c in copying.values)
        (entry: c.entry, download: null, state: c.state),
      for (final e in entries)
        if (!copying.containsKey(e.id))
          (
            entry: e,
            download: downloads[e.downloadId],
            state: offlineStateOf(e, downloads[e.downloadId]),
          ),
    ];
    final ongoing = [
      for (final v in views)
        if (v.state is! Downloaded) v,
    ];
    final complete = [
      for (final v in views)
        if (v.state is Downloaded) v,
    ];
    final busy =
        ongoing.isNotEmpty || planning > 0 || seasons.isNotEmpty || reviews > 0;
    final tab =
        ref.watch(downloadsTabProvider) ??
        (busy || complete.isEmpty
            ? DownloadsTab.ongoing
            : DownloadsTab.complete);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = LayoutSize(box.biggest).compact;
        return PageScaffold(
          maxWidth: _listMax,
          children: [
            Row(
              children: [
                SegmentedTabs(
                  value: tab,
                  segments: {
                    DownloadsTab.ongoing: _label(
                      'Ongoing',
                      ongoing.length + reviews,
                    ),
                    DownloadsTab.complete: _label('Complete', complete.length),
                  },
                  onChanged: ref.read(downloadsTabProvider.notifier).pick,
                ),
                const Spacer(),
                if (tab == DownloadsTab.complete && complete.isNotEmpty)
                  compact
                      ? SIconButton(
                          icon: Icons.folder_open_rounded,
                          tooltip: 'Open folder',
                          onPressed: () => _openFolder(ref),
                        )
                      : SButton.ghost(
                          label: 'Open folder',
                          icon: Icons.folder_open_rounded,
                          onPressed: () => _openFolder(ref),
                        ),
              ],
            ),
            const SizedBox(height: Space.s24),
            switch (tab) {
              DownloadsTab.ongoing => OngoingTab(
                views: ongoing,
                planning: planning,
                seasons: seasons,
                compact: compact,
              ),
              DownloadsTab.complete => CompleteTab(
                views: complete,
                compact: compact,
              ),
            },
          ],
        );
      },
    );
  }

  static String _label(String name, int count) =>
      count == 0 ? name : '$name  $count';

  static void _openFolder(WidgetRef ref) =>
      openFolder(ref.read(downloadsDirectoryProvider));

  /// Seasons whose torrents are being found or queued, with their series.
  static Map<SeasonKey, ImdbTitle> _planningSeasons(WidgetRef ref) {
    final queueing = ref.watch(seasonDownloadsProvider);
    final seasons = ref.read(seasonDownloadsProvider.notifier);
    return {
      for (final r in ref.watch(downloadReviewsProvider))
        if (r.isSeason) (r.series!.id, r.season!): r.series!,
      for (final key in queueing) key: ?seasons.seriesFor(key),
    };
  }
}
