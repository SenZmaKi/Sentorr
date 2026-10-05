import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/prepared_stream.dart';
import 'package:sentorr/player/stream/torrent_playback.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  final item = PlaybackItem(
    title: ImdbTitle(id: 'tt1', title: 'Film'),
  );
  final candidate = TorrentCandidate(
    release: fakeRelease(1),
    score: 1,
    qualityScore: 1,
    availabilityScore: 1,
    sizeScore: 1,
    requiresFileSelection: false,
  );
  Future<TorrentStreamConfig> config(_) async =>
      TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path);

  test(
    'countdown preparation is handed to playback without adding again',
    () async {
      final engine = FakeStreamingEngine();
      final native = FakePlayback();
      final player = Player(platformPlayer: native);
      final prepared = PreparedStreams(
        create: (item, candidate) => PendingStream(
          item: item,
          candidate: candidate,
          engine: engine,
          configFor: config,
          fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
        ),
      );
      final playback = TorrentPlayback(
        player: player,
        engine: engine,
        prepared: prepared,
        configFor: config,
        fetchMetadata: (_, _) async => throw StateError('must reuse metadata'),
        find: (_, _) async => throw StateError('must reuse candidate'),
        outputReady: () async {},
      );
      try {
        prepared.start(item, candidate);
        await settlePlayback();
        expect(engine.sources, hasLength(1));
        expect(native.opened, isEmpty);
        await playback.play(item, torrent: candidate);
        expect(engine.sources, hasLength(1));
        expect(native.opened, hasLength(1));
      } finally {
        prepared.clear();
        await playback.close();
        playback.dispose();
        await player.dispose();
        await engine.updates.close();
      }
    },
  );

  test(
    'cancel during native metadata closes its owner and cannot revive',
    () async {
      final engine = _SlowEngine();
      final prepared = PreparedStreams(
        create: (item, candidate) => PendingStream(
          item: item,
          candidate: candidate,
          engine: engine,
          configFor: config,
          fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
        ),
      );
      prepared.start(item, candidate);
      await settlePlayback();
      expect(engine.owners, hasLength(1));
      prepared.clear();
      await settlePlayback();
      expect(engine.owners, isEmpty);
      engine.gate.complete();
      await settlePlayback();
      expect(engine.owners, isEmpty);
      expect(prepared.take(item.id, candidate.release.infoHash), isNull);
      await engine.updates.close();
    },
  );

  test(
    'playback takes an unfinished preparation; closing cancels it',
    () async {
      final engine = _SlowEngine();
      final native = FakePlayback();
      final player = Player(platformPlayer: native);
      final prepared = PreparedStreams(
        create: (item, candidate) => PendingStream(
          item: item,
          candidate: candidate,
          engine: engine,
          configFor: config,
          fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
        ),
      );
      final playback = TorrentPlayback(
        player: player,
        engine: engine,
        prepared: prepared,
        configFor: config,
        fetchMetadata: (_, _) async => throw StateError('must reuse'),
        find: (_, _) async => throw StateError('must reuse'),
        outputReady: () async {},
      );
      try {
        prepared.start(item, candidate);
        await settlePlayback();
        final playing = playback.play(item, torrent: candidate);
        await settlePlayback();
        await playback.close();
        await playing.timeout(const Duration(seconds: 2));
        expect(engine.owners, isEmpty);
        engine.gate.complete();
        await settlePlayback();
        expect(native.opened, isEmpty);
        expect(engine.sources, hasLength(1));
      } finally {
        prepared.clear();
        await playback.close();
        playback.dispose();
        await player.dispose();
        await engine.updates.close();
      }
    },
  );

  test('choosing another hash discards the speculative torrent', () async {
    final engine = FakeStreamingEngine();
    final prepared = PreparedStreams(
      create: (item, candidate) => PendingStream(
        item: item,
        candidate: candidate,
        engine: engine,
        configFor: config,
        fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
      ),
    );
    prepared.start(item, candidate);
    await settlePlayback();
    expect(prepared.take(item.id, 'different'), isNull);
    await settlePlayback();
    expect(engine.owners, isEmpty);
    prepared.clear();
    await engine.updates.close();
  });
}
