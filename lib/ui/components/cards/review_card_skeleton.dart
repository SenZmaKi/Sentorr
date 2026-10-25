import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../skeleton.dart';
import '../surface.dart';

/// Reserves the same tile geometry as a review while its request is pending.
class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => DepthBox(
    style: context.depth.of(SurfaceDepth.raised),
    radius: Radii.card,
    padding: const EdgeInsets.all(Space.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton.text(widthFactor: .2, style: context.type.caption),
        const SizedBox(height: Space.s16),
        Skeleton.text(widthFactor: .85, style: context.type.label),
        Skeleton.text(widthFactor: .6, style: context.type.label),
        const SizedBox(height: Space.s8),
        for (final width in [.95, 1.0, .9, .65])
          Skeleton.text(widthFactor: width, style: context.type.bodySmall),
        const Spacer(),
        Skeleton.text(widthFactor: .55, style: context.type.caption),
      ],
    ),
  );
}
