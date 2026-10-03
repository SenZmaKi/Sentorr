import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';

/// Reveals a linked episode after layout, then pulses its outline twice.
/// Reduced motion uses a steady outline for the same brief interval.
class EpisodeDestination extends StatefulWidget {
  const EpisodeDestination({super.key, required this.child});

  final Widget child;

  @override
  State<EpisodeDestination> createState() => _EpisodeDestinationState();
}

class _EpisodeDestinationState extends State<EpisodeDestination>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: Motion.episodeHighlight,
  );
  late final _curve = CurvedAnimation(parent: _pulse, curve: Motion.change);
  late final _strength = TweenSequence<double>([
    for (var i = 0; i < 2; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ],
  ]).animate(_curve);
  Timer? _steady;
  bool _highlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: reduceMotion(context) ? Duration.zero : Motion.artwork,
        curve: Motion.change,
      );
      if (!mounted) return;
      if (reduceMotion(context)) {
        setState(() => _highlight = true);
        _steady = Timer(_pulse.duration!, () {
          if (mounted) setState(() => _highlight = false);
        });
      } else {
        _pulse.forward();
      }
    });
  }

  @override
  void dispose() {
    _steady?.cancel();
    _curve.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    child: widget.child,
    builder: (context, child) => DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          width: Borders.focus,
          color: Color.lerp(
            context.colors.focus.clear,
            context.colors.focus,
            _highlight ? 1 : _strength.value,
          )!,
        ),
      ),
      child: child,
    ),
  );
}
