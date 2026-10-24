import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../skeleton.dart';

/// The same artwork and line slots as EpisodeCard, including its synopsis.
class EpisodeCardSkeleton extends StatelessWidget {
  const EpisodeCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget line(TextStyle style, double fraction) => Skeleton.text(
      widthFactor: fraction,
      style: style,
      tone: SkeletonTone.surface,
    );
    return Semantics(
      label: 'Loading new episodes',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(radius: Radii.card),
          ),
          const SizedBox(height: Space.s12),
          line(context.type.caption, .6),
          const SizedBox(height: Space.s2),
          line(context.type.body, .8),
          const SizedBox(height: Space.s2),
          line(context.type.caption, .5),
          const SizedBox(height: Space.s8),
          line(context.type.bodySmall, .9),
          line(context.type.bodySmall, .7),
        ],
      ),
    );
  }
}
