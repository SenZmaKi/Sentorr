import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lab_controller.dart';

/// Bounded external-swarm probe. Timings require playback progression.
Future<void> performanceAudit(LabController lab, List<String> arguments) async {
  String option(String key) => arguments[arguments.indexOf(key) + 1];
  final watch = Stopwatch()..start();
  final samples = <Map<String, Object?>>[];
  final checks = <String, Object?>{};
  var phase = 'metadata';
  final sampler = Timer.periodic(const Duration(seconds: 1), (_) {
    samples.add({
      'elapsedMs': watch.elapsedMilliseconds,
      'phase': phase,
      ...lab.snapshot,
      'positionMs': lab.player.state.position.inMilliseconds,
      'buffering': lab.player.state.buffering,
      'cacheWaiting': lab.monitor.waiting,
      'cachedSeconds': lab.monitor.cachedSeconds,
    });
  });
  Future<void> until(bool Function() condition, int seconds) async {
    final limit = Stopwatch()..start();
    while (!condition()) {
      if (lab.error != null) throw StateError(lab.error!);
      if (limit.elapsed.inSeconds >= seconds) {
        throw TimeoutException('$phase after ${seconds}s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  var passed = false;
  try {
    if (arguments.contains('--idle')) {
      phase = 'idle';
      await Future<void>.delayed(const Duration(seconds: 60));
      passed = true;
      return;
    }
    await lab.open(
      option('--source'),
      localSeed: arguments.contains('--controlled'),
    );
    checks['muted'] = lab.muted;

    if (lab.error != null) throw StateError(lab.error!);
    checks['metadataMs'] = watch.elapsedMilliseconds;
    phase = 'startup';
    final startup = Stopwatch()..start();
    await lab.playSelected().timeout(const Duration(seconds: 70));
    await until(() => lab.player.state.position.inMilliseconds > 1000, 60);
    checks['startupMs'] = startup.elapsedMilliseconds;
    checks['firstPlaybackMs'] = watch.elapsedMilliseconds;
    checks['volume'] = lab.player.state.volume;
    if (lab.muted && lab.player.state.volume != 0) {
      throw StateError('Muted player has nonzero volume');
    }
    checks['bytesAtFirstPlayback'] = lab.snapshot['fileBytes'];
    checks['width'] = lab.player.state.width;
    checks['height'] = lab.player.state.height;
    phase = 'sustained';
    final sustainedSeconds =
        int.tryParse(
          Platform.environment['STREAMING_SUSTAINED_SECONDS'] ?? '',
        ) ??
        30;
    checks['sustainedStartMs'] = watch.elapsedMilliseconds;
    checks['sustainedStartPositionMs'] =
        lab.player.state.position.inMilliseconds;
    await Future<void>.delayed(Duration(seconds: sustainedSeconds));
    checks['sustainedEndMs'] = watch.elapsedMilliseconds;
    checks['sustainedEndPositionMs'] = lab.player.state.position.inMilliseconds;
    checks['sustainedSeconds'] = sustainedSeconds;
    final duration = lab.player.state.duration.inMilliseconds;
    for (final fraction in [0.5, 0.9, 0.05]) {
      phase = 'seek-$fraction';
      final target = (duration * fraction).round();
      final seek = Stopwatch()..start();
      checks['${phase}FromPositionMs'] =
          lab.player.state.position.inMilliseconds;
      await lab.seek(Duration(milliseconds: target));
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await until(
        () =>
            lab.player.state.position.inMilliseconds >= target + 500 &&
            lab.player.state.position.inMilliseconds < target + 15000,
        45,
      );
      checks['${phase}Ms'] = seek.elapsedMilliseconds;
    }
    phase = 'rapid-seeks';
    final rapid = Stopwatch()..start();
    await lab.seek(Duration(milliseconds: (duration * 0.2).round()));
    await lab.seek(Duration(milliseconds: (duration * 0.7).round()));
    final finalTarget = (duration * 0.3).round();
    await lab.seek(Duration(milliseconds: finalTarget));
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await until(
      () =>
          lab.player.state.position.inMilliseconds >= finalTarget + 500 &&
          lab.player.state.position.inMilliseconds < finalTarget + 15000,
      45,
    );
    checks['rapidSeeksMs'] = rapid.elapsedMilliseconds;
    phase = 'pause';
    await lab.player.pause();
    final position = lab.player.state.position;
    await Future<void>.delayed(const Duration(seconds: 2));
    checks['pauseDriftMs'] =
        (lab.player.state.position - position).inMilliseconds;
    await lab.player.play();
    phase = 'resume';
    await until(
      () =>
          lab.player.state.position >
          position + const Duration(milliseconds: 500),
      20,
    );
    passed = true;
  } catch (error, stack) {
    checks['failure'] = '$error';
    checks['failurePhase'] = phase;
    checks['stack'] = '$stack';
  } finally {
    sampler.cancel();
    final report = {
      ...lab.report(),
      'passed': passed,
      'checks': checks,
      'wallMs': watch.elapsedMilliseconds,
      'samples': samples,
      'pid': pid,
    };
    await lab.stop();
    await lab.shutdown();
    final file = File(option('--report'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    exit(passed ? 0 : 1);
  }
}
