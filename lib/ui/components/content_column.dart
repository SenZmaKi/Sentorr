import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../shared/layout/adaptive.dart';

/// Where a page's content column sits inside a box of a given width: the
/// responsive gutter, then the [Breakpoints.contentMax] cap centred, so
/// extra width becomes margin rather than stretched content.
///
/// Full-bleed rows (shelves) span the whole box and use [side] as their
/// leading padding, so their headers and first tiles align with the column
/// while tiles scroll out to the window edge.
@immutable
class ContentInsets {
  factory ContentInsets(
    double width, {
    double maxWidth = Breakpoints.contentMax,
  }) {
    final gutter = gutterFor(LayoutSize(Size(width, 0)));
    final side = math.max(gutter, (width - maxWidth) / 2);
    return ContentInsets._(gutter, side, math.max(0, width - side * 2));
  }

  const ContentInsets._(this.gutter, this.side, this.width);

  /// The page gutter for this width class (16 compact, 24 from medium).
  final double gutter;

  /// Distance from each edge of the box to the content column.
  final double side;

  /// The content column's width.
  final double width;

  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: side);
}

/// Places [child] in the page's content column: gutters on narrow boxes,
/// centred at the content cap on wide ones. Use [ContentColumn.bleed] for
/// rows that should reach the box edges with their header on the column.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required Widget this.child,
    this.maxWidth = Breakpoints.contentMax,
  }) : builder = null;

  /// Builds a full-width row, handing it the column's [ContentInsets].
  const ContentColumn.bleed({
    super.key,
    required Widget Function(BuildContext context, ContentInsets insets)
    this.builder,
    this.maxWidth = Breakpoints.contentMax,
  }) : child = null;

  final Widget? child;
  final Widget Function(BuildContext context, ContentInsets insets)? builder;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.hasBoundedWidth
          ? box.maxWidth
          : MediaQuery.sizeOf(context).width;
      final insets = ContentInsets(width, maxWidth: maxWidth);
      final build = builder;
      if (build != null) return build(context, insets);
      return Padding(padding: insets.horizontal, child: child);
    },
  );
}
