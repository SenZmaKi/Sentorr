import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';

/// Paints the seek track's spans and its thumb, which grows with [active].
class SeekTrackPainter extends CustomPainter {
  SeekTrackPainter({
    required this.played,
    required this.downloaded,
    required this.hover,
    required this.active,
    required this.focused,
    required this.colors,
    this.flat = false,
  });

  final PlayerColors colors;

  /// Fills the whole height without rounding, e.g. along a card's edge.
  final bool flat;

  final double played, active;
  final List<({double start, double end})> downloaded;
  final double? hover;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final h = flat
        ? size.height
        : PlayerMetrics.track +
              (PlayerMetrics.trackActive - PlayerMetrics.track) * active;
    final y = size.height / 2;
    final w = size.width;
    void span(double from, double to, Color color) {
      if (to <= from) return;
      canvas.drawRRect(
        RRect.fromLTRBR(
          w * from,
          y - h / 2,
          w * to,
          y + h / 2,
          Radius.circular(flat ? 0 : h / 2),
        ),
        Paint()..color = color,
      );
    }

    span(0, 1, colors.trackUnloaded);
    for (final range in downloaded) {
      span(
        range.start.clamp(0, 1),
        range.end.clamp(0, 1),
        colors.inactiveTrack,
      );
    }
    final hovered = hover;
    if (hovered != null && hovered > played) {
      span(played, hovered, colors.trackHover);
    }
    span(0, played.clamp(0, 1), colors.foreground);

    final r = PlayerMetrics.thumb / 2 * active;
    if (r <= 0) return;
    final center = Offset(w * played.clamp(0, 1), y);
    canvas.drawCircle(
      center.translate(0, 1),
      r + 1,
      Paint()
        ..color = const Color(0x52000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(center, r, Paint()..color = colors.foreground);
    if (focused) {
      canvas.drawCircle(
        center,
        r + Borders.focus * 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Borders.focus
          ..color = colors.focus,
      );
    }
  }

  @override
  bool shouldRepaint(SeekTrackPainter old) =>
      old.played != played ||
      old.downloaded != downloaded ||
      old.hover != hover ||
      old.active != active ||
      old.focused != focused ||
      old.flat != flat ||
      old.colors != colors;
}

/// The time under the pointer, floating above the track, kept inside it.
class SeekTimeBubble extends StatelessWidget {
  const SeekTimeBubble({
    required this.label,
    this.image,
    required this.x,
    required this.width,
  });

  final Uint8List? image;
  final String label;
  final double x, width;

  @override
  Widget build(BuildContext context) {
    final bubbleWidth = (image == null ? 88.0 : PlayerMetrics.previewWidth)
        .clamp(0.0, width);
    final left = (x - bubbleWidth / 2).clamp(0.0, width - bubbleWidth);
    final colors = context.player;
    final radius = BorderRadius.circular(Radii.control);
    return Positioned(
      left: left,
      bottom: Space.s24 + Space.s4,
      width: bubbleWidth,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: context.depth.of(SurfaceDepth.floating).shadows,
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: colors.previewBorder,
                      width: Borders.edge,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: colors.previewBackdrop,
                    borderRadius: radius,
                  ),
                  child: AspectRatio(
                    aspectRatio: PlayerMetrics.previewAspectRatio,
                    child: Image.memory(
                      image!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s8),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.controlSurface,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s12,
                  vertical: Space.s4,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: context.type.timecode.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
