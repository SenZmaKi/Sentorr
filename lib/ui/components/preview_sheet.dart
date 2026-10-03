import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'adaptive_sheet.dart';

/// The touch path to a [HoverPreview]: the same preview card, opened by a
/// long press, presented the way [showAdaptiveSheet] presents for the
/// window (rising from the bottom on compact, centred from medium). The
/// card is already a floating surface, so it is shown bare rather than
/// framed again. Like the hover card, any tap inside it closes it once the
/// tap has done its work.
Future<void> showPreviewSheet(
  BuildContext context, {
  required WidgetBuilder preview,
  double maxWidth = 400,
}) {
  final style = SheetStyle.of(context.screen);
  Widget content(BuildContext sheet) {
    final route = ModalRoute.of(sheet);
    final navigator = Navigator.of(sheet);
    return _CloseOnTap(
      onTap: () {
        if (route != null && route.isActive) navigator.removeRoute(route);
      },
      child: _PreviewFrame(
        bottom: style == SheetStyle.bottom,
        maxWidth: maxWidth,
        child: Builder(builder: preview),
      ),
    );
  }

  if (style == SheetStyle.bottom) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: OverlayColors.scrim,
      builder: content,
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: OverlayColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Space.s16),
      child: content(context),
    ),
  );
}

/// Closes the sheet after a tap (not a drag or scroll) inside it, once the
/// tap's own action has run.
class _CloseOnTap extends StatefulWidget {
  const _CloseOnTap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_CloseOnTap> createState() => _CloseOnTapState();
}

class _CloseOnTapState extends State<_CloseOnTap> {
  Offset? _down;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) => _down = e.position,
    onPointerUp: (e) {
      final down = _down;
      _down = null;
      if (down == null || (e.position - down).distance > kTouchSlop) return;
      scheduleMicrotask(widget.onTap);
    },
    onPointerCancel: (_) => _down = null,
    child: widget.child,
  );
}

/// Keeps the card within the window, clear of system bars and the
/// keyboard, scrolling if it is taller than the room left.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({
    required this.bottom,
    required this.maxWidth,
    required this.child,
  });

  final bool bottom;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(child: child),
    );
    if (!bottom) return SafeArea(child: card);
    final media = MediaQuery.of(context);
    return SafeArea(
      minimum: const EdgeInsets.all(Space.s8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.vertical - Space.s48,
        ),
        child: Center(heightFactor: 1, child: card),
      ),
    );
  }
}
