import 'package:torrent_stream/torrent_stream.dart';

import '../../../player/stream/stream_status.dart';
import '../../shared/title_format.dart';
import 'stats_readout.dart';

/// How far playback can run on what is buffered and downloaded, and how the
/// swarm is delivering it.
class NetworkStats {
  NetworkStats(this._s, this._d, this._position);

  final StreamStatus? _s;
  final NativeReadout _d;
  final double _position;

  TorrentStreamState? get _t => _s?.transfer;
  bool get _streaming => _s != null && _s.localFile == null;
  bool get _seeding =>
      _s?.localFile != null && _s?.transfer.selectedFile != null;

  /// Seconds downloaded contiguously from the playhead; what a stall waits on.
  double? get _ahead {
    final t = _t;
    if (!_streaming || t == null || t.downloadedTimes.isEmpty) return null;
    for (final r in t.downloadedTimes) {
      if (r.start <= _position + 0.5 && r.end > _position) {
        return r.end - _position;
      }
    }
    return 0;
  }

  String get _source => _s?.peer != null
      ? 'Downloaded on ${_s!.peer}'
      : _s?.localFile != null
      ? 'Downloaded file'
      : _s?.stage.name ?? 'Waiting';

  String get source => _source;

  StatsSection get buffer => (
    title: 'Buffer',
    rows: [
      ('Buffer health (s)', _d['demuxer-cache-duration']),
      ('Waiting on cache', yesNo(_d.flag('paused-for-cache'))),
      (
        'Bitrate (video / audio)',
        '${_d.bitrate('video-bitrate')} / ${_d.bitrate('audio-bitrate')}',
      ),
      if (_streaming) ...[
        (
          'Stream read speed',
          switch (int.tryParse(_d.values['cache-speed'] ?? '')) {
            final b? => '${sizeLabel(b)}/s',
            null => _d['cache-speed'],
          },
        ),
        ('Downloaded ahead (s)', _ahead?.toStringAsFixed(1) ?? 'Unknown'),
        ('Downloaded ranges', '${_t!.downloadedTimes.length}'),
        if (_t!.startupStatus.isNotEmpty) ('Startup', _t!.startupStatus),
        if (_t!.indexStatus.isNotEmpty) ('Index', _t!.indexStatus),
      ],
    ],
  );

  StatsSection get network {
    final t = _t;
    return (
      title: 'Network',
      rows: [
        ('Source', _source),
        if (_seeding) ...[
          ('Upload speed', '${sizeLabel(t!.uploadBytesPerSecond)}/s'),
          ('Uploaded', sizeLabel(t.uploadedBytes)),
          (
            'Peers / seeds (connected)',
            '${t.connectedPeers} / ${t.connectedSeeds}',
          ),
        ],
        if (_streaming) ...[
          ('File', t!.selectedFile?.path ?? 'Waiting for metadata'),
          (
            'Phase / transfer',
            '${t.phase.name} / ${t.transferState.name}'
                '${t.transferPaused ? ' (paused)' : ''}',
          ),
          (
            'Download / upload',
            '${sizeLabel(t.downloadBytesPerSecond)}/s / ${sizeLabel(t.uploadBytesPerSecond)}/s',
          ),
          (
            'Peers / seeds (connected)',
            '${t.connectedPeers} / ${t.connectedSeeds}',
          ),
          (
            'Connections / known / candidates',
            '${t.connections} / ${t.knownPeers} / ${t.connectionCandidates}',
          ),
          (
            'File downloaded',
            '${sizeLabel(t.selectedBytes)} / ${t.selectedFile == null ? 'Unknown' : sizeLabel(t.selectedFile!.length)}',
          ),
          (
            'Received / uploaded',
            '${sizeLabel(t.receivedBytes)} / ${sizeLabel(t.uploadedBytes)}',
          ),
          (
            'Read cache / served',
            '${sizeLabel(t.cachedBytes)} / ${sizeLabel(t.servedBytes)}',
          ),
          ('Read requests', '${t.requests}'),
          if (t.failure case final f?) ('Failure', f.message),
        ],
        if (_s?.problem case final p?) ('Problem', p),
      ],
    );
  }

  Map<String, Object?> get metrics {
    final t = _t;
    return {
      'stage': _s?.stage.name,
      'source': _source,
      'bufferSeconds': _d.typed('demuxer-cache-duration'),
      'pausedForCache': _d.flag('paused-for-cache'),
      'videoBitrate': _d.typed('video-bitrate'),
      'audioBitrate': _d.typed('audio-bitrate'),
      'problem': _s?.problem,
      if (t != null && _streaming) ...{
        'streamReadBytesPerSecond': _d.typed('cache-speed'),
        'downloadedAheadSeconds': switch (_ahead) {
          final a? => double.parse(a.toStringAsFixed(1)),
          null => null,
        },
        'downloadedRanges': t.downloadedTimes.length,
        'mediaDurationSeconds': t.mediaDuration > 0 ? t.mediaDuration : null,
        'phase': t.phase.name,
        'transferState': t.transferState.name,
        'transferPaused': t.transferPaused,
        'startupStatus': t.startupStatus,
        'indexStatus': t.indexStatus,
        'failure': t.failure?.message,
        'connections': t.connections,
        'knownPeers': t.knownPeers,
        'connectionCandidates': t.connectionCandidates,
        'fileDownloadedBytes': t.selectedBytes,
        'receivedBytes': t.receivedBytes,
        'cachedBytes': t.cachedBytes,
        'servedBytes': t.servedBytes,
        'readRequests': t.requests,
      },
      if (t != null && (_streaming || _seeding)) ...{
        'downloadBytesPerSecond': t.downloadBytesPerSecond,
        'uploadBytesPerSecond': t.uploadBytesPerSecond,
        'uploadedBytes': t.uploadedBytes,
        'peers': t.connectedPeers,
        'seeds': t.connectedSeeds,
      },
    };
  }

  /// Which source is playing; a change starts a new recording segment.
  Object get key => (_s?.torrent?.release.infoHash, _s?.localFile, _s?.peer);

  /// Details of [key] that may fill in after it starts, e.g. the file once
  /// metadata arrives.
  Map<String, Object?> get identity {
    final file = _t?.selectedFile;
    return {
      'infoHash': _s?.torrent?.release.infoHash,
      'release': _s?.torrent?.release.name,
      'file': file?.path ?? _s?.localFile,
      'fileSizeBytes': file?.length,
      'peer': _s?.peer,
    };
  }
}
