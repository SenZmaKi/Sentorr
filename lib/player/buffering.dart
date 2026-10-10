import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Cache pauses and unfinished seeks are waits even when mpv reports paused.
/// Core-idle alone is also emitted by deliberate pauses and frame steps.
class PlaybackBuffering extends ValueNotifier<bool> {
  PlaybackBuffering() : super(false);

  bool _playing = false, _buffering = false, _cachePaused = false;
  bool _seeking = false, _seekRequested = false, _preparingSeek = false;
  bool _disposed = false;
  final _subscriptions = <StreamSubscription<Object?>>[];
  NativePlayer? _native;
  Future<void>? _ready;

  Future<void> attach(Player player) => _ready ??= _attach(player);

  Future<void> _attach(Player player) async {
    playing(player.state.playing);
    buffering(player.state.buffering);
    _subscriptions.addAll([
      player.stream.playing.listen(playing),
      player.stream.buffering.listen(buffering),
    ]);
    final native = player.platform;
    if (native is! NativePlayer) return;
    _native = native;
    for (final entry in {
      'seeking': seeking,
      'paused-for-cache': cachePaused,
    }.entries) {
      await native.observeProperty(entry.key, (value) async {
        if (!_disposed) entry.value(value == 'yes' || value == 'true');
      });
    }
  }

  void playing(bool value) {
    _playing = value;
    _sync();
  }

  void buffering(bool value) {
    _buffering = value;
    _sync();
  }

  void cachePaused(bool value) {
    _cachePaused = value;
    _sync();
  }

  void seeking(bool value) {
    if (_seeking && !value) _seekRequested = false;
    _seeking = value;
    _sync();
  }

  void beginSeek() {
    _seekRequested = true;
    _preparingSeek = true;
    _sync();
  }

  /// Command completion is not frame readiness; mpv's seeking flag owns
  /// the remainder of the wait.
  void seekIssued() {
    _preparingSeek = false;
    _sync();
  }

  void reset() {
    _seekRequested = _preparingSeek = _seeking = _cachePaused = false;
    _sync();
  }

  void _sync() {
    if (!_disposed) {
      value =
          _preparingSeek ||
          (_seekRequested && _seeking) ||
          _cachePaused ||
          (_playing && _buffering);
    }
  }

  Future<void> close() async {
    _disposed = true;
    await _ready;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    if (_native case final native?) {
      await native.unobserveProperty('seeking');
      await native.unobserveProperty('paused-for-cache');
    }
    super.dispose();
  }
}
