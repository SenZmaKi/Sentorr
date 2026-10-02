import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  test('a hover fill fading out keeps its hue instead of graying', () {
    final hover = SentorrColors.light.stateHover;
    final midway = Color.lerp(hover, hover.clear, 0.5)!;
    expect(midway.r, hover.r);
    expect(midway.g, hover.g);
    expect(midway.b, hover.b);
    // The bug this guards: transparent black darkens the light fill.
    expect(Color.lerp(hover, Colors.transparent, 0.5)!.r, lessThan(hover.r));
  });
}
