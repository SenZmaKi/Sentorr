import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/player/engine.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:sentorr/torrents/engine.dart';

Future<Map<String, Object?>> checkOutage(
  ProviderContainer container,
  Directory root,
  String kind,
) async {
  await File('${root.path}/outage-ready').writeAsString('ready');
  await _until(() => File('${root.path}/outage-started').existsSync());
  final engine = container.read(playbackEngineProvider);
  final captionsEnabled = engine.streaming.subtitles.enabled;
  final sidecar = engine.streaming.subtitles.embeddedTrack;
  final clock = Stopwatch()..start();
  // Jump beyond the normal 60-second demuxer window while the host is absent.
  await engine.seek(const Duration(seconds: 180));
  await _until(
    () =>
        engine.streaming.status.value?.stage == StreamStage.streaming &&
        engine.state.playing &&
        engine.state.position.inMilliseconds > 181000,
  );
  final torrents = container.read(torrentEngineProvider).torrents.length;
  if ((kind == 'brief' && torrents != 0) ||
      (kind == 'permanent' && torrents != 1)) {
    throw StateError(
      'Wrong fallback policy: $kind produced $torrents local torrents',
    );
  }
  if ((engine.state.rate - 1.25).abs() > .01 ||
      (engine.state.volume - 37).abs() > .01) {
    throw StateError('Recovery lost playback controls');
  }
  if (engine.streaming.subtitles.enabled != captionsEnabled ||
      (sidecar?.data == true &&
          engine.streaming.subtitles.embeddedTrack?.id != sidecar?.id)) {
    throw StateError('Recovery lost caption intent or external text');
  }
  return {
    'outage': kind,
    'recoveryMs': clock.elapsedMilliseconds,
    'recoveredPositionMs': engine.state.position.inMilliseconds,
    'recoveredPeer': engine.streaming.status.value?.peer,
    'receiverTorrentsAfterOutage': torrents,
  };
}

Future<void> _until(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > const Duration(seconds: 90)) {
      throw StateError('Outage recovery timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
