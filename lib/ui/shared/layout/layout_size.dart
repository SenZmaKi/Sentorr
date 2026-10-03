import 'package:flutter/widgets.dart';

/// Width breakpoints from DESIGN.md "Responsive layout". Widgets compare
/// [WidthClass]es or use [LayoutSize.pick], never these raw values.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 960;
  static const double large = 1440;

  /// Below this height a layout is short: a phone in landscape, or a squat
  /// desktop window. Vertical chrome yields to content.
  static const double short = 480;

  /// Normal content centres at this width; extra width becomes margin.
  static const double contentMax = 1400;

  /// Reading prose caps here.
  static const double readingMax = 720;
}

/// Ordered width classes: compact phones, medium tablets and small windows,
/// expanded desktops and landscape tablets, large monitors.
enum WidthClass {
  compact,
  medium,
  expanded,
  large;

  static WidthClass of(double width) => width >= Breakpoints.large
      ? large
      : width >= Breakpoints.expanded
      ? expanded
      : width >= Breakpoints.medium
      ? medium
      : compact;

  bool operator >=(WidthClass other) => index >= other.index;
  bool operator <(WidthClass other) => index < other.index;
}

/// The size class of a box: the window (`context.screen`) or a widget's
/// own constraints (`ResponsiveBuilder`).
@immutable
class LayoutSize {
  LayoutSize(this.size) : width = WidthClass.of(size.width);

  final Size size;
  final WidthClass width;

  bool get compact => width == WidthClass.compact;
  bool get medium => width == WidthClass.medium;
  bool get expanded => width >= WidthClass.expanded;
  bool get large => width == WidthClass.large;

  /// Height is scarce; vertical chrome and heroes should shrink.
  bool get short => size.height < Breakpoints.short;
  bool get landscape => size.width > size.height;

  /// A phone on its side: short and landscape, whatever its width class.
  bool get phoneLandscape => short && landscape;

  /// The value for this width class, falling back to the nearest smaller
  /// class that has one.
  T pick<T>({required T compact, T? medium, T? expanded, T? large}) =>
      switch (width) {
        WidthClass.large => large ?? expanded ?? medium ?? compact,
        WidthClass.expanded => expanded ?? medium ?? compact,
        WidthClass.medium => medium ?? compact,
        WidthClass.compact => compact,
      };

  /// The value for a short layout, else [regular].
  T pickHeight<T>({required T short, required T regular}) =>
      this.short ? short : regular;

  @override
  bool operator ==(Object other) =>
      other is LayoutSize &&
      other.width == width &&
      other.short == short &&
      other.landscape == landscape;

  @override
  int get hashCode => Object.hash(width, short, landscape);
}
