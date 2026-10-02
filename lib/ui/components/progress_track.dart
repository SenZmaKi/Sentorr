import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'surface.dart';

/// How far along something is, e.g. a download, or how long until it
/// happens on its own, e.g. an exact match playing: an inset track the
/// action fill crosses. [ProgressTrack.value] for a fixed amount.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.progress});

  ProgressTrack.value(double value, {super.key})
    : progress = AlwaysStoppedAnimation(value.clamp(0, 1));

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return DepthBox(
      style: context.depth.of(SurfaceDepth.inset),
      radius: Radii.full,
      height: 4,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.action,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
        ),
      ),
    );
  }
}
