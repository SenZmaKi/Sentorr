import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';

/// Reserves a gutter inside desktop scrollbars across dialog scroll views.
/// The scrollbar stays at the viewport edge; only scrolling content moves in.
class DialogScrollBehavior extends MaterialScrollBehavior {
  const DialogScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final desktop = switch (getPlatform(context)) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (desktop && axisDirectionToAxis(details.direction) == Axis.vertical) {
      child = Padding(
        padding: const EdgeInsetsDirectional.only(end: Space.s24),
        child: child,
      );
    }
    return super.buildScrollbar(context, child, details);
  }
}
