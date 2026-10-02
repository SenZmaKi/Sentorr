import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'motion.dart';
import 'section_header.dart';
import 'surface.dart';

/// A titled, horizontally scrolling row of tiles. Tiles share one width so
/// the row height can be derived from the tile's aspect ratio and text.
/// Paging arrows float over the row's edges while it is hovered.
class Shelf extends StatefulWidget {
  const Shelf({
    super.key,
    required this.icon,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.tileWidth,
    required this.tileHeight,
    required this.artworkHeight,
    required this.gutter,
    this.subtitle,
    this.count,
    this.message,
    this.reveal = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? count;

  /// Replaces the tiles (e.g. an error) while keeping the row's height.
  final Widget? message;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double tileWidth;

  /// Full tile height including text; text scaling is the caller's to apply.
  final double tileHeight;

  /// Arrows centre on the artwork rather than the whole tile.
  final double artworkHeight;

  /// Horizontal page gutter; tiles scroll under it to the window edge.
  final double gutter;

  /// Stagger the first screenful of tiles in as content arrives.
  final bool reveal;

  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  // Room around tiles for raised shadows and the outset focus ring.
  static const _bleed = Space.s8;
  final _scroll = ScrollController();
  bool _hovered = false;
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdges);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final back = p.pixels > p.minScrollExtent + 1;
    final forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final step = p.viewportDimension - widget.gutter * 2;
    final target = (p.pixels + direction * step).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: reduceMotion(context) ? Duration.zero : Motion.artwork * 1.5,
      curve: Motion.change,
    );
  }

  Widget _tile(BuildContext context, int i) {
    final tile = SizedBox(
      width: widget.tileWidth,
      child: widget.itemBuilder(context, i),
    );
    // Only the first screenful staggers; later tiles are built on scroll.
    if (!widget.reveal || i > 8) return tile;
    return Reveal(
      delay: Duration(milliseconds: 45 * i),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final arrowTop =
        _bleed + widget.artworkHeight / 2 - ControlHeights.touch / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.gutter),
          child: SectionHeader(
            icon: widget.icon,
            title: widget.title,
            subtitle: widget.subtitle,
            count: widget.count,
          ),
        ),
        const SizedBox(height: Space.s16 - _bleed),
        SizedBox(
          height: widget.tileHeight + _bleed * 2,
          child: widget.message != null
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                  child: widget.message,
                )
              : MouseRegion(
                  onEnter: (_) {
                    _updateEdges();
                    setState(() => _hovered = true);
                  },
                  onExit: (_) => setState(() => _hovered = false),
                  child: Stack(
                    children: [
                      ListView.separated(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.gutter,
                          vertical: _bleed,
                        ),
                        itemCount: widget.itemCount,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: Space.s16),
                        itemBuilder: _tile,
                      ),
                      Positioned(
                        left: Space.s8,
                        top: arrowTop,
                        child: _EdgeArrow(
                          visible: _hovered && _canBack,
                          icon: Icons.chevron_left_rounded,
                          label: 'Scroll ${widget.title} back',
                          onTap: () => _page(-1),
                        ),
                      ),
                      Positioned(
                        right: Space.s8,
                        top: arrowTop,
                        child: _EdgeArrow(
                          visible: _hovered && _canForward,
                          icon: Icons.chevron_right_rounded,
                          label: 'Scroll ${widget.title} forward',
                          onTap: () => _page(1),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Floating circular pager; pointer-only, since keyboard focus already
/// scrolls the row to the focused tile.
class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({
    required this.visible,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final floating = context.depth.of(SurfaceDepth.floating);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.hover,
        curve: Motion.change,
        child: ExcludeFocus(
          child: Tooltip(
            message: label,
            child: Interactive(
              onTap: onTap,
              semanticLabel: label,
              borderRadius: Radii.full,
              builder: (context, s) => DepthBox(
                style: s.pressed
                    ? floating.pressed(c.statePressed)
                    : s.hovered
                    ? floating.hovered()
                    : floating,
                radius: Radii.full,
                width: ControlHeights.touch,
                height: ControlHeights.touch,
                border: Border.all(color: c.borderStrong),
                child: Icon(
                  icon,
                  size: IconSizes.navigation,
                  color: c.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
