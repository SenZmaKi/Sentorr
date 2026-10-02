import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// Where the preview sits horizontally over its tile.
enum PreviewAlign {
  /// Centred, for posters and stills.
  center,

  /// From the tile's leading edge, for wide rows led by artwork.
  start,
}

/// Floats a richer card over a tile once the pointer deliberately rests on
/// its artwork (the [HoverPreviewTrigger] inside it), covering the tile and
/// spilling past it rather than moving its neighbours.
///
/// Only intent opens it: the pointer must itself move onto the artwork and
/// settle there for [delay]. Content scrolling under a still pointer, a
/// sweep across a row, or a scroll during the wait never does.
/// Mouse only: touch taps go straight to the tile, and keyboard focus keeps
/// the tile's own artwork zoom. One preview is shown at a time.
class HoverPreview extends StatefulWidget {
  const HoverPreview({
    super.key,
    required this.preview,
    required this.child,
    this.align = PreviewAlign.center,
    this.width,
  });

  /// Builds the floating card; null disables the preview.
  final WidgetBuilder? preview;
  final Widget child;
  final PreviewAlign align;

  /// Defaults to half again the tile's width, within 300–400.
  final double? width;

  /// How long the pointer must stay settled before a preview opens.
  static const delay = Duration(milliseconds: 400);

  /// Movement beyond this restarts the wait: the pointer is still travelling.
  static const settleRadius = 6.0;

  @override
  State<HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<HoverPreview>
    with SingleTickerProviderStateMixin {
  static _HoverPreviewState? _shown;

  // Crossing from tile to preview (which covers it) briefly leaves both.
  static const _grace = Duration(milliseconds: 80);

  final _portal = OverlayPortalController();
  late final _t =
      AnimationController(
        vsync: this,
        duration: Motion.reveal,
        reverseDuration: Motion.hover,
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) _remove();
      });
  late final _curve = CurvedAnimation(
    parent: _t,
    curve: Motion.enter,
    reverseCurve: Motion.change,
  );
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _overTile = false;
  bool _overPreview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A page hidden mid-preview freezes its tickers; never leave a card
    // stranded over the page that replaced it.
    if (!TickerMode.valuesOf(context).enabled) _dismiss(animate: false);
  }

  @override
  void didUpdateWidget(HoverPreview old) {
    super.didUpdateWidget(old);
    if (widget.preview == null) _dismiss(animate: false);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_shown == this) _shown = null;
    _curve.dispose();
    _t.dispose();
    super.dispose();
  }

  bool _isMouse(PointerEvent e) => e.kind == PointerDeviceKind.mouse;

  // Counts wheel and trackpad scrolls anywhere. A clock would do, but
  // counting needs none, so it holds under test time too.
  static int _scrolls = 0;
  static bool _watchingScroll = false;

  /// Notes every wheel or trackpad scroll, wherever it lands.
  static void _watchScroll() {
    if (_watchingScroll) return;
    _watchingScroll = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((e) {
      if (e is PointerScrollEvent ||
          e is PointerPanZoomStartEvent ||
          e is PointerPanZoomUpdateEvent) {
        _scrolls++;
      }
    });
  }

  // Where the pointer began settling; null until it moves on the artwork.
  Offset? _settleFrom;

  // [_scrolls] when the wait began; any scroll since cancels it.
  int _scrollsAtSettle = 0;

  /// A containing list (or row) is still moving, e.g. from momentum, a
  /// fling or its paging arrows.
  bool _scrolling() {
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      if (scrollable.position.isScrollingNotifier.value) return true;
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    return false;
  }

  // Entering alone never starts the wait: a list scrolling under a still
  // pointer also "enters" tiles. Only real movement ([_hoverTrigger]) does.
  void _enterTrigger(PointerEnterEvent e) {
    if (!_isMouse(e) || widget.preview == null) return;
    _watchScroll();
    _overTile = true;
    _hideTimer?.cancel();
    if (_portal.isShowing) _t.forward();
  }

  void _hoverTrigger(PointerHoverEvent e) {
    if (!_isMouse(e) || widget.preview == null || _portal.isShowing) return;
    _overTile = true;
    if (_scrolling()) {
      _showTimer?.cancel();
      _settleFrom = null;
      return;
    }
    final from = _settleFrom;
    if (from != null &&
        (e.position - from).distance <= HoverPreview.settleRadius) {
      return;
    }
    _settleFrom = e.position;
    _scrollsAtSettle = _scrolls;
    _showTimer?.cancel();
    _showTimer = Timer(HoverPreview.delay, _show);
  }

  void _exitTrigger(PointerExitEvent e) {
    _overTile = false;
    _settleFrom = null;
    _showTimer?.cancel();
    _scheduleHide();
  }

  void _enterPreview(PointerEnterEvent e) {
    _overPreview = true;
    _hideTimer?.cancel();
    _t.forward();
  }

  void _exitPreview(PointerExitEvent e) {
    _overPreview = false;
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_grace, () {
      if (!_overTile && !_overPreview) _dismiss(animate: true);
    });
  }

  void _show() {
    _settleFrom = null;
    if (!mounted || !_overTile || widget.preview == null) return;
    // A scroll during the wait means the pointer only happens to be here.
    if (_scrolls != _scrollsAtSettle || _scrolling()) return;
    if (_shown != this) _shown?._dismiss(animate: true);
    _shown = this;
    _portal.show();
    if (reduceMotion(context)) {
      _t.value = 1;
    } else {
      _t.forward();
    }
  }

  void _dismiss({required bool animate}) {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (!_portal.isShowing) return;
    if (animate && mounted && !reduceMotion(context)) {
      _t.reverse();
    } else {
      _t.value = 0;
      _remove();
    }
  }

  void _remove() {
    _overPreview = false;
    if (_portal.isShowing) _portal.hide();
    if (_shown == this) _shown = null;
  }

  Widget _overlay(BuildContext context, OverlayChildLayoutInfo info) {
    final anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final width = math.min(
      widget.width ?? (anchor.width * 1.5).clamp(300.0, 400.0),
      info.overlaySize.width - _PreviewLayout.margin * 2,
    );
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _PreviewLayout(anchor, width, widget.align),
        // Pointer-only and supplementary: the tile keeps focus and speech.
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: Listener(
              // A wheel over the card is meant for the row beneath it.
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) _dismiss(animate: false);
              },
              // Every tap in the card navigates. Let the tap finish first.
              onPointerUp: (_) =>
                  scheduleMicrotask(() => _dismiss(animate: false)),
              child: MouseRegion(
                onEnter: _enterPreview,
                onExit: _exitPreview,
                child: AnimatedBuilder(
                  animation: _curve,
                  child: Builder(
                    builder: widget.preview ?? (_) => const SizedBox(),
                  ),
                  builder: (context, child) {
                    final t = _curve.value;
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * Space.s12),
                        child: Transform.scale(
                          scale: 0.95 + 0.05 * t,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: _TriggerScope(state: this, child: widget.child),
    );
  }
}

