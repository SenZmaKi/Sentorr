import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'status.dart';
import 'surface.dart';

/// Poster first, title and metadata below. No lift or scale on hover.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.title,
    required this.metadata,
    required this.artwork,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String metadata;
  final Widget artwork;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      borderRadius: Radii.card,
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title, $metadata',
      builder: (context, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: DepthBox(
              style: context.depth.of(SurfaceDepth.raised),
              radius: Radii.card,
              border: Border.all(color: s.hovered ? c.borderStrong : Colors.transparent),
              // Artwork clips independently so the frame shadow is not cut off.
              child: ClipRRect(borderRadius: BorderRadius.circular(Radii.card - 1), child: artwork),
            ),
          ),
          const SizedBox(height: Space.s8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.bodySmall.copyWith(fontWeight: FontWeight.w500, color: c.foreground),
          ),
          Text(metadata, style: context.type.caption.copyWith(color: c.foregroundMuted)),
        ],
      ),
    );
  }
}

/// Torrent row: one plane, aligned by information, divider below.
class TorrentRow extends StatelessWidget {
  const TorrentRow({
    super.key,
    required this.filename,
    required this.quality,
    required this.size,
    required this.seeders,
    required this.status,
    required this.selected,
    required this.onTap,
    required this.action,
  });

  final String filename;
  final List<String> quality;
  final String size;
  final int seeders;
  final TransferStatus status;
  final bool selected;
  final VoidCallback onTap;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tech = context.type.technical.copyWith(color: c.foregroundSecondary);
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: filename,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        padding: const EdgeInsets.symmetric(vertical: Space.s12, horizontal: Space.s16),
        decoration: BoxDecoration(
          color: selected
              ? c.selection
              : s.pressed
              ? c.statePressed
              : s.hovered
              ? c.stateHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.hover,
              width: Borders.focus,
              height: 32,
              color: selected ? c.foreground : Colors.transparent,
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: filename,
                    child: Text(
                      filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.technical.copyWith(color: c.foreground),
                    ),
                  ),
                  const SizedBox(height: Space.s4),
                  Wrap(spacing: Space.s4, children: [for (final q in quality) Tag(q)]),
                ],
              ),
            ),
            const SizedBox(width: Space.s16),
            SizedBox(
              width: 84,
              child: Text(size, style: tech, textAlign: TextAlign.right),
            ),
            const SizedBox(width: Space.s16),
            SizedBox(
              width: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_upward, size: 14, color: c.foregroundMuted),
                  const SizedBox(width: Space.s2),
                  Text('$seeders', style: tech),
                ],
              ),
            ),
            const SizedBox(width: Space.s16),
            SizedBox(
              width: 104,
              child: Align(alignment: Alignment.centerLeft, child: StatusBadge(status)),
            ),
            action,
          ],
        ),
      ),
    );
  }
}
