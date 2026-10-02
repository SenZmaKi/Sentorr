import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lab_controller.dart';

/// Native playback evidence; this does not certify visible frames/audio quality.
Future<void> playbackSmoke(LabController lab, List<String> arguments) async {
  String option(String key, String fallback) {
    final i = arguments.indexOf(key);
    return i >= 0 && i + 1 < arguments.length ? arguments[i + 1] : fallback;
  }

  final fixture = option('--fixture', p.absolute('fixtures/faststart.mp4'));
  final output = option(
    '--report',
    p.absolute('validation/playback.local.json'),
  );
  final checks = <String, Object?>{};
  Future<void> until(bool Function() predicate, String label) async {
    final watch = Stopwatch()..start();
    while (!predicate()) {
      if (lab.error != null) throw StateError(lab.error!);
      if (watch.elapsed > const Duration(seconds: 40)) {
        throw TimeoutException(label);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    checks[label] = watch.elapsedMilliseconds;
  }

  var passed = false;
  try {
    await lab.open(fixture, localSeed: true);
    if (lab.error != null) throw StateError(lab.error!);
    await until(
      () => lab.player.state.position > const Duration(seconds: 1),
      'playback-progress',
    );
    await until(
      () =>
          (lab.player.state.width ?? 0) > 0 &&
          (lab.player.state.height ?? 0) > 0,
      'decoded-video',
    );
    checks['width'] = lab.player.state.width;
    checks['height'] = lab.player.state.height;
    checks['durationSeconds'] = lab.player.state.duration.inSeconds;
    checks['downloadedAtFirstPlayback'] = lab.snapshot['fileBytes'];
    checks['fileSize'] = lab.snapshot['fileSize'];
    if ((checks['downloadedAtFirstPlayback'] as num) >=
        (checks['fileSize'] as num)) {
      throw StateError('File completed before first playback');
    }
    await lab.seek(const Duration(seconds: 60));
    await until(
      () => lab.player.state.position >= const Duration(milliseconds: 60500),
      'forward-seek',
    );
    await lab.seek(const Duration(seconds: 5));
    await until(
      () =>
          lab.player.state.position >= const Duration(milliseconds: 5500) &&
          lab.player.state.position < const Duration(seconds: 10),
      'backward-seek',
    );
    await lab.player.pause();
    final pausedAt = lab.player.state.position;
    await Future<void>.delayed(const Duration(seconds: 1));
    if ((lab.player.state.position - pausedAt).abs() >
        const Duration(milliseconds: 300)) {
      throw StateError('Playback advanced while paused');
    }
    checks['pause'] = true;
    await lab.player.play();
    await until(
      () =>
          lab.player.state.position >
          pausedAt + const Duration(milliseconds: 500),
      'resume',
    );
    await lab.seek(const Duration(seconds: 35));
    await lab.seek(const Duration(seconds: 70));
    await until(
      () => lab.player.state.position >= const Duration(milliseconds: 70500),
      'repeated-seeks',
    );
    passed = true;
  } catch (error, stack) {
    checks['failure'] = '$error';
    checks['stack'] = '$stack';
  } finally {
    final report = {...lab.report(), 'passed': passed, 'checks': checks};
    await lab.stop();
    await lab.shutdown();
    await File(output).parent.create(recursive: true);
    await File(output)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    exit(passed ? 0 : 1);
  }
}