class _TriggerScope extends InheritedWidget {
  const _TriggerScope({required this.state, required super.child});

  final _HoverPreviewState state;

  @override
  bool updateShouldNotify(_TriggerScope old) => old.state != state;
}

/// Marks the part of a tile that opens its [HoverPreview], normally the
/// artwork, so resting on a title's text never does. Inert outside one.
class HoverPreviewTrigger extends StatelessWidget {
  const HoverPreviewTrigger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.getInheritedWidgetOfExactType<_TriggerScope>()?.state;
    if (state == null) return child;
    return MouseRegion(
      onEnter: state._enterTrigger,
      onHover: state._hoverTrigger,
      onExit: state._exitTrigger,
      child: child,
    );
  }
}

/// Centres the card on its tile (or starts at its edge), then keeps it
/// inside the window.
class _PreviewLayout extends SingleChildLayoutDelegate {
  _PreviewLayout(this.anchor, this.width, this.align);

  static const margin = Space.s8;

  final Rect anchor;
  final double width;
  final PreviewAlign align;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, constraints.maxHeight - margin * 2),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = switch (align) {
      PreviewAlign.center => anchor.center.dx - child.width / 2,
      PreviewAlign.start => anchor.left - margin,
    };
    final y = anchor.center.dy - child.height / 2;
    double fit(double v, double extent, double max) =>
        v.clamp(margin, math.max(margin, max - extent - margin));
    return Offset(
      fit(x, child.width, size.width),
      fit(y, child.height, size.height),
    );
  }

  @override
  bool shouldRelayout(_PreviewLayout old) =>
      old.anchor != anchor || old.width != width || old.align != align;
}
