import 'dart:math';

import 'cancellation.dart';
import 'torrent_bytes.dart';

/// Prepare bounded container probes; all bytes still require piece verification.
Future<void> bootstrapMedia(
  TorrentBytes source,
  Cancellation lifetime,
  void Function(Map<String, Object?>) onEvent,
) async {
  final watch = Stopwatch()..start();
  final head = Cancellation(), tail = Cancellation();
  onEvent({'event': 'bootstrap-start'});
  try {
    final size = min(64 * 1024, source.length);
    await lifetime.wait(
      Future.wait([
        source.read(0, size, head),
        source.read(source.length - size, size, tail),
      ]),
    );
    onEvent({
      'event': 'bootstrap-ready',
      'elapsedBootstrapMs': watch.elapsedMilliseconds,
    });
  } finally {
    head.cancel();
    tail.cancel();
    source.release(head);
    source.release(tail);
  }
}
