import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import '../shared/title_format.dart';
import 'motion.dart';
import 'surface.dart';

/// What a [SpaceSegment] holds, which decides its tone.
enum SpaceKind {
  /// Stays until the viewer deletes it.
  kept,

  /// Sentorr deletes it on its own to make room.
  reclaimable,

  /// Asking for room it doesn't have yet.
  incoming,
}

class SpaceSegment {
  const SpaceSegment(this.label, this.bytes, this.kind);
  final String label;
  final int bytes;
  final SpaceKind kind;
}

/// Space a budget allows and what fills it: an inset track the segments
/// cross in order, with a legend under it. Past the budget the track
/// stretches and a mark shows where the budget ends, so what doesn't fit
/// reads as overflow.
class SpaceMeter extends StatelessWidget {
  const SpaceMeter({super.key, required this.segments, required this.budget});

  final List<SpaceSegment> segments;
  final int budget;

  static const _height = 6.0;
  static const _mark = 14.0;

  int get _used => segments.fold(0, (sum, s) => sum + s.bytes);

  Color _tone(BuildContext context, SpaceKind kind) => switch (kind) {
    SpaceKind.kept => context.colors.foreground,
    SpaceKind.reclaimable => context.colors.foregroundMuted,
    SpaceKind.incoming => context.colors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final used = _used;
    final over = used - budget;
    final scale = used > budget ? used : budget;
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    final legend = context.type.caption.copyWith(
      color: c.foregroundSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: _describe(),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _mark,
            child: LayoutBuilder(
              builder: (context, box) {
                double x(int bytes) =>
                    scale == 0 ? 0 : box.maxWidth * bytes / scale;
                final spans = <(SpaceSegment, int)>[];
                var at = 0;
                for (final s in segments) {
                  if (s.bytes <= 0) continue;
                  spans.add((s, at));
                  at += s.bytes;
                }
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    DepthBox(
                      style: context.depth.of(SurfaceDepth.inset),
                      radius: Radii.full,
                      height: _height,
                      width: box.maxWidth,
                    ),
                    for (final (i, (s, start)) in spans.indexed)
                      AnimatedPositioned(
                        duration: duration,
                        curve: Motion.change,
                        left: x(start),
                        width: x(s.bytes),
                        top: (_mark - _height) / 2,
                        height: _height,
                        child: _Fill(
                          color: _tone(context, s.kind),
                          first: i == 0,
                          last: i == spans.length - 1,
                        ),
                      ),
                    if (over > 0)
                      Positioned(
                        left: x(budget) - Borders.focus / 2,
                        top: 0,
                        bottom: 0,
                        width: Borders.focus,
                        child: ColoredBox(color: c.foreground),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Space.s8),
          Wrap(
            spacing: Space.s16,
            runSpacing: Space.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Swatch(color: _tone(context, s.kind), kind: s.kind),
                    const SizedBox(width: Space.s4),
                    Text('${s.label} ${sizeLabel(s.bytes)}', style: legend),
                  ],
                ),
              Text(
                over > 0
                    ? '${sizeLabel(over)} over ${sizeLabel(budget)}'
                    : '${sizeLabel(budget - used)} free of ${sizeLabel(budget)}',
                style: legend.copyWith(
                  color: over > 0 ? c.warning : c.foregroundMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _describe() {
    final parts = [
      for (final s in segments) '${s.label} ${sizeLabel(s.bytes)}',
    ];
    final over = _used - budget;
    parts.add(
      over > 0
          ? '${sizeLabel(over)} over the ${sizeLabel(budget)} budget'
          : '${sizeLabel(budget - _used)} free of ${sizeLabel(budget)}',
    );
    return parts.join(', ');
  }
}

/// One segment's stretch of the track, rounded only at the track's ends.
class _Fill extends StatelessWidget {
  const _Fill({required this.color, required this.first, required this.last});
  final Color color;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    const round = Radius.circular(Radii.full);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.horizontal(
          left: first ? round : Radius.zero,
          right: last ? round : Radius.zero,
        ),
      ),
    );
  }
}

/// A legend key whose shape, not just its color, tells kinds apart: solid
/// for kept, hollow for what Sentorr may delete, a bar for what is asking.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.kind});
  final Color color;
  final SpaceKind kind;

  @override
  Widget build(BuildContext context) => Container(
    width: kind == SpaceKind.incoming ? 12 : 8,
    height: 8,
    decoration: BoxDecoration(
      color: kind == SpaceKind.reclaimable ? null : color,
      border: kind == SpaceKind.reclaimable
          ? Border.all(color: color, width: 1.5)
          : null,
      borderRadius: BorderRadius.circular(Radii.full),
    ),
  );
}
