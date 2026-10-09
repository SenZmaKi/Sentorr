import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/shared_streams.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';
import '../support/fake_torrents.dart';

class _SlowEngine extends FakeStreamingEngine {
  final gate = Completer<void>();
  @override
  Future<List<TorrentStreamFile>> metadata(
    String infoHash, {
    Duration? timeout,
  }) async {
    await gate.future;
    return super.metadata(infoHash, timeout: timeout);
  }
}

void main() {
  test('remote owner can close while its stream is still opening', () async {
    final engine = _SlowEngine();
    final source = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path),
    );
    final candidate = TorrentCandidate(
      release: fakeRelease(1),
      score: 1,
      qualityScore: 1,
      availabilityScore: 1,
      sizeScore: 1,
      requiresFileSelection: false,
    );
    final lease = BufferedStreamLease(
      SharedStream(
        PlaybackItem(
          title: ImdbTitle(id: 'tt1', title: 'Film'),
        ),
        candidate,
        source,
        TorrentStream(
          uri: Uri.parse('http://127.0.0.1/source'),
          file: const TorrentStreamFile(
            index: 0,
            path: 'film.mkv',
            length: 1000,
            isPadFile: false,
          ),
        ),
      ),
    );
    final failed = expectLater(
      lease.ready,
      throwsA(isA<TorrentStreamException>()),
    );
    await settlePlayback();
    expect(engine.owners, isNotEmpty);
    await lease.close().timeout(const Duration(seconds: 1));
    await failed;
    expect(engine.owners, isEmpty);
    engine.gate.complete();
    await source.close();
    await engine.updates.close();
  });
}
