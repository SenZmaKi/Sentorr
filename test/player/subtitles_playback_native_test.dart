import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/media_kit_adapter.dart';
import 'package:sentorr/player/stream/subtitles.dart';
import 'package:torrent_stream/torrent_stream.dart';

/// Uses the production macOS libmpv without a window or audio output.
/// This exercises real MediaKit track changes over HTTP, not a fake player.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const library =
      'build/macos/Build/Products/Debug/Sentorr.app/'
      'Contents/Frameworks/Mpv.framework/Mpv';
  final available =
      Platform.isMacOS &&
      File(library).existsSync() &&
      File('tool/codec_lab/assets/media/tracks_subtitles.mkv').existsSync() &&
      File('tool/codec_lab/assets/media/captions.srt').existsSync();
  test(
    'caption toggles retain packets and sidecars reuse native tracks',
    () async {
      _loadFrameworks(File(library).absolute.parent.parent);
      MediaKit.ensureInitialized(libmpv: File(library).absolute.path);
      final video = File('tool/codec_lab/assets/media/tracks_subtitles.mkv');
      final srt = File('tool/codec_lab/assets/media/captions.srt');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ranges = <String?>[];
      final player = Player(
        configuration: const PlayerConfiguration(logLevel: MPVLogLevel.debug),
      );
      final native = player.platform as NativePlayer;
      final captions = PlaybackSubtitles(player);
      final logs = <String>[];
      final cachePauses = <bool>[];
      final logSub = player.stream.log.listen((log) => logs.add(log.text));
      final pauseSub = player.stream.buffering.listen(cachePauses.add);
      final workers = <Future<void>>[];
      Future<void> serve(HttpRequest request) async {
        final length = await video.length();
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range ?? '');
        final start = match == null ? 0 : int.parse(match[1]!);
        final end = match == null || match[2]!.isEmpty
            ? length - 1
            : int.parse(match[2]!);
        request.response.headers.set('Accept-Ranges', 'bytes');
        request.response.contentLength = end - start + 1;
        if (match != null) {
          request.response.statusCode = 206;
          request.response.headers.set(
            'Content-Range',
            'bytes $start-$end/$length',
          );
        }
        try {
          await for (final bytes in video.openRead(start, end + 1)) {
            request.response.add(bytes);
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await request.response.close();
        } on IOException {
          // Native teardown and stream replacement close outstanding requests.
        }
      }

      final requests = server.listen((request) => workers.add(serve(request)));
      Future<void> until(bool Function() ready) async {
        final clock = Stopwatch()..start();
        while (!ready()) {
          if (clock.elapsed > const Duration(seconds: 8)) {
            throw StateError('Native playback timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      Future<List<dynamic>> tracks() async =>
          jsonDecode(await native.getProperty('track-list')) as List;
      try {
        await native.setProperty('ao', 'null');
        await MediaKitTorrentAdapter(player).configure();
        await player.open(Media('http://127.0.0.1:${server.port}/video.mkv'));
        await until(
          () =>
              player.state.position > const Duration(milliseconds: 500) &&
              player.state.tracks.subtitle.length > 2,
        );
        captions.opened();
        captions.chooseTrack(captions.embedded.first);
        await until(() => captions.visible);
        final sid = await native.getProperty('sid');
        final position = player.state.position;
        final count = ranges.length;
        logs.clear();
        cachePauses.clear();
        for (var i = 0; i < 3; i++) {
          captions.off();
          expect(captions.visible, false);
          await Future<void>.delayed(const Duration(milliseconds: 80));
          captions.on();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          expect(captions.visible, true);
        }
        expect(await native.getProperty('sid'), sid);
        expect(ranges.length, count);
        expect(logs.where((line) => line.contains('refresh seek')), isEmpty);
        expect(cachePauses.where((paused) => paused), isEmpty);
        expect(player.state.position, greaterThan(position));

        final embedded = captions.embedded.first;
        captions.files = [
          SubtitleDownload(
            TorrentStreamFile(
              index: 1,
              path: 'captions.srt',
              length: await srt.length(),
              isPadFile: false,
            ),
            bytes: await srt.length(),
            path: srt.absolute.path,
          ),
        ];
        captions.chooseFile(1);
        await until(() => captions.visible);
        final importedSid = await native.getProperty('sid');
        final importedCount = (await tracks())
            .where((track) => track['type'] == 'sub')
            .length;
        captions.off();
        captions.on();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await native.getProperty('sid'), importedSid);
        captions.chooseTrack(embedded);
        await until(() => captions.visible);
        captions.chooseFile(1);
        await until(() => captions.visible);
        expect(await native.getProperty('sid'), importedSid);
        expect(
          (await tracks()).where((track) => track['type'] == 'sub').length,
          importedCount,
        );
      } finally {
        await captions.reset();
        captions.dispose();
        await player.dispose();
        await logSub.cancel();
        await pauseSub.cancel();
        await server.close(force: true);
        await requests.cancel();
        await Future.wait(workers);
      }
    },
    skip: available ? false : 'Requires the built macOS runner and bundled mpv',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

// flutter_tester does not carry the app runner's framework rpaths. Preload the
// bundled dependencies by absolute path, resolving their dependency order.
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
