import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'surface.dart';

/// How long until something happens on its own, e.g. an exact match
/// playing: an inset track the action fill crosses.
class CountdownTrack extends StatelessWidget {
  const CountdownTrack({super.key, required this.progress});

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
