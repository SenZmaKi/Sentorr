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
  final options = <StreamOptions>[];
  @override
  Future<TorrentEngineStream> stream(
    String hash,
    String owner,
    int index, {
    StreamOptions? options,
  }) {
    this.options.add(options!);
    return super.stream(hash, owner, index, options: options);
  }

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
  test('remote lease reuses the engine without warming or indexing the container twice', () async {
    final engine = _SlowEngine()..gate.complete();
    final source = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path),
    );
    final release = fakeRelease(1);
    final files = await source.open(TorrentSource.magnet(release.magnet));
    final stream = await source.prepareFile(files.single.index);
    final candidate = TorrentCandidate(
      release: release,
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
        stream,
      ),
    );
    await lease.ready;
    expect(engine.owners.length, 2);
    expect(engine.options.first.prepareContainer, true);
    expect(engine.options.first.indexMedia, true);
    expect(engine.options.last.prepareContainer, false);
    expect(engine.options.last.indexMedia, false);
    await source.close();
    expect(engine.owners.length, 1);
    await lease.close();
    expect(engine.owners, isEmpty);
    await engine.updates.close();
  });

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
