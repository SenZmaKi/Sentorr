import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';

/// The only depth vocabulary feature code may use.
enum SurfaceDepth { base, panel, raised, inset, floating }

/// Resolved appearance for one depth role.
@immutable
class DepthStyle {
  const DepthStyle({
    required this.fill,
    this.shadows = const [],
    this.edgeHighlight,
    this.edgeShade,
    this.insetShade,
  });

  final Color fill;
  final List<BoxShadow> shadows;

  /// 1-unit top edge light.
  final Color? edgeHighlight;

  /// 1-unit bottom edge shade.
  final Color? edgeShade;

  /// Inward top shading for recessed wells.
  final Color? insetShade;

  /// Pressed raised controls keep only the first contact-shadow layer.
  DepthStyle pressed(Color pressedFill) => DepthStyle(
    fill: pressedFill,
    shadows: shadows.take(1).toList(),
    edgeHighlight: edgeHighlight,
    edgeShade: edgeShade,
  );

  /// Hover on a raised control strengthens its edge highlight only.
  DepthStyle hovered() => DepthStyle(
    fill: fill,
    shadows: shadows,
    edgeHighlight: edgeHighlight == null
        ? null
        : Color.lerp(edgeHighlight, const Color(0xFFFFFFFF), 0.12),
    edgeShade: edgeShade,
    insetShade: insetShade,
  );

  static DepthStyle lerp(DepthStyle a, DepthStyle b, double t) => DepthStyle(
    fill: Color.lerp(a.fill, b.fill, t)!,
    shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
    edgeHighlight: Color.lerp(a.edgeHighlight, b.edgeHighlight, t),
    edgeShade: Color.lerp(a.edgeShade, b.edgeShade, t),
    insetShade: Color.lerp(a.insetShade, b.insetShade, t),
  );
}

@immutable
class SentorrDepth extends ThemeExtension<SentorrDepth> {
  const SentorrDepth(this.styles);

  final Map<SurfaceDepth, DepthStyle> styles;

  DepthStyle of(SurfaceDepth depth) => styles[depth]!;

  factory SentorrDepth.resolve(SentorrColors c, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final highlight = Color.fromRGBO(255, 255, 255, dark ? 0.08 : 0.70);
    final shade = Color.fromRGBO(0, 0, 0, dark ? 0.24 : 0.08);
    final panel = dark
        ? [shadowLayer(0, 2, 4, 0, .24), shadowLayer(0, 8, 16, -4, .20)]
        : [shadowLayer(0, 1, 2, 0, .08), shadowLayer(0, 4, 12, -2, .06)];
    final raised = dark
        ? [shadowLayer(0, 1, 2, 0, .32), shadowLayer(0, 4, 8, -2, .24)]
        : [shadowLayer(0, 1, 2, 0, .12), shadowLayer(0, 3, 6, -1, .08)];
    final floating = dark
        ? [shadowLayer(0, 2, 4, 0, .36), shadowLayer(0, 12, 32, -4, .32)]
        : [shadowLayer(0, 2, 4, 0, .10), shadowLayer(0, 12, 32, -4, .14)];
    return SentorrDepth({
      SurfaceDepth.base: DepthStyle(fill: c.canvas),
      SurfaceDepth.panel: DepthStyle(
        fill: c.surface,
        shadows: panel,
        edgeHighlight: highlight,
        edgeShade: shade,
      ),
      SurfaceDepth.raised: DepthStyle(
        fill: c.surfaceControl,
        shadows: raised,
        edgeHighlight: highlight,
        edgeShade: shade,
      ),
      SurfaceDepth.inset: DepthStyle(
        fill: c.surfaceInset,
        // Recessed wells light from below: the highlight sits on the bottom.
        edgeShade: highlight,
        insetShade: Color.fromRGBO(0, 0, 0, dark ? 0.40 : 0.10),
      ),
      SurfaceDepth.floating: DepthStyle(
        fill: c.surfaceRaised,
        shadows: floating,
        edgeHighlight: highlight,
        edgeShade: shade,
      ),
    });
  }

  @override
  SentorrDepth copyWith({Map<SurfaceDepth, DepthStyle>? styles}) =>
      SentorrDepth(styles ?? this.styles);

  @override
  SentorrDepth lerp(SentorrDepth? other, double t) {
    if (other == null) return this;
    return SentorrDepth({
      for (final d in SurfaceDepth.values)
        d: DepthStyle.lerp(of(d), other.of(d), t),
    });
  }
}
