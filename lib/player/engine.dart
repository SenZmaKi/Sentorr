import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';
import 'session.dart';

final _log = Logger('sentorr.player');

/// The native player for one open session. Volume, speed and track choices
/// carry across queue items because the same player opens each of them.
class PlaybackEngine {
  PlaybackEngine()
    : player = Player(
        configuration: const PlayerConfiguration(title: 'Sentorr'),
      ) {
    _errors = player.stream.error.listen(
      (error) => _log.warning('Playback error: $error'),
    );
  }

  final Player player;
  late final VideoController video = VideoController(player);
  String? _opened;
  late final StreamSubscription<String> _errors;

  PlayerState get state => player.state;
  PlayerStream get stream => player.stream;

  Future<void> open(PlaybackItem item) async {
    if (item.id == _opened) return;
    _opened = item.id;
    _log.info('Opening ${item.name} from ${item.source}');
    await player.open(Media(item.source.toString()));
  }

  /// Opens [item] again after a failure.
  Future<void> reopen(PlaybackItem item) {
    _opened = null;
    return open(item);
  }

  /// Restart when past the opening seconds, as a Previous press would.
  bool get pastStart => player.state.position > const Duration(seconds: 3);

  Future<void> seekBy(Duration delta) {
    final s = player.state;
    final target = s.position + delta;
    return player.seek(
      target < Duration.zero
          ? Duration.zero
          : (s.duration > Duration.zero && target > s.duration
                ? s.duration
                : target),
    );
  }

  /// [volume] is 0–100, as the native player takes it.
  Future<void> setVolume(double volume) =>
      player.setVolume(volume.clamp(0, 100).toDouble());

  Future<void> dispose() async {
    await _errors.cancel();
    await player.dispose();
  }
}

/// Lives while the player page is mounted and follows the session's current
/// item. Torrent streaming will resolve [PlaybackItem.source] before opening.
final playbackEngineProvider = Provider.autoDispose<PlaybackEngine>((ref) {
  final engine = PlaybackEngine();
  ref.onDispose(engine.dispose);
  ref.listen(playerSessionProvider.select((s) => s?.current), (_, item) {
    if (item != null) unawaited(engine.open(item));
  }, fireImmediately: true);
  return engine;
});
