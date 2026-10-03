import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/artwork_frame.dart';
import '../../components/cards/card_parts.dart';
import '../../components/motion.dart';
import '../../components/hero_frame.dart';
import '../../shared/theme/theme.dart';
import '../../shared/layout/adaptive.dart';

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
    this.playLabel = 'Play',
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

  /// e.g. "Resume" or "Continue S1 E4" for a title already started.
  final String playLabel;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = LayoutSize(box.biggest);
        final wide = layout.expanded;
        final short = context.screen.short;
        final pad = layout.pick(
          compact: Space.s16,
          medium: Space.s24,
          expanded: Space.s48,
        );
        // On a phone the pager takes its own row under the actions rather
        // than squeezing the copy beside it.
        final pagerBelow = layout.compact;
        final copy = AnimatedSwitcher(
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
            short: short,
          ),
        );
        return HeroFrame(
          background: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              const ArtworkFade(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.25, 1],
              ),
              if (wide)
                const ArtworkFade(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [0.35, 1],
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pad,
              context.screen.pickHeight(short: Space.s24, regular: Space.s96),
              pad,
              pad,
            ),
            child: ImageOverlayContext(
              child: pagerBelow
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copy,
                        if (pager != null) ...[
                          const SizedBox(height: Space.s16),
                          pager!,
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: copy),
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

class _Copy extends StatelessWidget {
  const _Copy({
    super.key,
    required this.hero,
    required this.wide,
    required this.short,
  });

  final FeaturedHero hero;
  final bool wide;

  /// A short window keeps to title, facts, two lines and the actions.
  final bool short;

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
    if (hero.genres.isNotEmpty && !short)
      Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [for (final g in hero.genres) OverlayGenreChip(g)],
        ),
      ),
    if (hero.synopsis.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Text(
          hero.synopsis,
          maxLines: short ? 2 : 3,
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
            label: hero.playLabel,
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
