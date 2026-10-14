import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../skeleton.dart';

/// Loading stand-in for a poster tile: its artwork frame, then title and
/// meta lines on the same line boxes the real card uses.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: aspectRatio,
          child: const Skeleton(radius: Radii.card),
        ),
        const SizedBox(height: Space.s12),
        Skeleton.text(
          widthFactor: .7,
          style: context.type.label,
          tone: SkeletonTone.surface,
        ),
        const SizedBox(height: Space.s2),
        Skeleton.text(
          widthFactor: .45,
          style: context.type.caption,
          tone: SkeletonTone.surface,
        ),
      ],
    ),
  );
}

/// Loading stand-in for a cast member: a round headshot and two centred
/// lines, matching [PersonCard].
class PersonSkeleton extends StatelessWidget {
  const PersonSkeleton({super.key, required this.avatar});

  final double avatar;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    excludeSemantics: true,
    child: Column(
      children: [
        Skeleton(width: avatar, height: avatar, radius: Radii.full),
        const SizedBox(height: Space.s8),
        Skeleton.text(
          widthFactor: .75,
          style: context.type.label,
          tone: SkeletonTone.surface,
        ),
        const SizedBox(height: Space.s2),
        Skeleton.text(
          widthFactor: .5,
          style: context.type.caption,
          tone: SkeletonTone.surface,
        ),
      ],
    ),
  );
}
