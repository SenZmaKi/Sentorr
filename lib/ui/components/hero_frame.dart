import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'surface.dart';

/// Panel-framed backdrop area shared by the hero and its loading/error
/// states, so the page does not jump when content arrives.
class HeroFrame extends StatelessWidget {
  const HeroFrame({
    super.key,
    required this.child,
    this.background,
    this.leading,
    this.banner = false,
  });

  final Widget child;

  /// On a phone, a compact banner with the copy over the artwork rather
  /// than a stacked band and a column of details.
  final bool banner;
  final Widget? background;

  /// Pinned to the frame's top-left corner, e.g. a Back control.
  final Widget? leading;

  /// A cinematic 21:9 band between 400 and 600 tall; in a short window no
  /// more than most of its height, so the page's actions and first shelf
  /// are in view without scrolling.
  static double minHeight(
    BuildContext context,
    BoxConstraints box, {
    bool banner = false,
  }) {
    if (banner && stacked(context, box.maxWidth)) return box.maxWidth * 0.9;
    final band = (box.maxWidth * 9 / 21).clamp(400.0, 600.0);
    final screen = context.screen;
    return screen.short ? math.min(band, screen.size.height * 0.7) : band;
  }

  /// A phone-width frame stacks: landscape artwork keeps its own band at
  /// the top rather than being cropped to a tall sliver behind the copy,
  /// and fades into black where the copy continues.
  static bool stacked(BuildContext context, double width) =>
      width < Breakpoints.medium && !context.screen.short;

  /// The stacked artwork band: 4:3, a mild crop of a 16:9 backdrop.
  static double bandHeight(double width) => width * 3 / 4;

  /// Top padding before hero copy. Stacked, the copy overlaps the band's
  /// faded foot; otherwise an opening, room for a pinned [leading] control
  /// when there is one, and less where height is scarce.
  static double topPad(
    BuildContext context,
    double width, {
    bool leading = true,
  }) {
    if (stacked(context, width)) return bandHeight(width) - Space.s64;
    return context.screen.pickHeight(
      // Clear of the pinned control's target, whatever the input.
      short: leading
          ? Space.s16 + context.density.iconButton + Space.s8
          : Space.s24,
      regular: Space.s96,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final stack = stacked(context, box.maxWidth) && !banner;
        return DepthBox(
          style: context.depth.of(SurfaceDepth.panel),
          radius: Radii.panel,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.panel),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight(context, box, banner: banner),
              ),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  if (background != null && stack) ...[
                    const Positioned.fill(
                      child: ColoredBox(color: OverlayColors.artworkBase),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: bandHeight(box.maxWidth),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          background!,
                          const ArtworkFade(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.45, 1],
                            colors: [
                              Color(0x00000000),
                              OverlayColors.artworkBase,
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (background != null)
                    Positioned.fill(child: background!),
                  child,
                  if (leading != null)
                    Positioned(
                      left: Space.s16,
                      top: Space.s16,
                      child: leading!,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A hero's actions. Wide, they wrap in one run; on a phone ([compact])
/// the first spans the width and the rest share a row beneath it.
class HeroActions extends StatelessWidget {
  const HeroActions({
    super.key,
    required this.compact,
    required this.children,
    this.inline = false,
  });

  final bool compact;

  /// On a phone, all actions share one row instead of the first spanning.
  final bool inline;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!compact || children.isEmpty) {
      return Wrap(spacing: Space.s8, runSpacing: Space.s8, children: children);
    }
    if (inline) {
      return Row(
        spacing: Space.s8,
        children: [for (final a in children) Expanded(child: a)],
      );
    }
    final [first, ...rest] = children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s8,
      children: [
        first,
        if (rest.isNotEmpty)
          Row(
            spacing: Space.s8,
            children: [for (final a in rest) Expanded(child: a)],
          ),
      ],
    );
  }
}

/// Artwork fade toward black along [begin]→[end], for text over artwork.
class ArtworkFade extends StatelessWidget {
  const ArtworkFade({
    super.key,
    required this.begin,
    required this.end,
    required this.stops,
    this.colors = OverlayColors.artworkFade,
  });

  final Alignment begin, end;
  final List<double> stops;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
        stops: stops,
      ),
    ),
  );
}

/// Outlined genre label over artwork; informational, not a filter.
class OverlayGenreChip extends StatelessWidget {
  const OverlayGenreChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: OverlayColors.inactiveTrack),
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s12,
        vertical: Space.s4,
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: OverlayColors.foregroundSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
