import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:sentorr/player/stream/subtitles.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart';
import '../support/fake_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native stream downloads a bundled SRT while the video stays partial',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-subtitles-');
      final source = await Directory('${root.path}/seed/Film')
          .create(recursive: true);
      await File('${source.path}/Film.mkv')
          .writeAsBytes(List.generate(4 * 1024 * 1024, (i) => i % 251));
      const text = '1\n00:00:00,000 --> 00:00:30,000\nBundled captions\n';
      await File('${source.path}/Film.en.srt').writeAsString(text);
      final metadata = createTorrentData(
        sourcePath: source.path,
        pieceSize: 64 * 1024,
      );
      final seed = createSessionFromTags([
        LibtorrentTagItem.settingsString(
          LibtorrentSettingsTag.listenInterfaces,
          '127.0.0.1:0',
        ),
        for (final tag in [
          LibtorrentSettingsTag.enableDht,
          LibtorrentSettingsTag.enableLsd,
          LibtorrentSettingsTag.enableUpnp,
          LibtorrentSettingsTag.enableNatpmp,
          LibtorrentSettingsTag.enableOutgoingUtp,
          LibtorrentSettingsTag.enableIncomingUtp,
        ])
          LibtorrentTagItem.settingsBool(tag, false),
      ]);
      final engine = loopbackEngine();
      final session = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(cacheDirectory: '${root.path}/cache'),
      );
      final player = Player(platformPlayer: _CaptionPlayer());
      final captions = PlaybackSubtitles(player);
      try {
        final handle = seed.addTorrentData(
          torrentData: metadata,
          savePath: source.parent.path,
        );
        handle.unsetFlags(
          LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
        );
        final watch = Stopwatch()..start();
        while (handle.getStatus().state != 5 || seed.listenPort == 0) {
          if (watch.elapsed > const Duration(seconds: 15)) {
            throw StateError('Seed not ready');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final files = await session.open(
          TorrentSource.metadata(metadata),
          peers: [TorrentPeer('127.0.0.1', seed.listenPort)],
        );
        final video = files.singleWhere((f) => f.path.endsWith('.mkv'));
        final sidecar = files.singleWhere((f) => f.path.endsWith('.srt'));
        await session.prepareFile(video.index);
        captions.watch(session, [sidecar]);
        captions.opened();
        captions.on();
        final complete = await until(
          engine,
          session.infoHash!,
          (t) => t.bytesOf(sidecar.index) == sidecar.length,
        );
        // Completion must describe real readable bytes, not merely selection.
        expect(
          await File(p.join(complete.savePath, sidecar.path)).readAsString(),
          text,
        );
        expect(complete.bytesOf(video.index), lessThan(video.length));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(captions.selected!.ready, true);
        expect(player.state.track.subtitle.uri, true);
        expect(
          player.state.track.subtitle.id,
          p.join(complete.savePath, sidecar.path),
        );
      } finally {
        await captions.reset();
        captions.dispose();
        await session.close();
        await engine.close();
        await player.dispose();
        seed.close();
        await root.delete(recursive: true);
      }
    },
  );
}

class _CaptionPlayer extends FakePlayback {
  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
  }
}
