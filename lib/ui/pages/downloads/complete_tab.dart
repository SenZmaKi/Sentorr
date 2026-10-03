import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'download_groups.dart';

/// Downloads on this device: movies first, then each series under its
/// name, a season's episodes together in order.
class CompleteTab extends StatelessWidget {
  const CompleteTab({super.key, required this.views, required this.compact});

  final List<DownloadView> views;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      return const DownloadsEmpty(
        icon: Icons.download_done_rounded,
        title: 'Nothing downloaded yet',
        message:
            'Finished downloads appear here and play without waiting for '
            'peers.',
      );
    }
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s12),
          child: Text(
            '${sizeLabel(totalBytes(views))} · plays without waiting for '
            'peers',
            style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
          ),
        ),
        for (final (name, group) in seriesGroups(views)) ...[
          const SizedBox(height: Space.s24),
          if (name != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s12),
              child: Text(
                name,
                style: context.type.subtitle.copyWith(color: c.foreground),
              ),
            ),
          for (final season in seasonGroups(group)) ...[
            if (season.first.entry.item.isEpisode)
              _SeasonLabel(season)
            else
              const SizedBox(height: Space.s8),
            DownloadRows(season, compact: compact),
          ],
        ],
      ],
    );
  }
}

/// A finished season's name and how much of it is here; its controls live
/// in Ongoing.
class _SeasonLabel extends StatelessWidget {
  const _SeasonLabel(this.views);

  final List<DownloadView> views;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = views.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.s12,
        Space.s16,
        Space.s12,
        Space.s8,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Season ${views.first.entry.item.season}',
              style: context.type.label.copyWith(color: c.foreground),
            ),
            TextSpan(
              text:
                  '   $n episode${n == 1 ? '' : 's'} · '
                  '${sizeLabel(totalBytes(views))}',
              style: context.type.caption.copyWith(color: c.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}
