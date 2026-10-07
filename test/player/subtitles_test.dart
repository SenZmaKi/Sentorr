import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/subtitles.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';

class CaptionPlayer extends FakePlayback {
  final selected = <SubtitleTrack>[];
  Completer<void>? gate;
  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    selected.add(track);
    await gate?.future;
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
  }
}

class CaptionEngine extends FakeStreamingEngine {
  Set<int> wanted = {};
  @override
  Future<void> want(String infoHash, String owner, Set<int> files) async {
    wanted = files;
  }
}

const file = TorrentStreamFile(
  index: 1,
  path: 'Movie.en.srt',
  length: 100,
  isPadFile: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CaptionPlayer native;
  late Player player;
  late CaptionEngine engine;
  late TorrentStreamSession session;
  late PlaybackSubtitles captions;
  setUp(() async {
    native = CaptionPlayer();
    player = Player(platformPlayer: native);
    engine = CaptionEngine();
    session = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(cacheDirectory: '/tmp'),
    );
    await session.open(
      TorrentSource.metadata(
        Uint8List.fromList([1]),
        expectedInfoHash: '0123456789012345678901234567890123456789',
      ),
    );
    captions = PlaybackSubtitles(player);
    captions.watch(session, [file]);
    captions.opened();
    await settlePlayback();
  });
  tearDown(() async {
    await captions.reset();
    captions.dispose();
    await session.close();
    await player.dispose();
    await engine.updates.close();
  });
  Future<void> progress(int bytes, {String path = 'Movie.en.srt'}) async {
    engine.updates.add([
      TorrentSnapshot(
        infoHash: '0123456789012345678901234567890123456789',
        savePath: '/tmp/movie',
        storage: TorrentStorage.temporary,
        fileBytes: [0, bytes],
      ),
    ]);
    await settlePlayback();
  }

  test(
    'downloads sidecars and automatically attaches only when verified complete',
    () async {
      expect(engine.wanted, {1});
      captions.on();
      await progress(50);
      expect(captions.enabled, true);
      expect(captions.status, 'Downloading 50%');
      expect(native.selected.where((t) => t.uri), isEmpty);
      await progress(100);
      expect(captions.status, 'Ready');
      expect(native.selected.last.id, '/tmp/movie/Movie.en.srt');
      expect(native.selected.last.uri, true);
      await progress(100);
      expect(native.selected.where((t) => t.uri), hasLength(1));
    },
  );
  test('Off during download prevents late automatic activation', () async {
    captions.chooseFile(1);
    await progress(25);
    captions.off();
    await progress(100);
    expect(native.selected.where((t) => t.uri), isEmpty);
    expect(captions.enabled, false);
    captions.on();
    await settlePlayback();
    expect(native.selected.last.uri, true);
  });
  test('item reset ignores old progress and retains captions intent', () async {
    captions.on();
    await captions.reset();
    await progress(100);
    expect(captions.files, isEmpty);
    expect(captions.enabled, true);
    expect(native.selected.where((t) => t.uri), isEmpty);
  });
  test('Off wins when native attachment is already in flight', () async {
    captions.on();
    native.gate = Completer<void>();
    await progress(100);
    captions.off();
    native.gate!.complete();
    await settlePlayback();
    expect(native.selected.last.id, 'no');
  });
  test('completion of an unselected sidecar does not activate it', () async {
    await captions.reset();
    const second = TorrentStreamFile(
      index: 2,
      path: 'Movie.fr.srt',
      length: 100,
      isPadFile: false,
    );
    captions.watch(session, [file, second]);
    captions.opened();
    captions.chooseFile(2);
    engine.updates.add([
      const TorrentSnapshot(
        infoHash: '0123456789012345678901234567890123456789',
        savePath: '/tmp/movie',
        storage: TorrentStorage.temporary,
        fileBytes: [0, 100, 50],
      ),
    ]);
    await settlePlayback();
    expect(captions.status, 'Downloading 50%');
    expect(native.selected.where((t) => t.uri), isEmpty);
    engine.updates.add([
      const TorrentSnapshot(
        infoHash: '0123456789012345678901234567890123456789',
        savePath: '/tmp/movie',
        storage: TorrentStorage.temporary,
        fileBytes: [0, 100, 100],
      ),
    ]);
    await settlePlayback();
    expect(native.selected.last.id, '/tmp/movie/Movie.fr.srt');
  });
  test('unsafe sidecar paths are unavailable and never attached', () async {
    await captions.reset();
    const unsafe = TorrentStreamFile(
      index: 1,
      path: '../../outside.srt',
      length: 100,
      isPadFile: false,
    );
    captions.watch(session, [unsafe]);
    captions.opened();
    captions.on();
    await progress(100);
    expect(captions.status, 'Unavailable');
    expect(native.selected.where((t) => t.uri), isEmpty);
  });
  test('imported native tracks do not duplicate sidecar picker rows', () async {
    native.state = native.state.copyWith(
      tracks: const Tracks(subtitle: [SubtitleTrack('1', 'Movie.en', 'en')]),
    );
    captions.chooseFile(1);
    await progress(100);
    native.state = native.state.copyWith(
      tracks: const Tracks(
        subtitle: [
          SubtitleTrack('1', 'Movie.en', 'en'),
          SubtitleTrack('2', 'Movie.en', 'en'),
        ],
      ),
    );
    expect(captions.embedded.map((t) => t.id), ['1']);
  });
  test('finished downloads remain off until captions are requested', () async {
    await progress(100);
    expect(captions.files.single.ready, true);
    expect(native.selected.where((t) => t.uri), isEmpty);
  });
}
