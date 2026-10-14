import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// What a skeleton stands in front of, which decides its fill.
enum SkeletonTone {
  /// Artwork and blocks on canvas or surface: surfaceControl pulsing
  /// toward surface.
  surface,

  /// Text inside any container, including filled buttons: the ambient
  /// text colour at low opacity, so it reads on every background.
  content,
}

/// A theme-aware loading stand-in. Every skeleton on screen shares one
/// pulse phase, so a loading group breathes together rather than
/// flickering; reduced motion keeps them static.
class Skeleton extends StatefulWidget {
  /// A block filling [width] × [height], or its parent when they are null.
  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.radius = Radii.chip,
    this.tone = SkeletonTone.surface,
  }) : sample = null,
       widthFactor = null,
       style = null;

  /// One line of the ambient text style, as wide as [sample] would render
  /// or [widthFactor] of the available width. The resolved text can then
  /// replace it without moving anything around it.
  const Skeleton.text({
    super.key,
    String this.sample = 'Loading',
    this.widthFactor,
    this.style,
    this.tone = SkeletonTone.content,
  }) : width = null,
       height = null,
       radius = Radii.chip;

  final double? width;
  final double? height;
  final double radius;
  final SkeletonTone tone;
  final String? sample;
  final double? widthFactor;

  /// Merged over the ambient text style, e.g. the role the line stands
  /// in for, so the line box matches the text that replaces it.
  final TextStyle? style;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  // One full breath: in, then out.
  static final _cycle = Motion.artworkPulse * 2;

  late final _pulse = AnimationController(vsync: this, duration: _cycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      // Start from the wall-clock phase so siblings stay in step.
      final now = DateTime.now().microsecondsSinceEpoch;
      _pulse
        ..value = now % _cycle.inMicroseconds / _cycle.inMicroseconds
        ..repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  double get _t {
    final v = _pulse.value;
    return Curves.easeInOut.transform(v < .5 ? v * 2 : 2 - v * 2);
  }

  Color _fill(BuildContext context) {
    final colors = context.colors;
    return switch (widget.tone) {
      SkeletonTone.surface => Color.lerp(
        colors.surfaceControl,
        colors.surface,
        _t * .5,
      )!,
      SkeletonTone.content =>
        (DefaultTextStyle.of(context).style.color ?? colors.foreground)
            .withValues(alpha: .16 + _t * .12),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bar = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: _fill(context),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
    final sample = widget.sample;
    if (sample == null) {
      return Semantics(
        label: 'Loading',
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height ?? double.infinity,
          child: bar,
        ),
      );
    }
    final painter = TextPainter(
      text: TextSpan(
        text: sample,
        style: DefaultTextStyle.of(context).style.merge(widget.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    // The bar spans roughly the x-height to cap-height band of the line,
    // centred in the full line box so swapping in text keeps the baseline.
    final line = SizedBox(
      width: widget.widthFactor == null ? size.width : null,
      height: size.height,
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: size.height * .6,
          child: bar,
        ),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: widget.widthFactor == null
          ? line
          : FractionallySizedBox(widthFactor: widget.widthFactor, child: line),
    );
  }
}
