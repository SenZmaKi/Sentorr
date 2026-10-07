import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../settings/streaming_settings.dart';

final _log = Logger('sentorr.player.stream');

/// Plays a [TorrentStream] endpoint in MediaKit with bounded native caching,
/// and keeps engine reads in step with seeks.
class MediaKitTorrentAdapter {
  MediaKitTorrentAdapter(this.player, {this.settings});

  final Player player;
  final StreamingSettings Function()? settings;

  /// Seconds of playable cache mpv waits for before starting or resuming.
  static const readySeconds = 2;

  /// Seconds mpv reads ahead of the position.
  static const forwardSeconds = 60;

  /// Must exceed the engine's piece wait, or mpv abandons slow reads.
  static const httpTimeoutSeconds = 60;

  /// Plays [stream] from [start], or its beginning.
  Future<void> open(
    TorrentStream stream, {
    Duration? start,
    required bool Function() isCurrent,
    bool Function()? canAutoplay,
  }) async {
    await configure();
    if (!isCurrent()) return;
    await player.open(
      Media(stream.uri.toString(), start: start),
      play: canAutoplay?.call() ?? true,
    );
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

  Future<void> configure({bool streaming = true}) async {
    final s = settings?.call() ?? const StreamingSettings();
    final native = player.platform;
    if (native is! NativePlayer) return;
    for (final MapEntry(:key, :value) in {
      if (streaming) ...{
        'network-timeout': '$httpTimeoutSeconds',
        'cache': 'yes',
        'cache-secs': '$forwardSeconds',
        'cache-pause': 'yes',
        'cache-pause-initial': 'yes',
        'cache-pause-wait': '$readySeconds',
      },
      'demuxer-max-bytes': '${s.playerForwardBufferMiB * 1024 * 1024}',
      'demuxer-max-back-bytes': '${s.playerBackwardBufferMiB * 1024 * 1024}',
    }.entries) {
      await native.setProperty(key, value);
    }
  }
}
