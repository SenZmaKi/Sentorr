// Opt-in native performance audit; run with SENTORR_PREVIEW_AUDIT=1.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/preview/extractor.dart';

Future<double> cpuSeconds() async {
  final sample = await Process.run('ps', ['-p', '$pid', '-o', 'time=']);
  final parts = (sample.stdout as String).trim().split(':');
  return double.parse(parts[0]) * 60 + double.parse(parts[1]);
}

final auditMode = Platform.environment['SENTORR_PREVIEW_MODE'] == 'exact'
    ? PreviewSeekMode.exact
    : PreviewSeekMode.keyframe;

final auditPrefix =
    Platform.environment['SENTORR_AUDIT_OUTPUT_PREFIX'] ?? auditMode.name;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native preview extraction audit',
    () async {
      MediaKit.ensureInitialized(
        libmpv:
            Platform.environment['SENTORR_AUDIT_LIBMPV'] ??
            '/opt/homebrew/lib/libmpv.dylib',
      );
      final results = <Map<String, Object?>>[];
      for (final name in [
        'bbb_h264.mp4',
        'bbb_h265.mp4',
        'bbb_av1.mp4',
        'hevc_4k60.mkv',
      ]) {
        final file = File('tool/codec_lab/assets/media/$name').absolute;
        if (!file.existsSync()) continue;
        final extractor = PreviewExtractor(mode: auditMode);
        try {
          for (final second in [1, 5, 8, 2, 6]) {
            final watch = Stopwatch()..start();
            final bytes = await extractor
                .extract(file.uri.toString(), Duration(seconds: second))
                .timeout(const Duration(seconds: 5));
            if (bytes == null) {
              results.add({
                'file': name,
                'second': second,
                'ms': watch.elapsedMilliseconds,
                'failed': true,
                'rss': ProcessInfo.currentRss,
              });
              await extractor.dispose();
              continue;
            }
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            expect(frame.image.width, inInclusiveRange(1, 240));
            expect(frame.image.height, inInclusiveRange(1, 136));
            expect(frame.image.width, extractor.timings['targetWidth']);
            expect(frame.image.height, extractor.timings['targetHeight']);
            results.add({
              'file': name,
              'second': second,
              'ms': watch.elapsedMilliseconds,
              'bytes': bytes.length,
              'frameSecond': extractor.framePosition!.inMilliseconds / 1000,
              'sha256': sha256.convert(bytes).toString(),
              'width': frame.image.width,
              'height': frame.image.height,
              'rss': ProcessInfo.currentRss,
            });
            frame.image.dispose();
            codec.dispose();
          }
        } finally {
          await extractor.dispose();
        }
      }
      if (auditMode == PreviewSeekMode.keyframe) {
        // Changing targets may legitimately reuse a keyframe. However, when
        // the decoded timestamp changes these moving fixtures must change too.
        for (final name in ['bbb_h264.mp4', 'hevc_4k60.mkv']) {
          final rows = results.where(
            (row) => row['file'] == name && row['bytes'] != null,
          );
          final positions = rows.map((row) => row['frameSecond']).toSet();
          expect(positions.length, greaterThan(1), reason: name);
          expect(
            rows.map((row) => row['sha256']).toSet().length,
            positions.length,
            reason: name,
          );
        }
      }
      expect(results.any((row) => row['bytes'] != null), isTrue);
      final output = File(
        'tool/preview_audit/${auditPrefix}_native_results.json',
      );
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(results),
      );
    },
    skip: Platform.environment['SENTORR_PREVIEW_AUDIT'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'headless playback CPU comparison',
    () async {
      MediaKit.ensureInitialized(
        libmpv:
            Platform.environment['SENTORR_AUDIT_LIBMPV'] ??
            '/opt/homebrew/lib/libmpv.dylib',
      );
      final results = <Map<String, Object?>>[];
      for (final file in ['bbb_h264.mp4', 'hevc_4k60.mkv']) {
        for (final previews in [false, true]) {
          final player = Player();
          final extractor = PreviewExtractor(mode: auditMode);
          final native = player.platform as NativePlayer;
          try {
            for (final entry in {
              'vo': 'null',
              'vid': 'auto',
              'audio': 'no',
              'hwdec': 'no',
              'loop-file': 'inf',
            }.entries) {
              await native.setProperty(entry.key, entry.value);
            }
            final uri = File('tool/codec_lab/assets/media/$file').absolute.uri
                .toString();
            await player.open(Media(uri));
            await Future<void>.delayed(const Duration(seconds: 1));
            final cpu = await cpuSeconds();
            final rss = ProcessInfo.currentRss;
            final watch = Stopwatch()..start();
            var attempts = 0, successes = 0;
            while (watch.elapsed < const Duration(seconds: 5)) {
              if (previews) {
                attempts++;
                final bytes = await extractor
                    .extract(uri, Duration(seconds: attempts % 8))
                    .timeout(const Duration(seconds: 4), onTimeout: () => null);
                if (bytes != null) {
                  successes++;
                } else {
                  await extractor.dispose();
                }
              }
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
            results.add({
              'file': file,
              'previews': previews,
              'wallMs': watch.elapsedMilliseconds,
              'cpuSeconds': await cpuSeconds() - cpu,
              'rssStart': rss,
              'rssEnd': ProcessInfo.currentRss,
              'attempts': attempts,
              'successes': successes,
              'position': await native.getProperty('time-pos'),
            });
          } finally {
            await extractor.dispose();
            await player.dispose();
          }
        }
      }
      File(
        'tool/preview_audit/${auditPrefix}_playback_results.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
    },
    skip: Platform.environment['SENTORR_PREVIEW_AUDIT'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
