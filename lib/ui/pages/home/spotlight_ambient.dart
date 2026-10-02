import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/catalog_rows.dart';
import '../../../imdb/images.dart';
import '../../../imdb/models.dart';
import '../../../imdb/providers.dart';
import '../../components/app_image.dart';
import '../../shared/theme/theme.dart';
import 'spotlight_state.dart';
import 'featured_artwork.dart';

/// The spotlight's artwork, blurred and veiled, washing the top of the page
/// so the hero reads as lit by its own picture. Drifts at a slower rate
/// than [scroll] for depth.
class SpotlightAmbient extends ConsumerWidget {
  const SpotlightAmbient({super.key, required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(featuredTitlesProvider).value ?? const [];
    if (titles.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final index = ref.watch(spotlightIndexProvider).clamp(0, titles.length - 1);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: scroll,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, scroll.hasClients ? -scroll.offset * 0.35 : 0),
            child: child,
          ),
          // Blur spreads past its box; clip so only the faded area shows.
          child: ClipRect(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SpotlightCrossfade(
                    child: _Wash(
                      key: ValueKey(titles[index].id),
                      title: titles[index],
                    ),
                  ),
                  ColoredBox(color: c.ambientVeil),
                  // Pages sit on surface, so fading into it leaves no edge.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.surface.withValues(alpha: 0), c.surface],
                        stops: const [0.3, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wash extends ConsumerWidget {
  const _Wash({super.key, required this.title});

  final ImdbTitle title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImdbImage? image =
        ref
            .watch(titleDetailsProvider(title.id))
            .whenOrNull(data: (d) => d.backdropCandidate) ??
        title.poster;
    if (image == null) return const SizedBox.shrink();
    // A small rendition is enough once blurred, and cheap to filter.
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
      child: AppImage(
        url: imdbImageUrl(image.url, width: 360),
        decodeWidth: 360,
        placeholder: false,
      ),
    );
  }
}
