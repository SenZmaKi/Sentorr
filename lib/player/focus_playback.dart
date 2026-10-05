import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

final _log = Logger('sentorr.player.focus');

/// Serializes focus changes so returning quickly still waits for pause.
class FocusPlayback {
  FocusPlayback({
    required this.isPlaying,
    required this.pause,
    required this.play,
  });

  final bool Function() isPlaying;
  final Future<void> Function() pause, play;
  bool _resume = false;
  bool _disposed = false;

  void dispose() => _disposed = true;
  Future<void> _pending = Future.value();

  Future<void> change(AppLifecycleState state, {required bool enabled}) {
    return _pending = _pending
        .then((_) async {
          if (_disposed) return;
          if (state == AppLifecycleState.resumed) {
            if (_resume) {
              await play();
              _resume = false;
            }
          } else if (enabled && !_resume && isPlaying()) {
            await pause();
            _resume = !_disposed;
          }
        })
        .catchError((Object error, StackTrace stack) {
          _log.warning('Focus playback change failed', error, stack);
        });
  }
}
