import 'package:flutter/material.dart';

import '../../../library/review_models.dart';
import '../../../torrents/match.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/interactive.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// One item of a download review: its number, where its torrent stands
/// and which one it downloads from. A row on the dialog plane; tapping it
/// opens the item's torrents. A miss offers Skip, a skipped item Undo.
class ReviewRow extends StatelessWidget {
  const ReviewRow({
    super.key,
    required this.entry,
    required this.inSeason,
    required this.onOpen,
    required this.onSkip,
  });

  final ReviewEntry entry;

  /// Rows of one season lead with the episode number, not the series.
  final bool inSeason;
  final VoidCallback onOpen;
  final ValueChanged<bool> onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final e = entry;
    final look = _StatusLook.of(context, e);
    final skipped = e.status == ReviewStatus.skipped;
    final r = e.torrent?.release;
    final name = inSeason ? e.item.name : itemLabel(e.item);
    return Interactive(
      onTap: onOpen,
      borderRadius: Radii.control,
      semanticLabel: '$name, ${look.label}${r == null ? '' : ', ${r.name}'}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        curve: Motion.change,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s12,
          vertical: Space.s12,
        ),
        decoration: BoxDecoration(
          color: s.pressed
              ? c.statePressed
              : s.hovered
              ? c.stateHover
              : c.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inSeason) ...[
              _Number(e.item.episode, muted: skipped),
              const SizedBox(width: Space.s12),
            ],
            Expanded(
              child: Opacity(
                opacity: skipped ? .6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.s2,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(color: c.foreground),
                    ),
                    _Status(look),
                    if (r != null && !skipped)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.s2),
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.technical.copyWith(
                            color: c.foregroundSecondary,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                    if (r != null && !skipped)
                      MetaLine([
                        MetaItem(
                          r.resolution == null
                              ? 'Unknown quality'
                              : '${r.resolution}p',
                          technical: r.resolution != null,
                        ),
                        MetaItem(sizeLabel(r.sizeBytes), technical: true),
                        MetaItem(
                          '${groupedCount(r.seeders)} seeders',
                          technical: true,
                        ),
                        if (r.isPack)
                          MetaItem(
                            r.isSeriesPack ? 'Series batch' : 'Whole season',
                            icon: Icons.layers_outlined,
                          ),
                      ], style: type.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.s8),
            if (e.blocking)
              SIconButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Skip',
                onPressed: () => onSkip(true),
              )
            else if (skipped)
              SIconButton(
                icon: Icons.undo_rounded,
                tooltip: 'Download after all',
                onPressed: () => onSkip(false),
              )
            else
              Padding(
                padding: const EdgeInsets.all(Space.s8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: IconSizes.control,
                  color: c.foregroundMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The episode number in a recessed well, so a season's rows scan as one
/// column.
class _Number extends StatelessWidget {
  const _Number(this.episode, {required this.muted});

  final int? episode;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceInset,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Text(
        episode == null ? '–' : '$episode',
        style: context.type.technical.copyWith(
          color: muted ? c.foregroundMuted : c.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.look);

  final _StatusLook look;

  @override
  Widget build(BuildContext context) => Row(
    spacing: Space.s4,
    children: [
      SizedBox.square(
        dimension: 14,
        child: look.icon == null
            ? CircularProgressIndicator(strokeWidth: 1.5, color: look.color)
            : Icon(look.icon, size: 14, color: look.color),
      ),
      Flexible(
        child: Text(
          look.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.caption.copyWith(
            color: look.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

/// A review status's glyph, words and role: ready is success, a
/// compromise warning, a miss error, the viewer's choice info; null glyph
/// spins.
class _StatusLook {
  const _StatusLook(this.icon, this.label, this.color);
  final IconData? icon;
  final String label;
  final Color color;

  static _StatusLook of(BuildContext context, ReviewEntry e) {
    final c = context.colors;
    final pack = e.torrent?.release.isPack ?? false;
    return switch (e.status) {
      ReviewStatus.waiting => _StatusLook(
        Icons.schedule_rounded,
        'Waiting',
        c.foregroundMuted,
      ),
      ReviewStatus.searching => _StatusLook(
        null,
        'Searching',
        c.foregroundSecondary,
      ),
      ReviewStatus.ready => _StatusLook(
        Icons.check_circle_outline_rounded,
        e.fromPack
            ? 'From the season torrent'
            : pack
            ? 'Season torrent'
            : 'Exact match',
        c.success,
      ),
      ReviewStatus.close => _StatusLook(
        Icons.info_outline_rounded,
        'Closest match · ${_concern(e.concerns.first)}',
        c.warning,
      ),
      ReviewStatus.missing => _StatusLook(
        Icons.error_outline_rounded,
        e.error != null ? 'Search failed' : 'No torrent found',
        c.error,
      ),
      ReviewStatus.chosen => _StatusLook(
        Icons.touch_app_outlined,
        'Your choice',
        c.info,
      ),
      ReviewStatus.skipped => _StatusLook(
        Icons.skip_next_rounded,
        'Skipped',
        c.foregroundMuted,
      ),
    };
  }

  static String _concern(MatchConcern concern) => switch (concern) {
    MatchConcern.otherResolution => 'other quality',
    MatchConcern.unknownResolution => 'quality unknown',
    MatchConcern.seasonPack || MatchConcern.seriesPack => 'batch',
  };
}
