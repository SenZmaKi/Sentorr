import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../interactive.dart';
import '../surface.dart';
import 'card_parts.dart';

/// A viewer review clipped to a fixed tile: score, headline, an excerpt,
/// its author, and how many readers liked or disliked it. [onTap] opens the
/// full text.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.headline,
    required this.excerpt,
    this.score,
    this.byline,
    this.likes,
    this.dislikes,
    this.spoiler = false,
    this.onTap,
  });

  final String headline;
  final String excerpt;

  /// The reviewer's 1–10 rating.
  final int? score;

  /// Author and date, e.g. "ana_k · Mar 4, 2024".
  final String? byline;

  /// Readers who found it helpful, and who did not.
  final int? likes;
  final int? dislikes;

  /// Flags a review that reveals the plot.
  final bool spoiler;
  final VoidCallback? onTap;

  static const excerptLines = 4;

  static double height(CardLines l) =>
      Space.s16 * 2 +
      l.caption +
      Space.s4 +
      Space.s12 +
      l.small * 2 +
      Space.s8 +
      l.small * excerptLines +
      Space.s12 +
      l.caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final raised = context.depth.of(SurfaceDepth.raised);
    return Interactive(
      onTap: onTap,
      borderRadius: Radii.card,
      semanticLabel: [
        if (spoiler) 'Contains spoilers',
        if (score != null) 'Rated $score out of 10',
        headline,
        ?byline,
        if (likes != null) '$likes likes',
        if (dislikes != null) '$dislikes dislikes',
      ].join(', '),
      builder: (context, s) => DepthBox(
        style: s.pressed
            ? raised.pressed(c.statePressed)
            : s.hovered
            ? raised.hovered()
            : raised,
        radius: Radii.card,
        border: Border.all(
          color: s.hovered ? c.borderStrong : c.borderStrong.clear,
        ),
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: CardLines(MediaQuery.textScalerOf(context)).caption,
              child: Row(
                children: [
                  if (score != null)
                    MetaLine([
                      MetaItem(
                        '$score/10',
                        icon: Icons.star_rounded,
                        technical: true,
                      ),
                    ], color: c.foregroundSecondary),
                  const Spacer(),
                  if (spoiler) const _SpoilerBadge(),
                ],
              ),
            ),
            const SizedBox(height: Space.s4 + Space.s12),
            Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.label.copyWith(
                color: c.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Space.s8),
            Expanded(
              child: Text(
                excerpt,
                maxLines: excerptLines,
                overflow: TextOverflow.ellipsis,
                style: type.bodySmall.copyWith(color: c.foregroundMuted),
              ),
            ),
            const SizedBox(height: Space.s12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    byline ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: c.foregroundSecondary),
                  ),
                ),
                MetaLine([
                  if (likes != null)
                    MetaItem(
                      compactCount(likes!),
                      icon: Icons.thumb_up_outlined,
                      technical: true,
                    ),
                  if (dislikes != null)
                    MetaItem(
                      compactCount(dislikes!),
                      icon: Icons.thumb_down_outlined,
                      technical: true,
                    ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Warns before the excerpt that the review reveals the plot.
class _SpoilerBadge extends StatelessWidget {
  const _SpoilerBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s8),
        child: MetaLine([
          const MetaItem('Spoilers', icon: Icons.visibility_outlined),
        ], color: c.warning),
      ),
    );
  }
}
