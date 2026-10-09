import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/player/stream/parked_stream.dart';
import 'package:sentorr/player/stream/torrent_playback.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';
import '../support/fake_torrents.dart';

TorrentCandidate _candidate(int id) => TorrentCandidate(
  release: fakeRelease(id),
  score: 1,
  qualityScore: 1,
  availabilityScore: 1,
  sizeScore: 1,
  requiresFileSelection: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final item = PlaybackItem(
    title: ImdbTitle(id: 'tt1', title: 'Movie'),
  );
  final next = PlaybackItem(
    title: ImdbTitle(id: 'tt2', title: 'Next movie'),
  );
  final first = _candidate(1), second = _candidate(2);
  late FakePlayback native;
  late Player player;
  late FakeStreamingEngine engine;
  late ParkedStreams parked;
  late TorrentPlayback playback;
  OfflineSource? saved;
  Future<void> Function() ready = () async {};
  bool failSecond = false;

  setUp(() {
    native = FakePlayback();
    player = Player(platformPlayer: native);
    engine = FakeStreamingEngine();
    parked = ParkedStreams();
    saved = null;
    ready = () async {};
    failSecond = false;
    playback = TorrentPlayback(
      player: player,
      engine: engine,
      fetchMetadata: (release, cancel) async => Uint8List.fromList([100, 101]),
      parked: parked,
      configFor: (release) async {
        if (failSecond && release.infoHash == second.release.infoHash) {
          throw StateError('replacement failed');
        }
        return TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path);
      },
      find: (_, _) async => TorrentResolution(
        query: TorrentQuery(title: 'Movie'),
        candidates: [first, second],
        failures: [],
      ),
      outputReady: () => ready(),
      offline: (_) => saved,
    );
  });
  tearDown(() async {
    await playback.close();
    playback.dispose();
    await player.dispose();
    await engine.updates.close();
  });

  test(
    'the streamed item changes only once the previous one stopped',
    () async {
      await playback.play(item, torrent: first);
      PlaybackItem? stopping;
      native.onStop = () => stopping = playback.item;
      await playback.play(next, torrent: second);
      expect(stopping, item);
      expect(playback.item, next);
    },
  );

  test('focus loss during torrent loading opens media paused', () async {
    final renderer = Completer<void>();
    var foreground = true;
    ready = () => renderer.future;
    playback.canAutoplay = () => foreground;
    final loading = playback.play(item, torrent: first);
    await settlePlayback();
    foreground = false;
    renderer.complete();
    await loading;
    expect(native.opened, hasLength(1));
    expect(native.state.playing, isFalse);
    expect(playback.status.value!.stage, StreamStage.streaming);
  });

  test('returning before loading finishes allows autoplay', () async {
    final renderer = Completer<void>();
    var foreground = false;
    ready = () => renderer.future;
    playback.canAutoplay = () => foreground;
    final loading = playback.play(item, torrent: first);
    await settlePlayback();
    foreground = true;
    renderer.complete();
    await loading;
    expect(native.state.playing, isTrue);
  });

  test(
    'partial peer playback does not claim a complete downloaded timeline',
    () async {
      saved = PeerFile(
        Uri.parse('http://127.0.0.1/video'),
        'Other device',
        buffered: true,
      );
      await playback.play(item);
      final status = playback.status.value!;
      expect(status.stage, StreamStage.streaming);
      expect(status.peer, 'Other device');
      expect(status.localFile, isNull);
      expect(status.hasDownloadedTimeline, isFalse);
    },
  );

  test('peer media also respects focus loss during loading', () async {
    final renderer = Completer<void>();
    ready = () => renderer.future;
    saved = PeerFile(Uri.parse('http://127.0.0.1/video'), 'Other device');
    playback.canAutoplay = () => false;
    final loading = playback.play(item);
    await settlePlayback();
    renderer.complete();
    await loading;
    expect(native.opened, hasLength(1));
    expect(native.state.playing, isFalse);
  });

  test(
    'HTTP metadata is added before renderer readiness; media waits',
    () async {
      final renderer = Completer<void>();
      ready = () => renderer.future;
      final playing = playback.play(item, torrent: first);
      await settlePlayback();
      expect(engine.sources.single, isA<TorrentMetadataSource>());
      expect(engine.owners, hasLength(1));
      expect(native.opened, isEmpty);
      renderer.complete();
      await playing;
      expect(native.opened, hasLength(1));
    },
  );

  test(
    'closing while renderer is pending releases prepared metadata session',
    () async {
      final renderer = Completer<void>();
      ready = () => renderer.future;
      final playing = playback.play(item, torrent: first);
      await settlePlayback();
      expect(engine.owners, hasLength(1));
      await playback.close();
      await playing.timeout(const Duration(seconds: 2));
      expect(engine.owners, isEmpty);
      expect(native.opened, isEmpty);
      renderer.complete();
    },
  );

  test('delayed seek cannot reach replacement playback', () async {
    await playback.play(item, torrent: first);
    engine.seekGate = Completer<void>();
    final seeking = playback.seek(const Duration(seconds: 80));
    await settlePlayback();
    await playback.play(next, torrent: second);
    engine.seekGate!.complete();
    await seeking;
    expect(native.seeks, isEmpty);
    expect(playback.status.value!.torrent, second);
  });

  for (final fails in [false, true]) {
    test(
      'superseded parked resume ${fails ? 'failure' : 'completion'} cannot affect new session',
      () async {
        await playback.play(item, torrent: first);
        await playback.park();
        engine.resumeGate = Completer<void>();
        final resuming = playback.play(item, torrent: first);
        await settlePlayback();
        await playback.play(next, torrent: second);
        if (fails) {
          engine.resumeGate!.completeError(StateError('late resume failure'));
        } else {
          engine.resumeGate!.complete();
        }
        await resuming;
        expect(playback.status.value!.torrent, second);
        expect(playback.status.value!.stage, StreamStage.streaming);
        expect(native.opened, hasLength(2));
        expect(engine.owners.values.single, contains(second.release.infoHash));
      },
    );
  }

  test(
    'failed parked resume releases its session before fresh playback',
    () async {
      await playback.play(item, torrent: first);
      await playback.park();
      engine.resumeGate = Completer<void>();
      final resuming = playback.play(item, torrent: first);
      await settlePlayback();
      engine.resumeGate!.completeError(StateError('resume failed'));
      await resuming;
      expect(playback.status.value!.stage, StreamStage.streaming);
      expect(engine.owners, hasLength(1));
      expect(engine.released, hasLength(1));
    },
  );

  test(
    'stop and release failures do not block another play or skip release',
    () async {
      await playback.play(item, torrent: first);
      native.failStop = true;
      engine.failRelease = true;
      await playback.play(next, torrent: second);
      expect(engine.released, hasLength(1));
      expect(playback.status.value!.stage, StreamStage.streaming);
      expect(playback.status.value!.torrent, second);
      expect(native.opened, hasLength(2));
    },
  );

  test('local playback observes seeding without acquiring a torrent', () async {
    final dir = Directory.systemTemp.createTempSync('player_seed_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/movie.mkv')..createSync();
    final transfers = StreamController<TorrentStreamState>.broadcast();
    addTearDown(transfers.close);
    saved = LocalFile(file.path, transfers: transfers.stream);
    await playback.play(item);
    transfers.add(
      const TorrentStreamState(uploadBytesPerSecond: 4096, peers: 2),
    );
    await settlePlayback();
    expect(playback.status.value!.localFile, file.path);
    expect(playback.status.value!.transfer.uploadBytesPerSecond, 4096);
    expect(engine.owners, isEmpty);
    await playback.close();
    expect(transfers.hasListener, isFalse);
    saved = null;
    await playback.play(next, torrent: second);
    transfers.add(const TorrentStreamState(uploadBytesPerSecond: 999));
    await settlePlayback();
    expect(playback.status.value!.localFile, isNull);
    expect(playback.status.value!.transfer.uploadBytesPerSecond, isNot(999));
  });

  for (final local in [false, true]) {
    for (final renderer in [false, true]) {
      test(
        '${local ? 'local' : 'peer'} ${renderer ? 'renderer' : 'open'} exception becomes a playback failure',
        () async {
          if (local) {
            final dir = Directory.systemTemp.createTempSync('player_test');
            addTearDown(() => dir.deleteSync(recursive: true));
            final file = File('${dir.path}/movie.mkv')..createSync();
            saved = LocalFile(file.path);
          } else {
            saved = PeerFile(Uri.parse('http://127.0.0.1/movie'), 'Peer');
          }
          if (renderer) {
            ready = () async => throw StateError('renderer failed');
          } else {
            native.failOpen = true;
          }
          await playback.play(item);
          expect(playback.status.value!.stage, StreamStage.failed);
          expect(playback.status.value!.problem, isNotEmpty);
        },
      );
    }
  }

  test(
    'error during native open cannot be overwritten by streaming success',
    () async {
      native.onOpen = () => playback.unplayable();
      await playback.play(item, torrent: first);
      await settlePlayback();
      expect(playback.status.value!.stage, StreamStage.failed);
      expect(engine.owners, isEmpty);
    },
  );

  test('fallback preserves position of a failed manual replacement', () async {
    final options = TorrentResolution(
      query: TorrentQuery(title: 'Movie'),
      candidates: [first, second],
      failures: [],
    );
    await playback.play(
      item,
      torrent: first,
      options: options,
      start: const Duration(seconds: 10),
    );
    native.state = native.state.copyWith(position: const Duration(seconds: 80));
    failSecond = true;
    await playback.switchTo(second);
    expect(playback.status.value!.stage, StreamStage.switching);
    playback.switchNow();
    await settlePlayback();
    expect(playback.status.value!.stage, StreamStage.streaming);
    expect(native.opened.last.start, const Duration(seconds: 80));
  });

  test('fatal playback error recovers even when duration is known', () async {
    await playback.play(item, torrent: first);
    native.state = native.state.copyWith(
      playing: false,
      duration: const Duration(minutes: 90),
    );
    native.emitError('playback stopped');
    await settlePlayback();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(playback.status.value!.stage, StreamStage.failed);
  });

  test('recoverable decoder errors leave progressing playback alone', () async {
    await playback.play(item, torrent: first);
    native.emitError('audio decoder unavailable');
    await settlePlayback();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(playback.status.value!.stage, StreamStage.streaming);
  });

  test('delayed error inspection cannot fail a replacement item', () async {
    await playback.play(item, torrent: first);
    native.emitError('old playback error');
    await settlePlayback();
    await playback.play(next, torrent: second);
    native.state = native.state.copyWith(playing: false);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(playback.status.value!.stage, StreamStage.streaming);
    expect(playback.status.value!.torrent, second);
  });
}
