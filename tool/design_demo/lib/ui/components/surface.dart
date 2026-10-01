import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';

/// Renders a theme-owned [DepthStyle]: fill, shadow stack, fine edge
/// lighting and, for recessed wells, inward shading.
class DepthBox extends StatelessWidget {
  const DepthBox({
    super.key,
    required this.style,
    required this.radius,
    this.padding,
    this.border,
    this.child,
    this.width,
    this.height,
  });

  final DepthStyle style;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final Widget? child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.hover,
      curve: Curves.easeInOut,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: style.shadows,
        border: border,
      ),
      foregroundDecoration: _EdgeLighting(style, radius),
      child: child,
    );
  }
}

/// Theme-selected surface for feature code: choose a role, not a recipe.
class Surface extends StatelessWidget {
  const Surface({super.key, this.depth = SurfaceDepth.panel, this.padding, this.radius, required this.child});

  final SurfaceDepth depth;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r =
        radius ??
        switch (depth) {
          SurfaceDepth.panel || SurfaceDepth.floating => Radii.panel,
          SurfaceDepth.raised => Radii.card,
          _ => Radii.control,
        };
    return DepthBox(
      style: context.depth.of(depth),
      radius: r,
      padding: padding ?? (depth == SurfaceDepth.panel ? const EdgeInsets.all(Space.s24) : null),
      child: child,
    );
  }
}

class _EdgeLighting extends Decoration {
  const _EdgeLighting(this.style, this.radius);

  final DepthStyle style;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _EdgePainter(style, radius);
}

class _EdgePainter extends BoxPainter {
  _EdgePainter(this.style, this.radius);

  final DepthStyle style;
  final double radius;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.height <= 0) return;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final inset = style.insetShade;
    if (inset != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      final top = Rect.fromLTWH(rect.left, rect.top, rect.width, 3);
      canvas.drawRect(
        top,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [inset, inset.withValues(alpha: 0)],
          ).createShader(top),
      );
      canvas.restore();
    }

    final hi = style.edgeHighlight ?? Colors.transparent;
    final lo = style.edgeShade ?? Colors.transparent;
    if (hi.a == 0 && lo.a == 0) return;
    // A 1-unit stroke lit at the top, shaded at the bottom, clear on the sides.
    final edge = (radius + 1) / size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Borders.edge
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hi, hi.withValues(alpha: 0), lo.withValues(alpha: 0), lo],
        stops: [0, edge.clamp(0.0, 0.5), (1 - edge).clamp(0.5, 1.0), 1],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.5), stroke);
  }
}
