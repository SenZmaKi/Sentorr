import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/downloaded.dart';
import '../../shared/download_actions.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/title_format.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_route.dart';
import 'featured_artwork.dart';
import 'featured_hero.dart';
import 'featured_section.dart';
import 'offline_notice.dart';
import 'spotlight.dart';

/// The spotlight while offline: downloaded movies and series instead of
/// trending titles, each playing its file straight from this device.
class OfflineSpotlight extends ConsumerWidget {
  const OfflineSpotlight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(offlineSpotlightProvider);
    final shows = [for (final p in picks) p.show];
    return Spotlight(
      titles: [for (final s in shows) s.title],
      builder: (context, i, pager) {
        final (:show, :next, :count) = picks[i];
        final episode = next.item.series == null
            ? null
            : episodeCode(next.item.season, next.item.episode);
        return FeaturedHero(
          title: show.title,
          facts: spotlightFacts(show, compact: context.screen.compact),
          genres: show.genres.take(3).toList(),
          synopsis: show.plot ?? '',
          badge: count > 1 ? '$count episodes downloaded' : 'Downloaded',
          badgeIcon: Icons.download_done_rounded,
          artwork: FeaturedArtwork(
            titles: shows,
            index: i,
            posterFallback: true,
          ),
          pager: pager,
          playLabel: episode == null ? 'Play' : 'Play $episode',
          onPlay: () => ref.playDownload(next),
          onDetails: () => ref.openTitle(show),
        );
      },
    );
  }
}

/// The top of the home page while offline: the status line, then the
/// downloads spotlight when there is anything downloaded.
class OfflineHead extends ConsumerWidget {
  const OfflineHead({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const OfflineNotice(),
      if (ref.watch(offlineSpotlightProvider).isNotEmpty) ...[
        const SizedBox(height: Space.s16),
        const OfflineSpotlight(),
      ],
    ],
  );
}
