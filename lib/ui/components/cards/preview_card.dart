import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../artwork_frame.dart';
import '../buttons.dart';
import '../interactive.dart';
import '../surface.dart';
import 'card_parts.dart';

/// The floating card a [HoverPreview] shows: landscape artwork fading into
/// the card, then title, actions, facts and synopsis. Tapping anywhere
/// outside the actions opens [onOpen], like the tile it covers.
class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.title,
    required this.artwork,
    required this.facts,
    required this.onOpen,
    this.eyebrow,
    this.badge,
    this.rating,
    this.genres = const [],
    this.synopsis,
    this.primaryLabel = 'Play',
    this.primaryIcon = Icons.play_arrow_rounded,
    this.onPrimary,
    this.openLabel = 'More info',
  });

  final String title;
  final Widget artwork;
  final List<MetaItem> facts;
  final VoidCallback onOpen;

  /// Names a parent, e.g. an episode's series.
  final String? eyebrow;

  /// Top-left stamp on the artwork, e.g. an episode code.
  final String? badge;

  /// Shown as a star chip on the artwork.
  final String? rating;
  final List<String> genres;
  final String? synopsis;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;

  /// The secondary action's label; null leaves only the primary action.
  final String? openLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final floating = context.depth.of(SurfaceDepth.floating);
    return Interactive(
      onTap: onOpen,
      button: false,
      borderRadius: Radii.card,
      builder: (context, _) => DepthBox(
        style: floating,
        radius: Radii.card,
        border: Border.all(color: c.borderStrong),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card - 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    artwork,
                    // Melts the artwork into the card instead of a hard edge.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [floating.fill.clear, floating.fill],
                          stops: const [0.6, 1],
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        left: Space.s12,
                        top: Space.s12,
                        child: OverlayBadge(badge!, technical: true),
                      ),
                    if (rating != null)
                      Positioned(
                        right: Space.s12,
                        top: Space.s12,
                        child: OverlayBadge(
                          rating!,
                          icon: Icons.star_rounded,
                          technical: true,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s16,
                  0,
                  Space.s16,
                  Space.s16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      CardEyebrow(eyebrow!),
                      const SizedBox(height: Space.s2),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.subtitle.copyWith(color: c.foreground),
                    ),
                    const SizedBox(height: Space.s4),
                    MetaLine(facts),
                    const SizedBox(height: Space.s12),
                    Wrap(
                      spacing: Space.s8,
                      runSpacing: Space.s8,
                      children: [
                        SButton.primary(
                          label: primaryLabel,
                          icon: primaryIcon,
                          onPressed: onPrimary,
                        ),
                        if (openLabel != null)
                          SButton(
                            label: openLabel!,
                            icon: Icons.info_outline_rounded,
                            onPressed: onOpen,
                          ),
                      ],
                    ),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: Space.s12),
                      Text(
                        genres.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption.copyWith(
                          color: c.foregroundSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (synopsis case final text? when text.isNotEmpty) ...[
                      const SizedBox(height: Space.s8),
                      Text(
                        text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodySmall.copyWith(
                          color: c.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
