import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';
import '../shared/play_route.dart';
import '../shared/theme/theme.dart';
import '../shared/title_route.dart';
import 'cards/title_poster.dart';
import 'cards/title_preview.dart';
import 'title_artwork.dart';
import 'hover_preview.dart';
import 'interactive.dart';

/// A title reference with its own navigation target, even inside a play tile.
/// Uses the same preview as posters; touch can long-press for details.
class TitleLink extends ConsumerWidget {
  const TitleLink({
    super.key,
    required this.title,
    required this.child,
    this.season,
    this.beforeOpen,
    this.preview = true,
    this.episode,
  });

  final ImdbTitle title;
  final Widget child;
  final int? season;

  /// Episode references preview and reveal the episode within its series.
  final ImdbEpisode? episode;

  /// Player headings use a plain link without a floating preview.
  final bool preview;

  /// Player chrome docks playback before revealing the title page.
  final VoidCallback? beforeOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() {
      beforeOpen?.call();
      ref.openTitle(
        title,
        season: episode?.seasonNumber ?? season,
        episodeId: episode?.title.id,
      );
    }

    final link = Semantics(
      link: true,
      child: Interactive(
        button: false,
        borderRadius: Radii.chip,
        semanticLabel: 'More info about ${episode?.title.title ?? title.title}',
        onTap: open,
        builder: (context, state) => DefaultTextStyle.merge(
          style: TextStyle(
            decoration: state.hovered || state.focused
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
          child: child,
        ),
      ),
    );
    if (!preview) return link;
    return HoverPreview(
      width: 360,
      preview: (_) => episode != null
          ? EpisodePreview(
              series: title,
              episode: episode!,
              openLabel: 'View episode',
              artwork: episode!.title.poster != null
                  ? TitleArtwork(image: episode!.title.poster)
                  : TitleBackdrop(title: title),
              onOpen: open,
              onPlay:
                  episode!.releaseDate?.dateTime?.isAfter(DateTime.now()) ==
                      true
                  ? null
                  : () => ref.playEpisode(title, episode!, season: season),
            )
          : PickUpPreview(
              title: title,
              onOpen: open,
              onPlay: () => ref.playOrPickUp(title),
            ),
      child: HoverPreviewTrigger(child: link),
    );
  }
}
