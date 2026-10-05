import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';

/// Keeps controls through their fade, then releases their stream listeners.
/// Showing them again reads fresh player state rather than replaying updates.
class BarVisibility extends StatefulWidget {
  const BarVisibility({
    super.key,
    required this.visible,
    required this.duration,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Widget child;

  @override
  State<BarVisibility> createState() => _BarVisibilityState();
}

class _BarVisibilityState extends State<BarVisibility> {
  late bool _retained = widget.visible;

  @override
  void didUpdateWidget(BarVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _retained = true;
    } else if (widget.duration == Duration.zero) {
      _retained = false;
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !widget.visible,
    child: IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: widget.duration,
        curve: Motion.change,
        onEnd: () {
          if (!widget.visible && _retained) {
            setState(() => _retained = false);
          }
        },
        child: _retained ? widget.child : const SizedBox.shrink(),
      ),
    ),
  );
}
