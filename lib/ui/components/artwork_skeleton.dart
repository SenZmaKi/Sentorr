import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// A quiet loading cue for large artwork; missing artwork stays static.
class ArtworkSkeleton extends StatefulWidget {
  const ArtworkSkeleton({super.key});

  @override
  State<ArtworkSkeleton> createState() => _ArtworkSkeletonState();
}

class _ArtworkSkeletonState extends State<ArtworkSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: Motion.artworkPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              colors.surfaceControl,
              colors.surface,
              Curves.easeInOut.transform(_pulse.value) * 0.5,
            ),
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
