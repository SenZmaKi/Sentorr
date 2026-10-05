import 'dart:math';

import 'cancellation.dart';
import 'torrent_bytes.dart';

/// Warm the header while HTTP is available. The demuxer requests container
/// indexes at the tail only when needed; all bytes require piece verification.
Future<void> bootstrapMedia(
  TorrentBytes source,
  Cancellation lifetime,
  void Function(Map<String, Object?>) onEvent,
) async {
  final watch = Stopwatch()..start();
  final head = Cancellation();
  onEvent({'event': 'bootstrap-start'});
  try {
    final size = min(64 * 1024, source.length);
    await lifetime.wait(source.read(0, size, head));
    onEvent({
      'event': 'bootstrap-ready',
      'elapsedBootstrapMs': watch.elapsedMilliseconds,
    });
  } finally {
    head.cancel();
    source.release(head);
  }
}
