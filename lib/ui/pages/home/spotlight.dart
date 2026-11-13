import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/motion.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';
import 'spotlight_gestures.dart';
import 'spotlight_pager.dart';
import 'spotlight_state.dart';

/// Rotates a hero through [titles]. Advances on its own, pausing while
/// hovered or focused, or once touched until the viewer swipes or picks
/// another title, and stays put under reduced motion.
class Spotlight extends ConsumerStatefulWidget {
  const Spotlight({super.key, required this.titles, required this.builder});

  /// Each title's name, for the pager.
  final List<String> titles;

  /// The hero for title [index], with the pager to place in it.
  final Widget Function(BuildContext context, int index, Widget? pager) builder;

  @override
  ConsumerState<Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends ConsumerState<Spotlight>
    with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(
    vsync: this,
    duration: Motion.spotlightHold,
  )..addStatusListener(_onHoldStatus);
  bool _hovered = false;
  bool _focused = false;
  bool _touched = false;

  int get _count => widget.titles.length;
  bool get _paused => _hovered || _focused || _touched || reduceMotion(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setPause();
    });
  }

  @override
  void didUpdateWidget(Spotlight old) {
    super.didUpdateWidget(old);
    if (old.titles.length != _count) _setPause();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _count < 2) return;
    _show((ref.read(spotlightIndexProvider) + 1) % _count);
  }

  void _show(int index) {
    ref.read(spotlightIndexProvider.notifier).show(index);
    _touched = false;
    _hold.value = 0;
    if (!_paused) _hold.forward();
  }

  void _setPause({bool? hovered, bool? focused, bool? touched}) {
    _hovered = hovered ?? _hovered;
    _focused = focused ?? _focused;
    _touched = touched ?? _touched;
    if (_paused) {
      _hold.stop();
    } else if (_count > 1) {
      _hold.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final i = ref.watch(spotlightIndexProvider).clamp(0, _count - 1);
    return MouseRegion(
      onEnter: (_) => _setPause(hovered: true),
      onExit: (_) => _setPause(hovered: false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => _setPause(focused: f),
        child: SpotlightGestures(
          onTouch: () => _setPause(touched: true),
          onSwipe: (step) {
            if (_count > 1) _show((i + step) % _count);
          },
          child: widget.builder(
            context,
            i,
            _count < 2
                ? null
                : RepaintBoundary(
                    child: SpotlightPager(
                      titles: widget.titles,
                      index: i,
                      progress: _hold,
                      onSelect: _show,
                      // A phone swipes between titles, so its dots only
                      // show where it is.
                      indicator:
                          context.screen.compact && context.input.isTouch,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
