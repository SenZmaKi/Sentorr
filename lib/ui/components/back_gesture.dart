import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/theme.dart';
import 'surface.dart';

/// Turns the inputs desktops send instead of a system Back into one:
/// Escape, the Browser Back key, Alt+Left (Cmd+[ on macOS), the mouse's
/// back button, and a two-finger trackpad swipe right. Each asks the route
/// to pop ([Navigator.maybePop]), exactly as Android's Back does, so the
/// nearest [PopScope] alone decides what Back means.
///
/// The swipe pulls an arrow in from the leading edge and goes back if
/// released once the arrow is fully drawn; a swipe that scrolled a row
/// along the way stays with the row. It only draws while [enabled], i.e.
/// while Back would do something.
///
/// Its focus scope catches focus that a page covered or emptied lets go
/// of, so the keys keep working, and a click takes focus back should
/// something outside have kept it.
class BackGesture extends StatefulWidget {
  const BackGesture({super.key, this.enabled = true, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<BackGesture> createState() => _BackGestureState();
}

class _BackGestureState extends State<BackGesture>
    with SingleTickerProviderStateMixin {
  /// Horizontal travel that arms Back.
  static const _distance = 160.0;

  /// Travel before a swipe commits to an axis.
  static const _lock = 12.0;
  static const _size = 44.0;

  final _focus = FocusScopeNode(debugLabel: 'Back gesture');
  late final _pull = AnimationController(vsync: this, duration: Motion.panel);

  // The current trackpad swipe: its axis once locked, and whether it
  // scrolled something sideways instead.
  bool? _horizontal;
  bool _scrolled = false;
  bool _swiping = false;

  @override
  void initState() {
    super.initState();
    // Autofocus yields to an existing focus, so request it outright.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pull.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (e.buttons & kBackMouseButton != 0) return _back();
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null ||
        (focused != _focus && !focused.ancestors.contains(_focus))) {
      _focus.requestFocus();
    }
  }

  void _back() => Navigator.maybePop(context);

  /// Escape leaves a text field before it goes back, so clearing out of
  /// the search box doesn't also leave Search.
  void _escape() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused?.context?.findAncestorWidgetOfExactType<EditableText>() !=
        null) {
      // Its scope takes focus, so the next Escape still reaches Back.
      return focused!.unfocus();
    }
    _back();
  }

  void _start(PointerPanZoomStartEvent _) {
    _swiping = true;
    _horizontal = null;
    _scrolled = false;
    _pull.stop();
  }

  void _update(PointerPanZoomUpdateEvent e) {
    final pan = e.pan;
    if (_horizontal == null && pan.distance >= _lock) {
      _horizontal = pan.dx.abs() > pan.dy.abs() * 1.5;
    }
    // Fingers moving right draw the arrow in; anything else puts it away.
    final reach = widget.enabled && _horizontal == true && !_scrolled
        ? pan.dx / _distance
        : 0.0;
    _pull.value = reach.clamp(0.0, 1.0);
  }

  void _end(PointerPanZoomEndEvent _) {
    _swiping = false;
    if (_pull.value >= 1) _back();
    _pull.animateBack(0, curve: Motion.change);
  }

  bool _onScroll(ScrollUpdateNotification n) {
    // Into a row's content, not its bounce past the start.
    if (_swiping &&
        n.metrics.axis == Axis.horizontal &&
        (n.scrollDelta ?? 0) != 0 &&
        n.metrics.pixels > n.metrics.minScrollExtent) {
      _scrolled = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
        const SingleActivator(LogicalKeyboardKey.browserBack): _back,
        if (mac)
          const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
              _back
        else
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _back,
      },
      child: FocusScope(
        node: _focus,
        child: Listener(
          // Gaps between the page's content still count.
          behavior: HitTestBehavior.translucent,
          onPointerDown: _down,
          onPointerPanZoomStart: _start,
          onPointerPanZoomUpdate: _update,
          onPointerPanZoomEnd: _end,
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScroll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _Arrow(pull: _pull, size: _size),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides in from the edge as [pull] grows, then fills in once armed so
/// the viewer knows releasing will go back.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.pull, required this.size});

  final Animation<double> pull;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final floating = context.depth.of(SurfaceDepth.floating);
    return AnimatedBuilder(
      animation: pull,
      builder: (context, _) {
        final t = pull.value;
        if (t == 0) return const SizedBox.shrink();
        final armed = t >= 1;
        final eased = Motion.enter.transform(t);
        return Opacity(
          opacity: (t * 2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-size + (size + Space.s16) * eased, 0),
            child: Transform.scale(
              scale: 0.8 + 0.2 * eased,
              child: DepthBox(
                style: armed
                    ? DepthStyle(fill: c.action, shadows: floating.shadows)
                    : floating,
                radius: Radii.full,
                width: size,
                height: size,
                border: Border.all(color: armed ? c.action : c.borderStrong),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: IconSizes.navigation,
                  color: armed ? c.onAction : c.foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
