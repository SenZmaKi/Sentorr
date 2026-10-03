import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../shared/theme/theme.dart';
import 'hover_preview.dart';

/// Centres the card on its tile (or starts at its edge), then keeps it
/// inside the window.
class PreviewLayout extends SingleChildLayoutDelegate {
  PreviewLayout(this.anchor, this.width, this.align);

  static const margin = Space.s8;

  final Rect anchor;
  final double width;
  final PreviewAlign align;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, constraints.maxHeight - margin * 2),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = switch (align) {
      PreviewAlign.center => anchor.center.dx - childSize.width / 2,
      PreviewAlign.start => anchor.left - margin,
    };
    final y = anchor.center.dy - childSize.height / 2;
    double fit(double v, double extent, double max) =>
        v.clamp(margin, math.max(margin, max - extent - margin));
    return Offset(
      fit(x, childSize.width, size.width),
      fit(y, childSize.height, size.height),
    );
  }

  @override
  bool shouldRelayout(PreviewLayout old) =>
      old.anchor != anchor || old.width != width || old.align != align;
}
