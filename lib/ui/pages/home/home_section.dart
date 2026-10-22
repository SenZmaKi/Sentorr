import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps the content in view stationary when a preceding home row changes
/// height (for example, when Planned gains its first title).
class HomeSection extends SingleChildRenderObjectWidget {
  const HomeSection({
    super.key,
    required super.child,
    this.preserveFollowing = false,
  });

  final bool preserveFollowing;

  @override
  RenderSliverToBoxAdapter createRenderObject(BuildContext context) =>
      _RenderHomeSection()..preserveFollowing = preserveFollowing;

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSliverToBoxAdapter renderObject,
  ) {
    (renderObject as _RenderHomeSection).preserveFollowing = preserveFollowing;
  }
}

class _RenderHomeSection extends RenderSliverToBoxAdapter {
  bool preserveFollowing = false;
  double? _extent;
  double? _crossAxisExtent;

  @override
  void performLayout() {
    final previous = _extent;
    final sameWidth = _crossAxisExtent == constraints.crossAxisExtent;
    super.performLayout();
    final extent = geometry!.scrollExtent;
    _extent = extent;
    _crossAxisExtent = constraints.crossAxisExtent;

    // A disappearing row may straddle the top edge. Preserve the content
    // below it too, while keeping the page inside its leading boundary.
    // Resizing the window retains the viewport's usual behavior.
    if (sameWidth &&
        previous != null &&
        extent != previous &&
        (constraints.scrollOffset > 0 || preserveFollowing)) {
      final viewport = RenderAbstractViewport.of(this);
      final pixels = viewport is RenderViewport
          ? viewport.offset.pixels
          : constraints.precedingScrollExtent + constraints.scrollOffset;
      final correction = (extent - previous).clamp(-pixels, double.infinity);
      if (correction != 0) {
        geometry = SliverGeometry(scrollOffsetCorrection: correction);
      }
    }
  }
}
