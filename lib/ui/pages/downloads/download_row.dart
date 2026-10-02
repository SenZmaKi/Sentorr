import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../downloads/models.dart';
import '../../../library/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/interactive.dart';
import '../../components/progress_track.dart';
import '../../components/title_artwork.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// One downloaded or downloading item: its artwork, names, where the
/// transfer stands, and what can be done with it. A row on the page plane.
class DownloadRow extends ConsumerWidget {
  const DownloadRow({
    super.key,
    required this.entry,
    required this.state,
    this.download,
    this.compact = false,
  });

  final LibraryEntry entry;
  final OfflineState state;
  final DownloadItem? download;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final item = entry.item;
    return Interactive(
      borderRadius: Radii.card,
      onTap: () => ref.playDownload(entry),
      semanticLabel: 'Play ${itemLabel(item)}, ${_status(state, download).$2}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        curve: Motion.change,
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: s.pressed
              ? c.statePressed
              : s.hovered
              ? c.stateHover
              : c.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 96 : 128,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ArtworkFrame(
                  active: s.hovered || s.focused,
                  artwork: item.title.poster != null
                      ? TitleArtwork(image: item.title.poster)
                      : TitleBackdrop(title: item.series ?? item.title),
                  hoverOverlay: const Center(
                    child: OverlayGlyph(
                      Icons.play_arrow_rounded,
                      primary: true,
                    ),
                  ),
                  decorations: [
                    if (item.isEpisode)
                      Positioned(
                        left: Space.s4,
                        top: Space.s4,
                        child: OverlayBadge(
                          episodeCode(item.season, item.episode),
                          technical: true,
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.s16),
            Expanded(child: _Details(entry, state, download)),
            const SizedBox(width: Space.s8),
            ..._actions(context, ref),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) => switch (state) {
    Downloading(:final status) => [
      if (status == OfflineProgress.paused)
        SIconButton(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Resume download',
          onPressed: () => ref.resumeDownload(entry),
        )
      else
        SIconButton(
          icon: Icons.pause_rounded,
          tooltip: 'Pause download',
          onPressed: () => ref.pauseDownload(entry),
        ),
      SIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Cancel download',
        onPressed: () => ref.deleteDownload(context, entry, finished: false),
      ),
    ],
    Downloaded() => [
      SIconButton(
        icon: Icons.folder_open_rounded,
        tooltip: 'Show in folder',
        onPressed: () => ref.showDownload(entry),
      ),
      SIconButton(
        icon: Icons.delete_outline_rounded,
        tooltip: 'Delete download',
        onPressed: () => ref.deleteDownload(context, entry),
      ),
    ],
    DownloadFailed() => [
      SIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'Try again',
        onPressed: () => ref.download(entry.item),
      ),
      SIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Remove',
        onPressed: () => ref.deleteDownload(context, entry, finished: false),
      ),
    ],
    _ => const [],
  };
}

class _Details extends StatelessWidget {
  const _Details(this.entry, this.state, this.download);

  final LibraryEntry entry;
  final OfflineState state;
  final DownloadItem? download;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = entry.item;
    final (icon, label, tone) = _status(state, download);
    final color = switch (tone) {
      _Tone.neutral => c.foregroundSecondary,
      _Tone.info => c.info,
      _Tone.success => c.success,
      _Tone.error => c.error,
    };
    final d = download;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.series case final series?) CardEyebrow(series.title),
        CardTitle(item.name, large: true),
        const SizedBox(height: Space.s4),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Space.s4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s2),
        MetaLine([
          if (d != null && d.totalBytes > 0)
            MetaItem(
              state is Downloaded
                  ? sizeLabel(d.totalBytes)
                  : '${sizeLabel(d.downloadedBytes)} of ${sizeLabel(d.totalBytes)}',
              technical: true,
            ),
          if (d != null && d.downloadBytesPerSecond > 0)
            MetaItem(
              '${sizeLabel(d.downloadBytesPerSecond.round())}/s',
              icon: Icons.arrow_downward_rounded,
              technical: true,
            ),
          if (d != null && d.uploadBytesPerSecond > 0)
            MetaItem(
              '${sizeLabel(d.uploadBytesPerSecond.round())}/s',
              icon: Icons.arrow_upward_rounded,
              technical: true,
            ),
          if (d != null && d.status == DownloadStatus.downloading)
            MetaItem(
              '${d.peers}',
              icon: Icons.people_outline_rounded,
              technical: true,
            ),
        ]),
        if (state case Downloading(:final progress)) ...[
          const SizedBox(height: Space.s8),
          ProgressTrack.value(progress),
        ],
        if (state case DownloadFailed(:final error?)) ...[
          const SizedBox(height: Space.s4),
          Text(
            error,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: c.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

enum _Tone { neutral, info, success, error }

/// Queued and paused are neutral, moving is info, done is success and a
/// failure is error, each with its own icon and words.
(IconData, String, _Tone) _status(
  OfflineState state,
  DownloadItem? d,
) => switch (state) {
  Downloading(:final status, :final progress) => switch (status) {
    OfflineProgress.preparing => (
      Icons.hourglass_empty_rounded,
      'Preparing',
      _Tone.neutral,
    ),
    OfflineProgress.queued => (Icons.schedule_rounded, 'Queued', _Tone.neutral),
    OfflineProgress.paused => (
      Icons.pause_rounded,
      'Paused at ${(progress * 100).floor()}%',
      _Tone.neutral,
    ),
    OfflineProgress.downloading => (
      Icons.downloading_rounded,
      'Downloading ${(progress * 100).floor()}%',
      _Tone.info,
    ),
  },
  Downloaded() =>
    d?.status == DownloadStatus.seeding
        ? (Icons.download_done_rounded, 'Downloaded · sharing', _Tone.success)
        : (Icons.download_done_rounded, 'Downloaded', _Tone.success),
  DownloadFailed() => (
    Icons.error_outline_rounded,
    'Download failed',
    _Tone.error,
  ),
  _ => (Icons.download_rounded, 'Not downloaded', _Tone.neutral),
};
