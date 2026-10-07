import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/motion.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';

/// Keep the next backdrop decoded for a smooth change, rather than retaining
/// every featured title's full-size artwork and provider subscriptions.
class FeaturedArtwork extends StatelessWidget {
  const FeaturedArtwork({super.key, required this.titles, required this.index});
  final List<ImdbTitle> titles;
  final int index;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (titles.length > 1)
        Opacity(
          opacity: 0,
          child: TitleBackdrop(
            title: titles[(index + 1) % titles.length],
            posterFallback: false,
          ),
        ),
      SpotlightCrossfade(
        child: KenBurns(
          key: ValueKey(titles[index].id),
          active: true,
          duration: Motion.spotlightHold + Motion.spotlightFade,
          child: TitleBackdrop(title: titles[index], posterFallback: false),
        ),
      ),
    ],
  );
}

/// Animated artwork repaints independently of the hero's copy, panel and
/// shelves. Only the current and briefly outgoing images are painted.
class SpotlightCrossfade extends StatelessWidget {
  const SpotlightCrossfade({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : Motion.spotlightFade,
      switchInCurve: Motion.change,
      switchOutCurve: Motion.change,
      // Rapid pager changes need only the latest outgoing artwork. Older
      // transitions otherwise keep additional full-size images mounted.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [if (previous.isNotEmpty) previous.last, ?current],
      ),
      child: child,
    ),
  );
}
