import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'models.dart';

/// Notes where the viewer is in the playing item: every [interval] of
/// playback, shortly after a seek, when it pauses or ends, and once more
/// when it is left.
class ProgressTracker {
  ProgressTracker(this._player, {required this.canRecord, required this.save}) {
    _subscriptions = [
      _player.stream.position.listen(_moved),
      _player.stream.playing.listen((playing) {
        if (!playing) flush();
      }),
      _player.stream.completed.listen((done) {
        if (done) flush();
      }),
    ];
  }

  /// Often enough that little is lost, rarely enough to keep writes cheap.
  static const interval = Duration(seconds: 15);

  /// A position change this large is a seek rather than playback.
  static const seekJump = Duration(seconds: 3);

  /// How long a seek must hold before it is saved, so scrubbing saves once.
  static const seekSettle = Duration(seconds: 1);

  final Player _player;

  /// Whether the player's position belongs to the item, e.g. not while
  /// another torrent or item is starting.
  final bool Function(PlaybackItem item) canRecord;
  final void Function(PlaybackItem item, Duration position, Duration duration)
  save;

  late final List<StreamSubscription<Object?>> _subscriptions;
  final _clock = Stopwatch();
  Timer? _seek;
  Duration _last = Duration.zero;
  PlaybackItem? _item;

  /// The item now playing; the one before it is saved first.
  set item(PlaybackItem? next) {
    if (next?.id == _item?.id) return;
    flush();
    _item = next;
    _clock.reset();
  }

  void _moved(Duration position) {
    final jumped = (position - _last).abs() >= seekJump;
    _last = position;
    if (jumped) {
      _seek?.cancel();
      _seek = Timer(seekSettle, flush);
    }
    if (!_player.state.playing) return;
    if (!_clock.isRunning) _clock.start();
    if (_clock.elapsed >= interval) flush();
  }

  void flush() {
    final item = _item, s = _player.state;
    _seek?.cancel();
    _clock
      ..reset()
      ..stop();
    if (item == null || !canRecord(item)) return;
    if (s.duration <= Duration.zero || s.position <= Duration.zero) return;
    save(item, s.position, s.duration);
  }

  Future<void> dispose() async {
    flush();
    _item = null;
    for (final s in _subscriptions) {
      await s.cancel();
    }
  }
}
