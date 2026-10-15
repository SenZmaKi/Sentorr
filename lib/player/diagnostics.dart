import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Samples only while diagnostics are visible. Missing native properties are
/// explicit, because backend support varies across devices.
class PlaybackDiagnostics extends ChangeNotifier {
  PlaybackDiagnostics(this.read, {this.source, this.engine}) {
    unawaited(sample());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  }

  factory PlaybackDiagnostics.forPlayer(
    Player player, {
    Object? Function()? source,
    Future<Map<String, Object?>?> Function()? engine,
  }) => PlaybackDiagnostics(
    (property) async {
      final native = player.platform;
      return native is NativePlayer ? native.getProperty(property) : '';
    },
    source: source,
    engine: engine,
  );

  /// The torrent engine's detail, sampled on the same tick; see
  /// `TorrentStreamSession.diagnose`.
  final Future<Map<String, Object?>?> Function()? engine;
  Map<String, Object?>? torrent;

  final Object? Function()? source;
  Object? _source;
  final _counterStarts = <String, int>{};

  final Future<String> Function(String) read;
  late final Timer _timer;
  bool _closed = false, _busy = false;
  Map<String, String> values = {};

  /// Player configuration that holds for a session: read once, on request.
  static const config = [
    'hwdec',
    'current-vo',
    'gpu-api',
    'gpu-context',
    'video-sync',
    'cache',
    'cache-secs',
    'demuxer-max-bytes',
    'demuxer-max-back-bytes',
    'demuxer-readahead-secs',
    'mpv-version',
    'ffmpeg-version',
  ];

  Future<Map<String, Object?>> readConfig() async => {
    for (final key in config)
      key: await read(key).then<String?>((v) => v, onError: (_) => null),
  };
  static const properties = [
    ...video,
    'demuxer-cache-duration',
    'video-bitrate',
    'audio-bitrate',
    // Bytes/s mpv reads from the local torrent server.
    'cache-speed',
    'paused-for-cache',
    'current-tracks/sub/codec',
    'current-tracks/sub/lang',
    'current-tracks/sub/external',
    'sub-delay',
  ];

  /// Decode and presentation readouts, recorded under their mpv names.
  static const video = [
    'video-codec',
    'audio-codec-name',
    'hwdec-current',
    'video-params/w',
    'video-params/h',
    'container-fps',
    'estimated-vf-fps',
    'display-fps',
    'decoder-frame-drop-count',
    'frame-drop-count',
    'avsync',
    'video-params/pixelformat',
    'video-params/gamma',
  ];

  Future<void> sample() async {
    if (_busy || _closed) return;
    final identity = source?.call();
    if (identity != _source) {
      _source = identity;
      values = {};
      torrent = null;
      _counterStarts.clear();
      notifyListeners();
    }
    _busy = true;
    final next = <String, String>{};
    try {
      for (final key in properties) {
        if (_closed) return;
        try {
          final value = await read(key);
          if (identity != source?.call()) return;
          final count = int.tryParse(value);
          if (source != null &&
              count != null &&
              (key == 'decoder-frame-drop-count' ||
                  key == 'frame-drop-count')) {
            final start = _counterStarts.putIfAbsent(key, () => count);
            if (count < start) _counterStarts[key] = 0;
            next[key] = '${count - _counterStarts[key]!}';
          } else {
            next[key] = value.isEmpty ? 'Unavailable' : value;
          }
        } catch (_) {
          next[key] = 'Unavailable';
        }
      }
      final torrent = await engine?.call();
      if (!_closed && identity == source?.call()) {
        values = next;
        this.torrent = torrent;
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer.cancel();
    super.dispose();
  }
}
