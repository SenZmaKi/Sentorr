import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';

/// One progress value keeps a shortcut's fill and ink in sync. Entry fades;
/// exit clears immediately so moving across shortcuts leaves no trails.
class ShortcutHighlight extends StatelessWidget {
  const ShortcutHighlight({super.key, required this.on, required this.builder});

  final bool on;
  final Widget Function(BuildContext, double) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: on ? 1 : 0),
    duration: on && !reduceMotion(context) ? Motion.press : Duration.zero,
    curve: Motion.enter,
    builder: (context, progress, _) => builder(context, progress),
  );
}
