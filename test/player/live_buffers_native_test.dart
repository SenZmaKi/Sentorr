import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/media_kit_adapter.dart';
import 'package:sentorr/settings/streaming_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = File(
    'build/macos/Build/Products/Debug/Sentorr.app/Contents/Frameworks/Mpv.framework/Mpv',
  );
  test(
    'native buffer edits apply in order to an open paused player',
    () async {
      _loadFrameworks(library.absolute.parent.parent);
      MediaKit.ensureInitialized(libmpv: library.absolute.path);
      final player = Player();
      final native = player.platform as NativePlayer;
      var settings = const StreamingSettings();
      final adapter = MediaKitTorrentAdapter(player, settings: () => settings);
      try {
        await native.setProperty('ao', 'null');
        await native.setProperty('vo', 'null');
        await adapter.configure();
        await player.open(
          Media(
            File('tool/codec_lab/assets/media/tracks_subtitles.mkv')
                .absolute
                .uri
                .toString(),
          ),
          play: false,
        );
        settings = settings.copyWith(
          playbackResumeBufferSeconds: 8,
          playerForwardBufferMiB: 16,
          playerBackwardBufferMiB: 4,
        );
        final first = adapter.updateBuffers();
        settings = settings.copyWith(
          playbackResumeBufferSeconds: 3,
          playerForwardBufferMiB: 24,
          playerBackwardBufferMiB: 0,
        );
        final second = adapter.updateBuffers();
        await Future.wait([first, second]);
        expect(double.parse(await native.getProperty('cache-pause-wait')), 3);
        expect(
          int.parse(await native.getProperty('demuxer-max-bytes')),
          24 * 1024 * 1024,
        );
        expect(
          int.parse(await native.getProperty('demuxer-max-back-bytes')),
          0,
        );
        expect(player.state.playing, isFalse);
      } finally {
        await player.dispose();
      }
    },
    skip:
        !Platform.isMacOS ||
        !library.existsSync() ||
        !File('tool/codec_lab/assets/media/tracks_subtitles.mkv').existsSync(),
  );
}

void _loadFrameworks(Directory directory) {
  const dependencies = {
    'Mpv',
    'Ass',
    'Avcodec',
    'Avfilter',
    'Avformat',
    'Avutil',
    'Swresample',
    'Swscale',
    'Uchardet',
    'Dav1d',
    'Freetype',
    'Fribidi',
    'Harfbuzz',
    'Png16',
    'Mbedcrypto',
    'Mbedtls',
    'Mbedx509',
    'Xml2',
  };
  final pending = directory
      .listSync()
      .whereType<Directory>()
      .where(
        (entry) =>
            dependencies.any((name) => entry.path.endsWith('/$name.framework')),
      )
      .map((entry) {
        final name = entry.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last;
        return '${entry.path}/${name.substring(0, name.length - '.framework'.length)}';
      })
      .toList();
  while (pending.isNotEmpty) {
    final before = pending.length;
    pending.removeWhere((path) {
      try {
        DynamicLibrary.open(path);
        return true;
      } on Object {
        return false;
      }
    });
    if (before == pending.length) break;
  }
}
