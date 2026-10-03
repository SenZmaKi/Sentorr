import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'surface.dart';
import 'dialog_scroll.dart';

/// How an adaptive sheet presents in a window of a given size.
enum SheetStyle {
  /// Compact: a sheet rising from the bottom edge, swiped down to close.
  bottom,

  /// Medium and up: the centred floating dialog.
  dialog,

  /// Short windows: as tall as the window allows, so its content scrolls
  /// rather than being squeezed.
  fullHeight;

  static SheetStyle of(LayoutSize screen) => screen.short
      ? fullHeight
      : screen.compact
      ? bottom
      : dialog;
}

/// Shows [builder]'s content in the overlay that suits the window: a bottom
/// sheet on compact, the dialog contract (floating surface, radius 16,
/// padding 24, [maxWidth], scrim) from medium, and a full-height sheet when
/// short. Content is given a bounded height: build it as a
/// `Column(mainAxisSize: min)` with the part that may grow in a
/// `Flexible` scroll view. It can read the presentation from
/// [SheetScope.of], e.g. to make primary actions full width on [bottom].
///
/// Content whose width changes while open (a list that expands) passes
/// `framed: false` and wraps itself in a [SheetFrame] with its own width.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 560,
  bool dismissible = true,
  bool useRootNavigator = true,
  bool framed = true,
}) {
  final style = SheetStyle.of(context.screen);
  Widget content(BuildContext context) => SheetScope(
    style: style,
    child: ScrollConfiguration(
      behavior: const DialogScrollBehavior(),
      child: framed
          ? SheetFrame(maxWidth: maxWidth, child: builder(context))
          : builder(context),
    ),
  );
  if (style == SheetStyle.bottom) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: OverlayColors.scrim,
      builder: content,
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: dismissible,
    barrierColor: OverlayColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: style == SheetStyle.fullHeight
          ? const EdgeInsets.all(Space.s8)
          : const EdgeInsets.all(Space.s24),
      child: content(context),
    ),
  );
}

/// The presentation an adaptive sheet's content sits in.
class SheetScope extends InheritedWidget {
  const SheetScope({super.key, required this.style, required super.child});

  final SheetStyle style;

  /// Null outside an adaptive sheet.
  static SheetStyle? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetScope>()?.style;

  @override
  bool updateShouldNotify(SheetScope old) => old.style != style;
}

/// The floating surface every presentation draws on, in the style of the
/// enclosing [SheetScope]. Bottom sheets float a gutter clear of the screen
/// edges, lift above the keyboard and keep out of the system bars; short
/// sheets take the window's height.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = SheetScope.of(context) ?? SheetStyle.of(context.screen);
    final pad = style == SheetStyle.fullHeight ? Space.s16 : Space.s24;
    final c = context.colors;
    final bottom = style == SheetStyle.bottom;
    final surface = DepthBox(
      style: context.depth.of(SurfaceDepth.floating),
      radius: Radii.panel,
      border: Border.all(color: c.borderStrong),
      padding: EdgeInsets.fromLTRB(
        Space.s24,
        bottom ? Space.s8 : pad,
        Space.s24,
        pad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bottom) const _Handle(),
          Flexible(child: child),
        ],
      ),
    );
    if (!bottom) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SafeArea(child: surface),
      );
    }
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        minimum: const EdgeInsets.all(Space.s8),
        child: ConstrainedBox(
          // Leaves a strip of the page above, so it reads as a sheet.
          constraints: BoxConstraints(
            maxHeight:
                media.size.height -
                media.viewInsets.bottom -
                media.padding.vertical -
                Space.s48,
          ),
          child: surface,
        ),
      ),
    );
  }
}

/// The grab handle atop a bottom sheet.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s16),
    child: Center(
      child: Container(
        width: Space.s32,
        height: Space.s4,
        decoration: BoxDecoration(
          color: context.colors.borderStrong,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
      ),
    ),
  );
}
