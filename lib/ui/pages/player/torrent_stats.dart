import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../player/stream/torrent_playback.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// The live torrent behind the picture, condensed for the chrome: how much
/// of the file is here, transfer speeds and connected peers. Each fact's
/// tooltip carries the detail.
class TorrentStats extends StatelessWidget {
  const TorrentStats({
    super.key,
    required this.status,
    this.compact = false,
    this.dense = false,
  });

  final ValueListenable<StreamStatus?> status;

  /// Progress and the active transfer speed, for narrow players.
  final bool compact;

  /// Left-aligned and tight, for sitting under a title.
  final bool dense;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) {
      if (status == null ||
          !(status.stage == StreamStage.connecting ||
              status.stage == StreamStage.preparing ||
              status.stage == StreamStage.streaming)) {
        return const SizedBox.shrink();
      }
      final t = status.transfer;
      final progress = t.selectedProgress;
      final file = t.selectedFile;
      final peers = t.connectedPeers;
      final local = status.localFile != null;
      final downloaded = local || (progress != null && progress >= 1);
      final sharing = !local || file != null;
      return Semantics(
        container: true,
        label: [
          if (downloaded)
            'Downloaded'
          else if (progress != null)
            '${_percent(progress)} downloaded',
          if (!downloaded) '${_speed(t.downloadBytesPerSecond)} down',
          if (sharing && (downloaded || !compact))
            '${_speed(t.uploadBytesPerSecond)} up',
          if (sharing && !compact) '$peers peers',
        ].join(', '),
        child: ExcludeSemantics(
          // Shrinks to fit narrow headers instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: dense ? Alignment.centerLeft : Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (downloaded || (progress != null && file != null))
                  _Stat(
                    dense: dense,
                    leading: downloaded
                        ? const Icon(Icons.check_circle_outline_rounded)
                        : _Ring(progress!),
                    label: downloaded ? 'Downloaded' : _percent(progress!),
                    tooltip: downloaded
                        ? 'The video is downloaded and ready to play'
                        : '${_percent(progress!)} of the video downloaded · '
                              '${sizeLabel(t.selectedBytes)} of ${sizeLabel(file!.length)}',
                  ),
                if (!downloaded)
                  _Stat(
                    dense: dense,
                    leading: const Icon(Icons.arrow_downward_rounded),
                    label: _speed(t.downloadBytesPerSecond),
                    tooltip:
                        'Download speed · ${sizeLabel(t.receivedBytes)} received',
                  ),
                if (sharing && (downloaded || !compact))
                  _Stat(
                    dense: dense,
                    leading: const Icon(Icons.arrow_upward_rounded),
                    label: _speed(t.uploadBytesPerSecond),
                    tooltip:
                        'Upload speed · ${sizeLabel(t.uploadedBytes)} shared',
                  ),
                if (sharing && !compact) ...[
                  _Stat(
                    dense: dense,
                    leading: const Icon(Icons.people_outline_rounded),
                    label: '$peers',
                    tooltip: peers == 0
                        ? 'Looking for peers'
                        : '$peers ${peers == 1 ? 'peer' : 'peers'} connected, '
                              '${t.connectedSeeds} with the whole file',
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The opening cover's line while the torrent gets going; null leaves the
/// cover's default.
String? streamLabel(StreamStatus? status) {
  if (status == null) return null;
  final peers = status.transfer.connectedPeers;
  final suffix = peers == 0 ? '' : ' · $peers ${peers == 1 ? 'peer' : 'peers'}';
  return switch (status.stage) {
    StreamStage.finding => 'Finding a torrent',
    StreamStage.connecting => 'Connecting to peers$suffix',
    StreamStage.preparing => 'Preparing the video$suffix',
    StreamStage.streaming => 'Buffering$suffix',
    StreamStage.switching => 'Switching torrents',
    StreamStage.failed => null,
  };
}

String _percent(double fraction) => '${(fraction * 100).floor()}%';

String _speed(int bytesPerSecond) => '${sizeLabel(bytesPerSecond)}/s';

class _Stat extends StatelessWidget {
  const _Stat({
    required this.leading,
    required this.label,
    required this.tooltip,
    this.dense = false,
  });

  final bool dense;
  final Widget leading;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color = context.player.foregroundSecondary;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: dense
            ? const EdgeInsets.only(right: Space.s12)
            : const EdgeInsets.symmetric(horizontal: Space.s8),
        child: IconTheme.merge(
          data: IconThemeData(size: dense ? 14 : 16, color: color),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 16, child: Center(child: leading)),
              const SizedBox(width: Space.s4),
              Text(
                label,
                maxLines: 1,
                style: context.type.technical.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verified share of the file, as a small determinate ring.
class _Ring extends StatelessWidget {
  const _Ring(this.value);

  final double value;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 12,
    child: CircularProgressIndicator(
      value: value,
      strokeWidth: 2,
      color: context.player.foreground,
      backgroundColor: context.player.trackUnloaded,
      strokeCap: StrokeCap.round,
    ),
  );
}
