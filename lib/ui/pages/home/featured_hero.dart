import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/artwork_frame.dart';
import '../../components/cards/card_parts.dart';
import '../../components/motion.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';

/// Panel-framed backdrop area shared by the hero and its loading/error
/// states, so the page does not jump when content arrives.
class HeroFrame extends StatelessWidget {
  const HeroFrame({super.key, required this.child, this.background});

  final Widget child;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => DepthBox(
        style: context.depth.of(SurfaceDepth.panel),
        radius: Radii.panel,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.panel),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (box.maxWidth * 9 / 21).clamp(400, 600),
            ),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                if (background != null) Positioned.fill(child: background!),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spotlight backdrop with title, synopsis and the primary actions. Text sits
/// over bottom and leading artwork fades rather than trusting the image.
class FeaturedHero extends StatelessWidget {
  const FeaturedHero({
    super.key,
    required this.title,
    required this.facts,
    required this.synopsis,
    required this.artwork,
    this.genres = const [],
    this.badge,
    this.badgeIcon,
    this.pager,
    this.onPlay,
    this.onDetails,
  });

  final String title;

  /// Icon-led facts under the title: rating, kind, year, length.
  final List<MetaItem> facts;
  final List<String> genres;
  final String synopsis;
  final Widget artwork;
  final String? badge;
  final IconData? badgeIcon;

  /// Optional control to switch between featured titles.
  final Widget? pager;
  final VoidCallback? onPlay;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 960;
        final pad = wide ? Space.s48 : Space.s24;
        return HeroFrame(
          background: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              const _Fade(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.25, 1],
              ),
              if (wide)
                const _Fade(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [0.35, 1],
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, Space.s96, pad, pad),
            child: ImageOverlayContext(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.reveal,
                      switchInCurve: Motion.enter,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.bottomLeft,
                        children: [...previous, ?current],
                      ),
                      // Keyed by title so each change replays the reveal.
                      child: _Copy(
                        key: ValueKey(title),
                        hero: this,
                        wide: wide,
                      ),
                    ),
                  ),
                  if (pager != null) ...[
                    const SizedBox(width: Space.s16),
                    pager!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.begin, required this.end, required this.stops});

  final Alignment begin, end;
  final List<double> stops;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: OverlayColors.artworkFade,
        stops: stops,
      ),
    ),
  );
}

class _Copy extends StatelessWidget {
  const _Copy({super.key, required this.hero, required this.wide});

  final FeaturedHero hero;
  final bool wide;

  List<Widget> _parts(SentorrType type) => [
    if (hero.badge != null)
      Padding(
        padding: const EdgeInsets.only(bottom: Space.s12),
        child: OverlayBadge(hero.badge!, icon: hero.badgeIcon),
      ),
    Text(
      hero.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: (wide ? type.display : type.headline).copyWith(
        color: OverlayColors.foreground,
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(top: Space.s12),
      child: MetaLine(
        hero.facts,
        color: OverlayColors.foreground,
        style: type.bodySmall,
      ),
    ),
    if (hero.genres.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [for (final g in hero.genres) _GenreChip(g)],
        ),
      ),
    if (hero.synopsis.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Text(
          hero.synopsis,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          // Supporting prose: a step down from the facts, so title and
          // facts lead.
          style: (wide ? type.body : type.bodySmall).copyWith(
            color: OverlayColors.foregroundMuted,
          ),
        ),
      ),
    Padding(
      padding: const EdgeInsets.only(top: Space.s24),
      child: Wrap(
        spacing: Space.s8,
        runSpacing: Space.s8,
        children: [
          SButton.primary(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            onPressed: hero.onPlay,
          ),
          SButton(
            label: 'More info',
            icon: Icons.info_outline_rounded,
            onPressed: hero.onDetails,
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, part) in _parts(type).indexed)
              Reveal(
                delay: Duration(milliseconds: 70 * i),
                child: part,
              ),
          ],
        ),
      ),
    );
  }
}

/// Outlined genre label over artwork; informational, not a filter.
class _GenreChip extends StatelessWidget {
  const _GenreChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: OverlayColors.inactiveTrack),
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s12,
        vertical: Space.s4,
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: OverlayColors.foregroundSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
