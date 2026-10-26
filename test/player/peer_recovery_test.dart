import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/peer_recovery.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/player/stream/torrent_playback.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';
import '../support/fake_torrents.dart';

Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed > const Duration(seconds: 3)) fail('Recovery timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final item = PlaybackItem(
    title: ImdbTitle(id: 'tt1', title: 'Movie'),
  );
  final candidate = TorrentCandidate(
    release: fakeRelease(7),
    score: 1,
    qualityScore: 1,
    availabilityScore: 1,
    sizeScore: 1,
    requiresFileSelection: false,
  );
  late FakePlayback native;
  late Player player;
  late FakeStreamingEngine engine;
  late TorrentPlayback playback;
  var searches = 0;
  setUp(() {
    searches = 0;
    native = FakePlayback();
    player = Player(platformPlayer: native);
    engine = FakeStreamingEngine();
    playback = TorrentPlayback(
      player: player,
      engine: engine,
      peerRecoveryPolicy: const PeerRecoveryPolicy(
        budget: Duration(milliseconds: 100),
        attemptTimeout: Duration(milliseconds: 30),
        delays: [Duration(milliseconds: 5)],
      ),
      configFor: (_) async =>
          TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path),
      fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
      find: (_, _) async {
        searches++;
        return TorrentResolution(
          query: TorrentQuery(title: 'Movie'),
          candidates: [candidate],
          failures: [],
        );
      },
      outputReady: () async {},
    );
  });
  tearDown(() async {
    await playback.close();
    playback.dispose();
    await player.dispose();
    await engine.updates.close();
  });

  Future<void> start(PeerFile peer) async {
    await playback.play(item, source: peer, start: const Duration(seconds: 42));
    playback.allowPeerRecovery();
    native.state = native.state.copyWith(
      position: const Duration(seconds: 42),
      playing: true,
      volume: 37,
      rate: 1.25,
    );
    native.emitPosition(const Duration(seconds: 42));
    await settlePlayback();
  }

  test(
    'returning peer reopens at saved position without a local torrent',
    () async {
      var probes = 0;
      final peer = PeerFile(
        Uri.parse('http://127.0.0.1/peer'),
        'MacBook',
        torrent: candidate,
        fileIndex: 0,
        available: () async => ++probes > 1,
      );
      await start(peer);
      native.onOpen = () => scheduleMicrotask(() {
        native.state = native.state.copyWith(
          position: const Duration(seconds: 43),
          duration: const Duration(minutes: 10),
        );
      });
      expect(playback.unplayable(), true);
      await until(
        () =>
            probes > 1 &&
            native.opened.length == 2 &&
            playback.status.value?.stage == StreamStage.streaming,
      );
      expect(native.opened.last.uri, peer.url.toString());
      expect(native.opened.last.start, const Duration(seconds: 42));
      expect(engine.sources, isEmpty);
      expect(searches, 0);
    },
  );

  test('permanent outage loads the exact torrent/file at saved position and retains controls', () async {
    final peer = PeerFile(
      Uri.parse('http://127.0.0.1/peer'),
      'MacBook',
      torrent: candidate,
      fileIndex: 0,
      available: () async => false,
      captionData: '1\n00:00:00,000 --> 00:02:00,000\nHello',
      captionsEnabled: true,
    );
    await start(peer);
    playback.unplayable();
    await until(
      () =>
          engine.sources.isNotEmpty &&
          playback.status.value?.stage == StreamStage.streaming,
    );
    expect(
      (engine.sources.single as TorrentMetadataSource).expectedInfoHash,
      candidate.release.infoHash,
    );
    expect(native.opened.last.start, const Duration(seconds: 42));
    expect(native.state.volume, 37);
    expect(native.state.rate, 1.25);
    expect(playback.subtitles.embeddedTrack?.id, contains('Hello'));
    expect(playback.subtitles.enabled, true);
    expect(searches, 0);
  });

  test(
    'a delayed pre-seek position cannot overwrite the recovery target',
    () async {
      await start(
        PeerFile(
          Uri.parse('http://127.0.0.1/peer'),
          'MacBook',
          torrent: candidate,
          fileIndex: 0,
          available: () async => false,
        ),
      );
      await playback.seek(const Duration(seconds: 180));
      native.emitPosition(const Duration(seconds: 42));
      await settlePlayback();
      expect(playback.resumePosition, const Duration(seconds: 180));
      playback.unplayable();
      await until(
        () =>
            engine.sources.isNotEmpty &&
            playback.status.value?.stage == StreamStage.streaming,
      );
      expect(native.opened.last.start, const Duration(seconds: 180));
    },
  );

  test(
    'recovery respects a local pause and captions turned off after handoff',
    () async {
      await start(
        PeerFile(
          Uri.parse('http://127.0.0.1/peer'),
          'MacBook',
          torrent: candidate,
          fileIndex: 0,
          available: () async => false,
          captionData: '1\n00:00:00,000 --> 00:02:00,000\nHello',
          captionsEnabled: true,
        ),
      );
      playback.subtitles.off();
      native.state = native.state.copyWith(playing: false);
      native.emitPlaying(false);
      await settlePlayback();
      playback.unplayable();
      await until(
        () =>
            engine.sources.isNotEmpty &&
            playback.status.value?.stage == StreamStage.streaming,
      );
      expect(native.state.playing, false);
      expect(playback.subtitles.enabled, false);
    },
  );

  test(
    'replacement item cancels a late reconnect and prevents torrent fallback',
    () async {
      final probe = Completer<bool>();
      final entered = Completer<void>();
      await start(
        PeerFile(
          Uri.parse('http://127.0.0.1/peer'),
          'MacBook',
          torrent: candidate,
          fileIndex: 0,
          available: () {
            if (!entered.isCompleted) entered.complete();
            return probe.future;
          },
        ),
      );
      playback.unplayable();
      await entered.future;
      final next = PlaybackItem(
        title: ImdbTitle(id: 'tt2', title: 'Next'),
      );
      await playback.play(
        next,
        source: PeerFile(Uri.parse('http://127.0.0.1/next'), 'Other'),
      );
      probe.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(playback.item!.id, 'tt2');
      expect(native.opened.last.uri, 'http://127.0.0.1/next');
      expect(engine.sources, isEmpty);
    },
  );

  test(
    'a hung recovery attempt cannot escape the overall retry budget',
    () async {
      var attempts = 0;
      final clock = Stopwatch()..start();
      final recovered =
          await const PeerRecoveryPolicy(
            budget: Duration(milliseconds: 80),
            attemptTimeout: Duration(milliseconds: 20),
            delays: [Duration(milliseconds: 1)],
          ).run(
            attempt: (_) {
              attempts++;
              return Completer<bool>().future;
            },
            current: () => true,
            wait: (d) => Future<void>.delayed(d),
          );
      expect(recovered, false);
      expect(attempts, greaterThan(1));
      expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );

  test(
    'watchdog detects silent stalls but ignores pauses and resets on progress',
    () async {
      var position = Duration.zero;
      var playing = false;
      var recoveries = 0;
      final source = Object();
      final watchdog = PeerStallWatchdog(
        grace: const Duration(milliseconds: 30),
        interval: const Duration(milliseconds: 5),
        recover: () => recoveries++,
        sample: () => (
          source: source,
          position: position,
          playing: playing,
          completed: false,
        ),
      );
      addTearDown(watchdog.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(recoveries, 0);
      playing = true;
      await until(() => recoveries == 1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(recoveries, 1);
      position = const Duration(seconds: 1);
      await until(() => recoveries == 2);
    },
  );
}
