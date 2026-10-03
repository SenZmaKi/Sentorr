import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'layout_size.dart';

export 'layout_size.dart';

/// How the user mostly points. Touch drops hover-only affordances and grows
/// targets to 48; pointer keeps hover previews, tooltips and 40 targets.
/// Input decides interaction, never layout: layout follows size.
enum InputMode {
  touch,
  pointer;

  static InputMode get platform => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => touch,
    _ => pointer,
  };

  bool get isTouch => this == InputMode.touch;
  bool get canHover => this == InputMode.pointer;

  /// Minimum hit target for icon buttons and rows.
  double get target => isTouch ? ControlHeights.touch : ControlHeights.standard;
}

/// App-wide input mode, provided once above the app. Tests may override it.
class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({super.key, required this.input, required super.child});

  final InputMode input;

  @override
  bool updateShouldNotify(AdaptiveScope old) => old.input != input;
}

extension AdaptiveContext on BuildContext {
  /// The window's size class: for chrome — navigation, overlays, player.
  /// Content composition uses its own constraints via [ResponsiveBuilder].
  LayoutSize get screen => LayoutSize(MediaQuery.sizeOf(this));

  InputMode get input =>
      dependOnInheritedWidgetOfExactType<AdaptiveScope>()?.input ??
      InputMode.platform;
}

/// A [LayoutBuilder] that hands its builder the size class of its own
/// constraints, so content fits where it is placed rather than the window.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, LayoutSize layout) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final screen = MediaQuery.sizeOf(context);
      // Unbounded axes (inside a scroll view) take the window's extent.
      final size = Size(
        box.hasBoundedWidth ? box.maxWidth : screen.width,
        box.hasBoundedHeight ? box.maxHeight : screen.height,
      );
      return builder(context, LayoutSize(size));
    },
  );
}

/// Horizontal page gutters: 16 compact, 24 from medium.
double gutterFor(LayoutSize layout) =>
    layout.pick(compact: Space.s16, medium: Space.s24);
