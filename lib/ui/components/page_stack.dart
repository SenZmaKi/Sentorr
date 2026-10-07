import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// Mounts pages on their first visit, then keeps their scroll/input state.
/// Hidden pages take no pointer, focus or semantics, and their tickers pause.
class FadePageStack extends StatefulWidget {
  const FadePageStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadePageStack> createState() => _FadePageStackState();
}

class _FadePageStackState extends State<FadePageStack> {
  final _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(FadePageStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.removeWhere((index) => index >= widget.children.length);
    _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion(context) ? Duration.zero : Motion.reveal;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, page) in widget.children.indexed)
          _Page(
            active: i == widget.index,
            duration: duration,
            child: _visited.contains(i) ? page : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: duration,
            curve: Motion.change,
            child: AnimatedSlide(
              offset: active ? Offset.zero : const Offset(0, 0.012),
              duration: duration,
              curve: Motion.enter,
              // Inside the fades: muting the page must not freeze its own
              // exit, or it would stay painted over the page below it.
              child: TickerMode(enabled: active, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
