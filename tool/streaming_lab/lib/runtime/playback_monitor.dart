import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// mpv's cache pause can differ from MediaKit's buffering notification.
class PlaybackMonitor {
  PlaybackMonitor(this.player, this.changed);
  final Player player;
  final void Function() changed;
  Timer? _timer;
  bool _polling = false, _closed = false;
  bool waiting = false;
  double cachedSeconds = 0;
  final wait = Stopwatch();
  final _unchanged = Stopwatch();
  Duration _lastPosition = Duration.zero;
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_closed || _polling) return;
    _polling = true;
    try {
      final native = player.platform;
      var cachePause = false;
      if (native is NativePlayer) {
        cachedSeconds =
            double.tryParse(
              await native.getProperty('demuxer-cache-duration'),
            ) ??
            0;
        cachePause = await native.getProperty('paused-for-cache') == 'yes';
      }
      if (_closed) return;
      final position = player.state.position;
      if (!player.state.playing || position != _lastPosition) {
        _unchanged
          ..reset()
          ..start();
      } else if (!_unchanged.isRunning) {
        _unchanged.start();
      }
      _lastPosition = position;
      waiting =
          player.state.buffering ||
          cachePause ||
          (player.state.playing &&
              !player.state.completed &&
              _unchanged.elapsed.inSeconds >= 3);
      if (waiting) {
        wait.start();
      } else {
        wait
          ..stop()
          ..reset();
      }
      changed();
    } catch (_) {
      // A stop/dispose can race an in-flight property query.
    } finally {
      _polling = false;
    }
  }

  void close() {
    _closed = true;
    _timer?.cancel();
  }
}
