import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/torrent_playback.dart';
import 'package:sentorr/settings/streaming_settings.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';
import '../support/fake_torrents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'settings resize paused active prefetch without reopening media',
    () async {
      final native = FakePlayback();
      final player = Player(platformPlayer: native);
      final engine = FakeStreamingEngine();
      var settings = const StreamingSettings();
      final candidate = TorrentCandidate(
        release: fakeRelease(1),
        score: 1,
        qualityScore: 1,
        availabilityScore: 1,
        sizeScore: 1,
        requiresFileSelection: false,
      );
      final playback = TorrentPlayback(
        player: player,
        engine: engine,
        configFor: (_) async =>
            TorrentStreamConfig(cacheDirectory: Directory.systemTemp.path),
        find: (_, _) async => TorrentResolution(
          query: TorrentQuery(title: 'Movie'),
          candidates: [candidate],
          failures: [],
        ),
        fetchMetadata: (_, _) async => Uint8List.fromList([100, 101]),
        outputReady: () async {},
        bufferSettings: () => settings,
      );
      playback.canAutoplay = () => false;
      try {
        await playback.play(
          PlaybackItem(
            title: ImdbTitle(id: 'tt1', title: 'Movie'),
          ),
          torrent: candidate,
        );
        native.state = native.state.copyWith(
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 60),
        );
        settings = settings.copyWith(limitDownloadAhead: false);
        await playback.updateBufferSettings(settings);
        await settlePlayback();
        expect(engine.prefetched.last, (0, 1000));
        settings = settings.copyWith(
          limitDownloadAhead: true,
          downloadAheadMinutes: 2,
        );
        await playback.updateBufferSettings(settings);
        await settlePlayback();
        expect(engine.prefetched.last, (83, 117));
        expect(native.opened, hasLength(1));
        expect(native.seeks, isEmpty);
        expect(native.state.playing, isFalse);
        await playback.close();
        // Settings can change after the current session has closed as well.
        await playback.updateBufferSettings(settings);
      } finally {
        await playback.close();
        playback.dispose();
        await player.dispose();
        await engine.updates.close();
      }
    },
  );
}
