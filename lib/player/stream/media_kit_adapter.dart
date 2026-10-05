import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

final _log = Logger('sentorr.player.stream');

/// Plays a [TorrentStream] endpoint in MediaKit with the cache policy the
/// streaming lab validated, and keeps engine reads in step with seeks.
class MediaKitTorrentAdapter {
  MediaKitTorrentAdapter(this.player);

  final Player player;
  bool _configured = false;

  /// Seconds of playable cache mpv waits for before starting or resuming.
  static const readySeconds = 10;

  /// Seconds mpv reads ahead of the position.
  static const forwardSeconds = 60;

  /// Must exceed the engine's piece wait, or mpv abandons slow reads.
  static const httpTimeoutSeconds = 60;

  /// Plays [stream] from [start], or its beginning.
  Future<void> open(
    TorrentStream stream, {
    Duration? start,
    required bool Function() isCurrent,
  }) async {
    await _configure();
    if (!isCurrent()) return;
    await player.open(Media(stream.uri.toString(), start: start));
  }

  /// Cancels the engine's obsolete reads before mpv asks for [position].
  Future<void> seek(
    TorrentStreamSession? session,
    Duration position, {
    required bool Function() isCurrent,
  }) async {
    _log.fine('Seeking to $position');
    try {
      await session?.prepareSeek();
    } on TorrentStreamException catch (error) {
      // A closing session has nothing left to cancel.
      _log.fine('Seek preparation skipped: $error');
    }
    if (isCurrent()) await player.seek(position);
  }

  Future<void> _configure() async {
    if (_configured) return;
    final native = player.platform;
    if (native is! NativePlayer) return;
    for (final MapEntry(:key, :value) in const {
      'network-timeout': '$httpTimeoutSeconds',
      'cache': 'yes',
      'cache-secs': '$forwardSeconds',
      'cache-pause': 'yes',
      'cache-pause-initial': 'yes',
      'cache-pause-wait': '$readySeconds',
      'demuxer-max-bytes': '${64 * 1024 * 1024}',
      'demuxer-max-back-bytes': '${16 * 1024 * 1024}',
    }.entries) {
      await native.setProperty(key, value);
    }
    _configured = true;
  }
}
