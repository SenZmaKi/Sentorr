import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';

/// Whether the platform asked to remove nonessential animation.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades content up into place once, when first built. [delay] staggers
/// siblings; it runs inside one controller so no timers outlive the widget.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = Space.s12,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + Motion.reveal,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / _controller.duration!.inMicroseconds,
      1,
      curve: Motion.enter,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _t.value) * widget.offset),
        child: child,
      ),
    ),
  );
}

/// Slow push-in on artwork while [active]; restarts each time it becomes
/// active. Finite per activation, and still under reduced motion.
class KenBurns extends StatefulWidget {
  const KenBurns({
    super.key,
    required this.active,
    required this.duration,
    required this.child,
    this.scale = 1.08,
    this.focus = const Alignment(0.2, -0.3),
  });

  final bool active;
  final Duration duration;
  final Widget child;
  final double scale;

  /// The point the zoom moves toward; faces tend to sit upper-centre.
  final Alignment focus;

  @override
  State<KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<KenBurns>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(restart: false);
  }

  @override
  void didUpdateWidget(KenBurns old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync(restart: widget.active);
  }

  void _sync({required bool restart}) {
    if (!widget.active || reduceMotion(context)) return;
    if (restart) {
      _controller.forward(from: 0);
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale:
          1 + (widget.scale - 1) * Curves.easeOut.transform(_controller.value),
      alignment: widget.focus,
      child: child,
    ),
  );
}
