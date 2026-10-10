import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/buffering.dart';
import 'package:sentorr/player/stream/media_kit_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = File(
    'build/macos/Build/Products/Debug/Sentorr.app/Contents/Frameworks/Mpv.framework/Mpv',
  );
  final video = File('tool/codec_lab/assets/media/tracks_subtitles.mkv');
  test(
    'native stalled paused seek remains buffering until bytes arrive',
    () async {
      _loadFrameworks(library.absolute.parent.parent);
      MediaKit.ensureInitialized(libmpv: library.absolute.path);
      final player = Player();
      final native = player.platform as NativePlayer;
      final buffering = PlaybackBuffering();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Completer<void>? gate;
      final workers = <Future<void>>[];
      var blockedRequests = 0;
      Future<void> serve(HttpRequest request) async {
        final length = await video.length();
        final match = RegExp(r'bytes=(\d+)-(\d*)')
            .firstMatch(request.headers.value('Range') ?? '');
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
            if (gate case final wait?) {
              blockedRequests++;
              await wait.future;
            }
            request.response.add(bytes);
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await request.response.close();
        } on IOException {
          /* Seeks cancel old HTTP reads. */
        }
      }

      final requests = server.listen((request) => workers.add(serve(request)));
      Future<void> until(bool Function() ready) async {
        final clock = Stopwatch()..start();
        while (!ready()) {
          if (clock.elapsed > const Duration(seconds: 10)) {
            throw StateError(
              'Native buffering check timed out: position=${player.state.position} playing=${player.state.playing} buffering=${buffering.value}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      try {
        await native.setProperty('ao', 'null');

        await MediaKitTorrentAdapter(player).configure();
        await native.setProperty('demuxer-max-bytes', '2097152');
        await native.setProperty('cache-pause-wait', '0.1');
        await native.setProperty('demuxer-max-back-bytes', '0');
        await buffering.attach(player);
        await player.open(Media('http://127.0.0.1:${server.port}/video.mkv'));
        await until(() => player.state.position.inMilliseconds >= 500);
        await player.pause();
        await until(() => !player.state.playing && !buffering.value);
        gate = Completer<void>();
        buffering.beginSeek();
        await player.seek(const Duration(seconds: 8));
        buffering.seekIssued();
        await until(() => blockedRequests > 0 && buffering.value);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(buffering.value, true);
        expect(player.state.playing, false);
        gate.complete();
        gate = null;
        await until(() => !buffering.value);
        expect(player.state.position.inSeconds, greaterThanOrEqualTo(7));
      } finally {
        if (gate != null && !gate.isCompleted) gate.complete();
        await buffering.close();
        await player.dispose();
        await requests.cancel();
        await server.close(force: true);
        await Future.wait(workers)
            .timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: !Platform.isMacOS || !library.existsSync() || !video.existsSync(),
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
