import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// Animates keyed page replacements, including the first mounted page.
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation.drive(CurveTween(curve: Motion.change)),
      child: SlideTransition(
        position: animation
            .drive(CurveTween(curve: Motion.enter))
            .drive(Tween(begin: const Offset(0, 0.012), end: Offset.zero)),
        child: child,
      ),
    ),
    child: child,
  );
}
