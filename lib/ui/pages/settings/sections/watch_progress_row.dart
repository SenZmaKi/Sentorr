import 'package:flutter/material.dart';

import '../../../../watching/models.dart';
import '../../../components/buttons.dart';
import '../../../components/progress_track.dart';
import '../../../components/title_artwork.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/title_format.dart';
import '../settings_search.dart';

/// "S1 E3 · Pilot · Today", or "Today" for a movie.
String _context(WatchEntry e) => [
  if (e.isEpisode) ...[episodeCode(e.season, e.episode), e.title.title],
  relativeDay(e.updatedAt),
].join(' · ');

/// One title being watched: its poster, where it left off, a track for how
/// far along it is with the time left beside it, and a remove control.
class WatchProgressRow extends StatelessWidget implements SettingsSearchable {
  const WatchProgressRow({
    super.key,
    required this.entry,
    required this.onRemove,
  });

  final WatchEntry entry;
  final VoidCallback onRemove;

  @override
  bool matches(SettingsSearch? search) =>
      search == null || search.matches([(entry.series ?? entry.title).title]);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = entry.series ?? entry.title;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s12,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: SizedBox(
              width: 40,
              height: 60,
              child: TitleArtwork(image: shown.poster),
            ),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(color: c.foreground),
                ),
                Text(
                  _context(entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodySmall.copyWith(
                    color: c.foregroundSecondary,
                  ),
                ),
                const SizedBox(height: Space.s8),
                Row(
                  children: [
                    Expanded(child: ProgressTrack.value(entry.progress)),
                    const SizedBox(width: Space.s12),
                    Text(
                      '${durationLabel(entry.remaining)} left',
                      style: context.type.technical.copyWith(
                        color: c.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          SIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remove from Continue watching',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
