import 'dart:async';

import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

/// Drives disk demand from playback, even when the demuxer's RAM cache is full.
class DownloadAhead {
  DownloadAhead(this.player, this.session) {
    _position = player.stream.position.listen((_) => _update());
    _duration = player.stream.duration.listen((_) => _update());
    _update();
  }

  final Player player;
  final TorrentStreamSession session;
  late final StreamSubscription<Duration> _position, _duration;
  bool _closed = false, _running = false, _dirty = false;

  void _update() {
    if (_closed) return;
    _dirty = true;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_dirty && !_closed) {
        _dirty = false;
        await session.bufferAhead(player.state.position, player.state.duration);
      }
    } on Object catch (error) {
      if (!_closed) {
        Logger('sentorr.player.buffer').warning('Download ahead failed', error);
      }
    } finally {
      _running = false;
    }
  }

  void close() {
    _closed = true;
    unawaited(_position.cancel());
    unawaited(_duration.cancel());
  }
}
