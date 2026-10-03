import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../player/models.dart';
import '../../components/cards/title_preview.dart';
import '../../components/title_artwork.dart';
import '../../shared/title_route.dart';

/// The app's hover preview for a queue item, as media tiles elsewhere show.
/// Its secondary action opens the title page and docks the player, so the
/// page can be read while playback continues.
class ItemPreview extends ConsumerWidget {
  const ItemPreview({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onDock,
  });

  final PlaybackItem item;

  /// Null when the item is the one already playing.
  final VoidCallback? onPlay;
  final VoidCallback onDock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = item.series;
    void open() {
      ref.openTitle(
        series ?? item.title,
        season: item.season,
        episodeId: item.isEpisode ? item.id : null,
      );
      onDock();
    }

    if (series == null) {
      return TitlePreview(title: item.title, onOpen: open, onPlay: onPlay);
    }
    return EpisodePreview(
      series: series,
      episode: ImdbEpisode(
        title: item.title,
        seasonNumber: item.season,
        episodeNumber: item.episode,
      ),
      artwork: item.title.poster != null
          ? TitleArtwork(image: item.title.poster)
          : TitleBackdrop(title: series),
      onPlay: onPlay,
      onOpen: open,
    );
  }
}
