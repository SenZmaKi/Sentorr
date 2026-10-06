import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../app_image.dart';

/// Loading stand-in matching a tile's frame and two text lines.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.surfaceControl;
    Widget line(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: const ArtworkPlaceholder(),
          ),
          const SizedBox(height: Space.s12),
          line(0.7, 12),
          const SizedBox(height: Space.s8),
          line(0.45, 10),
        ],
      ),
    );
  }
}
