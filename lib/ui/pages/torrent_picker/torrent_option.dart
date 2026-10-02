import 'package:flutter/material.dart';

import '../../../torrents/filters.dart';
import '../../../torrents/release_traits.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/source_icon.dart';
import '../../components/cards/card_parts.dart';
import '../../components/interactive.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// Whether a torrent already ran for the item being picked for.
enum OptionMark { none, playing, failed }

/// One torrent to choose, aligned by information: filename, then quality
/// and what the name says about the video, then size, availability and
/// where it came from. A row on its parent plane; selection adds a check.
class TorrentOption extends StatelessWidget {
  const TorrentOption({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
    this.best = false,
    this.mark = OptionMark.none,
  });

  final TorrentCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  /// The candidate ranked first for the viewer's preferences.
  final bool best;
  final OptionMark mark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = candidate.release;
    final traits = ReleaseTraits.of(r.name);
    final quality = QualityBand.of(r.resolution);
    final uploaded = r.uploadedAt;
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: [
        r.name,
        if (mark == OptionMark.playing) 'playing',
        if (mark == OptionMark.failed) 'failed to start',
      ].join(', '),
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
                  if (mark != OptionMark.none) _Mark(mark),
                  MetaLine([
                    if (best)
                      const MetaItem('Best match', icon: Icons.check_rounded),
                    MetaItem(
                      r.resolution == null
                          ? 'Unknown quality'
                          : quality == QualityBand.uhd
                          ? '4K'
                          : '${r.resolution}p',
                      icon: Icons.high_quality_outlined,
                      technical: r.resolution != null,
                    ),
                    if (traits.origin case final origin?)
                      MetaItem(origin.label),
                    if (traits.codec case final codec?) MetaItem(codec.label),
                    if (traits.hdr) const MetaItem('HDR'),
                  ], style: context.type.bodySmall),
                  MetaLine([
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
                      MetaItem(
                        r.isSeriesPack ? 'Series batch' : 'Whole season',
                        icon: Icons.layers_outlined,
                      ),
                    MetaItem(
                      r.source.label,
                      leading: (size) => SourceIcon(r.source, size: size),
                    ),
                    if (uploaded != null)
                      MetaItem(
                        ageLabel(uploaded),
                        icon: Icons.schedule_rounded,
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

/// Playing or failed, led by an icon so color is not the only cue.
class _Mark extends StatelessWidget {
  const _Mark(this.mark);

  final OptionMark mark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final failed = mark == OptionMark.failed;
    final color = failed ? c.error : c.success;
    return Row(
      spacing: Space.s4,
      children: [
        Icon(
          failed ? Icons.error_outline_rounded : Icons.play_circle_outline,
          size: IconSizes.metadata,
          color: color,
        ),
        Text(
          failed ? 'Couldn’t start' : 'Playing',
          style: context.type.label.copyWith(color: color),
        ),
      ],
    );
  }
}

/// "3 days ago", coarsening with distance.
String ageLabel(DateTime when, {DateTime? now}) {
  final days = (now ?? DateTime.now()).difference(when).inDays;
  String unit(int n, String name) => '$n $name${n == 1 ? '' : 's'} ago';
  return switch (days) {
    < 1 => 'Today',
    < 30 => unit(days, 'day'),
    < 365 => unit(days ~/ 30, 'month'),
    _ => unit(days ~/ 365, 'year'),
  };
}
