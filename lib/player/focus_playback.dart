import 'package:flutter/widgets.dart';

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
    return _pending = _pending.then((_) async {
      if (_disposed) return;
      if (state == AppLifecycleState.resumed) {
        if (_resume) {
          _resume = false;
          await play();
        }
      } else if (enabled && !_resume && isPlaying()) {
        _resume = true;
        await pause();
      }
    });
  }
}
