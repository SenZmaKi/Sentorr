import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../../shared/layout/adaptive.dart';
import '../skeleton.dart';

/// Loading rows matching [EpisodeRow]'s still, padding and text lines,
/// so episodes land without the list jumping.
class EpisodeListSkeleton extends StatelessWidget {
  const EpisodeListSkeleton({
    super.key,
    this.count = 4,
    this.compact = false,
    this.dense = false,
    this.divided = false,
  });

  final int count;

  /// As [EpisodeRow.compact] and [EpisodeRow.dense].
  final bool compact, dense;

  /// Dividers between rows, where the loaded list has them.
  final bool divided;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = this.compact || LayoutSize(box.biggest).compact;
      final columns = compact
          ? 1
          : ((box.maxWidth + Space.s16) / (480 + Space.s16)).floor().clamp(
              1,
              2,
            );
      final type = context.type;
      Widget line(double widthFactor, TextStyle style) => Skeleton.text(
        widthFactor: widthFactor,
        style: style,
        tone: SkeletonTone.surface,
      );
      final row = Padding(
        padding: EdgeInsets.all(dense ? Space.s8 : Space.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: dense
                  ? 96
                  : compact
                  ? 128
                  : 176,
              child: const AspectRatio(
                aspectRatio: 16 / 9,
                child: Skeleton(radius: Radii.card),
              ),
            ),
            SizedBox(width: dense ? Space.s12 : Space.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(.55, type.body),
                  const SizedBox(height: Space.s2),
                  line(.35, type.caption),
                  if (!dense) ...[
                    const SizedBox(height: Space.s8),
                    line(.9, type.bodySmall),
                    line(.6, type.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
      return Semantics(
        label: 'Loading episodes',
        excludeSemantics: true,
        child: Column(
          children: [
            for (var i = 0; i < count; i += columns) ...[
              if (divided && i > 0) const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s16,
                children: [
                  for (var column = 0; column < columns; column++)
                    Expanded(child: row),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
