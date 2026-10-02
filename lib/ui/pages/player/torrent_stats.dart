import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../player/stream/torrent_playback.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// The live torrent behind the picture, condensed for the chrome: how much
/// of the file is here, transfer speeds and connected peers. Each fact's
/// tooltip carries the detail.
class TorrentStats extends StatelessWidget {
  const TorrentStats({super.key, required this.status, this.compact = false});

  final ValueListenable<StreamStatus?> status;

  /// Only progress and download speed, for narrow players.
  final bool compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) {
      if (status == null ||
          status.stage == StreamStage.finding ||
          status.stage == StreamStage.failed) {
        return const SizedBox.shrink();
      }
      final t = status.transfer;
      final progress = t.selectedProgress;
      final file = t.selectedFile;
      final peers = t.connectedPeers;
      return Semantics(
        container: true,
        label: [
          if (progress != null) '${_percent(progress)} downloaded',
          '${_speed(t.downloadBytesPerSecond)} down',
          '$peers peers',
        ].join(', '),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress != null && file != null)
                _Stat(
                  leading: progress >= 1
                      ? const Icon(Icons.check_circle_outline_rounded)
                      : _Ring(progress),
                  label: progress >= 1 ? 'Downloaded' : _percent(progress),
                  tooltip:
                      '${_percent(progress)} of the video downloaded · '
                      '${sizeLabel(t.selectedBytes)} of ${sizeLabel(file.length)}',
                ),
              _Stat(
                leading: const Icon(Icons.arrow_downward_rounded),
                label: _speed(t.downloadBytesPerSecond),
                tooltip:
                    'Download speed · ${sizeLabel(t.receivedBytes)} received',
              ),
              if (!compact) ...[
                _Stat(
                  leading: const Icon(Icons.arrow_upward_rounded),
                  label: _speed(t.uploadBytesPerSecond),
                  tooltip:
                      'Upload speed · ${sizeLabel(t.uploadedBytes)} shared',
                ),
                _Stat(
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
  });

  final Widget leading;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color = context.player.foregroundSecondary;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s8),
        child: IconTheme.merge(
          data: IconThemeData(size: 16, color: color),
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
