import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
import '../title_artwork.dart';
import 'card_parts.dart';
import 'preview_card.dart';

/// Hover preview for an IMDb title. Hovering also warms the title page,
/// since both read the same details.
class TitlePreview extends ConsumerWidget {
  const TitlePreview({
    super.key,
    required this.title,
    required this.onOpen,
    this.onPlay,
    this.playLabel = 'Play',
  });

  final ImdbTitle title;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final String playLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = title;
    final details = ref.watch(titleDetailsProvider(t.id)).value;
    return PreviewCard(
      title: t.title,
      artwork: TitleBackdrop(title: t),
      rating: t.rating?.toStringAsFixed(1),
      facts: [
        MetaItem(kindLabel(t), icon: kindIcon(t)),
        if (yearLabel(t) case final year?) MetaItem(year),
        if (lengthLabel(t, details) case final length?) MetaItem(length),
        if (details?.certificate case final rated?) MetaItem(rated),
      ],
      genres: t.genres.take(3).toList(),
      synopsis: t.plot,
      primaryLabel: playLabel,
      onPrimary: onPlay,
      onOpen: onOpen,
    );
  }
}

/// Hover preview for one episode, led by its still.
class EpisodePreview extends StatelessWidget {
  const EpisodePreview({
    super.key,
    required this.series,
    required this.episode,
    required this.artwork,
    required this.onOpen,
    this.onPlay,
    this.openLabel = 'Series',
  });

  final ImdbTitle series;
  final ImdbEpisode episode;
  final Widget artwork;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  /// Null when [onOpen] is the episode itself, e.g. on its series' page.
  final String? openLabel;

  @override
  Widget build(BuildContext context) {
    final e = episode.title;
    final aired = episode.releaseDate?.dateTime;
    return PreviewCard(
      eyebrow: series.title,
      title: e.title,
      badge: episodeCode(episode.seasonNumber, episode.episodeNumber),
      rating: e.rating?.toStringAsFixed(1),
      artwork: artwork,
      facts: [
        if (aired != null)
          MetaItem(relativeDay(aired), icon: Icons.event_outlined),
        if (e.runtimeSeconds case final s?)
          MetaItem(
            stampLabel(Duration(seconds: s)),
            icon: Icons.schedule_rounded,
            technical: true,
          ),
      ],
      synopsis: e.plot,
      primaryLabel: 'Play episode',
      onPrimary: onPlay,
      openLabel: openLabel,
      onOpen: onOpen,
    );
  }
}
