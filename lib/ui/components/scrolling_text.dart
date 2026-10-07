import 'package:flutter/material.dart';

import 'motion.dart';

/// A single line that gently pans overflowing text, pausing at each end.
/// Reduced motion retains an ellipsis and exposes the complete semantic label.
class ScrollingText extends StatelessWidget {
  const ScrollingText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final direction = Directionality.of(context);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      final height = painter.height;
      painter.dispose();
      if (!box.hasBoundedWidth ||
          width <= box.maxWidth ||
          reduceMotion(context)) {
        return Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return Semantics(
        label: text,
        child: ExcludeSemantics(
          child: ClipRect(
            child: SizedBox(
              width: box.maxWidth,
              height: height,
              child: _Pan(
                distance: width - box.maxWidth,
                direction: direction,
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: width,
                  maxWidth: width,
                  child: Text(text, style: style, maxLines: 1, softWrap: false),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Pan extends StatefulWidget {
  const _Pan({
    required this.distance,
    required this.direction,
    required this.child,
  });
  final double distance;
  final TextDirection direction;
  final Widget child;
  @override
  State<_Pan> createState() => _PanState();
}

class _PanState extends State<_Pan> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  void _start() {
    _animation.duration = Duration(
      milliseconds: (widget.distance / 25 * 1000).round() + 2000,
    );
    _animation.repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Pan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distance != widget.distance) {
      _animation.reset();
      _start();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(
        (widget.direction == TextDirection.ltr ? -1 : 1) *
            widget.distance *
            const Interval(
              0.15,
              0.85,
              curve: Curves.easeInOut,
            ).transform(_animation.value),
        0,
      ),
      child: child,
    ),
  );
}
