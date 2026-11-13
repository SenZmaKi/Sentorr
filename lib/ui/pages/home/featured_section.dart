import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../imdb/models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/hero_frame.dart';
import '../../components/hero_skeleton.dart';
import '../../components/load_error.dart';
import '../../components/pick_up_button.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/play_route.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
import '../../shared/title_route.dart';
import 'featured_artwork.dart';
import 'featured_hero.dart';
import 'spotlight.dart';

/// Spotlight over the top trending titles.
class FeaturedSection extends ConsumerWidget {
  const FeaturedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(featuredTitlesProvider)
      .when(
        data: (titles) => Spotlight(
          titles: [for (final t in titles) t.title],
          builder: (context, i, pager) {
            final t = titles[i];
            return FeaturedHero(
              title: t.title,
              facts: spotlightFacts(t, compact: context.screen.compact),
              genres: t.genres.take(3).toList(),
              synopsis: t.plot ?? '',
              badge: '#${i + 1} trending this week',
              badgeIcon: Icons.trending_up_rounded,
              artwork: FeaturedArtwork(titles: titles, index: i),
              pager: pager,
              onPlay: () => ref.playOrPickUp(t),
              playAction: PickUpButton(
                titleId: t.id,
                onPressed: () => ref.playOrPickUp(t),
              ),
              onDetails: () => ref.openTitle(t),
            );
          },
        ),
        error: (_, _) => HeroFrame(
          child: Padding(
            padding: const EdgeInsets.all(Space.s24),
            child: LoadError(
              message: "Couldn't load featured titles. Check your connection.",
              onRetry: () =>
                  ref.invalidate(catalogRowProvider(CatalogRow.trending)),
            ),
          ),
        ),
        loading: () => const HeroSkeleton(),
      );
}

/// A phone keeps to what fits one line: rating, kind, year and length.
List<MetaItem> spotlightFacts(ImdbTitle t, {required bool compact}) => [
  if (t.rating != null)
    MetaItem(
      t.rating!.toStringAsFixed(1),
      icon: Icons.star_rounded,
      technical: true,
    ),
  if (t.voteCount != null && !compact)
    MetaItem('${compactCount(t.voteCount!)} votes'),
  MetaItem(kindLabel(t), icon: kindIcon(t)),
  if (yearLabel(t) case final year?)
    MetaItem(year, icon: Icons.calendar_today_outlined),
  if (t.runtimeSeconds case final s? when t.canHaveEpisodes != true)
    MetaItem(durationLabel(Duration(seconds: s)), icon: Icons.schedule_rounded),
];
