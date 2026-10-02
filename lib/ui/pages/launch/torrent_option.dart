import 'package:flutter/material.dart';

import '../../../torrents/resolution_models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/interactive.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// One torrent to choose, aligned by information: filename, quality, size,
/// availability. A row on the dialog plane; selection adds a check.
class TorrentOption extends StatelessWidget {
  const TorrentOption({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
    this.best = false,
  });

  final TorrentCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  /// The candidate ranked first for the viewer's preferences.
  final bool best;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = candidate.release;
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: r.name,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        curve: Motion.change,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s12,
        ),
        decoration: BoxDecoration(
          color: s.pressed
              ? c.statePressed
              : s.hovered
              ? c.stateHover
              : selected
              ? c.selection
              : c.selection.clear,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.s2),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: IconSizes.control,
                color: selected ? c.foreground : c.foregroundMuted,
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s4,
                children: [
                  Tooltip(
                    message: r.name,
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.technical.copyWith(
                        color: c.foreground,
                      ),
                    ),
                  ),
                  MetaLine([
                    if (best) const MetaItem('Best match', icon: Icons.bolt),
                    MetaItem(
                      r.resolution == null
                          ? 'Unknown quality'
                          : '${r.resolution}p',
                      icon: Icons.high_quality_outlined,
                      technical: r.resolution != null,
                    ),
                    MetaItem(
                      sizeLabel(r.sizeBytes),
                      icon: Icons.save_outlined,
                      technical: true,
                    ),
                    MetaItem(
                      '${groupedCount(r.seeders)} seeders',
                      icon: Icons.group_outlined,
                      technical: true,
                    ),
                    if (candidate.requiresFileSelection)
                      const MetaItem(
                        'Whole season',
                        icon: Icons.layers_outlined,
                      ),
                  ], style: context.type.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
