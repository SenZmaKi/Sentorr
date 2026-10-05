import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../downloads/models.dart';
import '../../../library/models.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/progress_track.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'row_frame.dart';
import 'transfer_stats.dart';

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
  Widget build(BuildContext context, WidgetRef ref) => DownloadRowFrame(
    item: entry.item,
    status: _status(state, download),
    facts: _Progress(state, download),
    note: switch (state) {
      DownloadFailed(:final error) => error,
      _ => null,
    },
    onTap: () => ref.playDownload(entry),
    actions: _actions(context, ref),
    compact: compact,
  );

  List<Widget> _actions(BuildContext context, WidgetRef ref) => switch (state) {
    Downloading(status: OfflineProgress.copying) => [
      SIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Cancel copy',
        onPressed: () => ref.cancelDownload(context, entry),
      ),
    ],
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
        onPressed: () => ref.cancelDownload(context, entry),
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
        onPressed: () => ref.download(context, entry.item),
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

/// The transfer's facts, then its track while it runs.
class _Progress extends StatelessWidget {
  const _Progress(this.state, this.download);

  final OfflineState state;
  final DownloadItem? download;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TransferStats(_transfer(state, download)),
      if (state case Downloading(:final progress)) ...[
        const SizedBox(height: Space.s8),
        ProgressTrack.value(progress),
      ],
    ],
  );
}

/// Each state's icon, words and tone.
RowStatus _status(OfflineState state, DownloadItem? d) => switch (state) {
  Downloading(:final status, :final progress, :final from) => switch (status) {
    OfflineProgress.preparing => (
      Icons.hourglass_empty_rounded,
      'Preparing',
      RowTone.neutral,
    ),
    OfflineProgress.queued => (
      Icons.schedule_rounded,
      'Queued',
      RowTone.neutral,
    ),
    OfflineProgress.paused => (
      Icons.pause_rounded,
      'Paused at ${(progress * 100).floor()}%',
      RowTone.neutral,
    ),
    OfflineProgress.downloading => (
      Icons.downloading_rounded,
      'Downloading ${(progress * 100).floor()}%',
      RowTone.info,
    ),
    OfflineProgress.copying => (
      Icons.devices_rounded,
      'Copying from $from ${(progress * 100).floor()}%',
      RowTone.info,
    ),
  },
  Downloaded() =>
    d?.status == DownloadStatus.seeding
        ? (Icons.download_done_rounded, 'Downloaded · sharing', RowTone.success)
        : (Icons.download_done_rounded, 'Downloaded', RowTone.success),
  DownloadFailed() => (
    Icons.error_outline_rounded,
    'Download failed',
    RowTone.error,
  ),
  _ => (Icons.download_rounded, 'Not downloaded', RowTone.neutral),
};

/// Size, then while bytes move: down and up speed, seeds and peers, and
/// time left. Shown at fixed slots while downloading so the line does not
/// jump as speeds touch zero.
List<MetaItem> _transfer(OfflineState state, DownloadItem? d) {
  if (d == null) return const [];
  final live =
      d.status == DownloadStatus.downloading ||
      d.status == DownloadStatus.seeding;
  final downloading = d.status == DownloadStatus.downloading;
  String speed(double v) => '${sizeLabel(v.round())}/s';
  final eta = etaLabel(
    d.totalBytes - d.downloadedBytes,
    d.downloadBytesPerSecond,
  );
  return [
    if (d.totalBytes > 0)
      MetaItem(
        state is Downloaded
            ? sizeLabel(d.totalBytes)
            : '${sizeLabel(d.downloadedBytes)} of ${sizeLabel(d.totalBytes)}',
        technical: true,
      ),
    if (downloading)
      MetaItem(
        speed(d.downloadBytesPerSecond),
        icon: Icons.arrow_downward_rounded,
        technical: true,
      ),
    if (live)
      MetaItem(
        speed(d.uploadBytesPerSecond),
        icon: Icons.arrow_upward_rounded,
        technical: true,
      ),
    if (live) ...[
      MetaItem(
        '${d.seeds} seeds',
        icon: Icons.cloud_done_outlined,
        technical: true,
      ),
      MetaItem(
        '${d.peers} peers',
        icon: Icons.people_outline_rounded,
        technical: true,
      ),
    ],
    if (downloading)
      MetaItem(eta ?? 'Waiting for peers', icon: Icons.timer_outlined),
  ];
}
