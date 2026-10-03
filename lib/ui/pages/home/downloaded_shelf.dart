import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/downloaded.dart';
import '../../../library/models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/episode_card.dart';
import '../../components/title_artwork.dart';
import '../../shared/download_actions.dart';
import '../../shared/title_format.dart';
import 'async_shelf.dart';
import 'home_layout.dart';

/// Finished downloads, shown while offline: everything here plays.
class DownloadedShelf extends ConsumerWidget {
  const DownloadedShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncShelf<LibraryEntry>(
      icon: Icons.download_done_rounded,
      title: 'Downloaded',
      subtitle: 'Plays without a connection',
      count: (n) => '$n ready',
      items: AsyncData(ref.watch(finishedDownloadsProvider)),
      spec: HomeLayout.of(context).episode,
      onRetry: () {},
      cardBuilder: (context, entry, _) {
        final item = entry.item;
        final series = item.series;
        return EpisodeCard(
          series: series?.title ?? kindLabel(item.title),
          code: series == null
              ? yearLabel(item.title)
              : episodeCode(item.season, item.episode),
          name: item.name,
          meta: [
            MetaItem(
              sizeLabel(entry.release.sizeBytes),
              icon: Icons.save_outlined,
              technical: true,
            ),
          ],
          duration: item.runtime == null ? null : stampLabel(item.runtime!),
          plot: item.title.plot,
          artwork: series != null && item.title.poster != null
              ? TitleArtwork(image: item.title.poster)
              : TitleBackdrop(title: series ?? item.title),
          onTap: () => ref.playDownload(entry),
        );
      },
    );
  }
}
