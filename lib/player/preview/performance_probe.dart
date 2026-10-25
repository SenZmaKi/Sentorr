import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';

import 'controller.dart';

/// Opt-in audit sampler. No timers or frame callbacks in normal builds.
class PreviewPerformanceProbe {
  PreviewPerformanceProbe(this.player, this.previews, this.buffering) {
    buffering.addListener(_onBuffering);
    _playing = player.stream.playing.listen(
      (playing) => record({'event': playing ? 'play' : 'pause'}),
    );
    SchedulerBinding.instance.addTimingsCallback(_frames);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    record({'event': 'audit-start', 'pid': pid});
  }
  final Player player;
  final PreviewController Function() previews;
  final ValueListenable<bool> buffering;
  late final StreamSubscription<bool> _playing;
  void _onBuffering() => record({
    'event': 'buffering',
    'value': buffering.value,
    'playing': player.state.playing,
    'positionSeconds': player.state.position.inMilliseconds / 1000,
  });
  final _log = Logger('sentorr.preview.audit');
  late final Timer _timer;
  bool _busy = false, _closed = false;
  int _frameCount = 0;
  double _maxBuildMs = 0, _maxRasterMs = 0;

  void record(Map<String, Object?> event) {
    if (_closed) return;
    _log.info(
      jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(),
        'pid': pid,
        ...event,
      }),
    );
  }

  void _frames(List<FrameTiming> timings) {
    for (final frame in timings) {
      _frameCount++;
      final build = frame.buildDuration.inMicroseconds / 1000;
      final raster = frame.rasterDuration.inMicroseconds / 1000;
      if (build > _maxBuildMs) _maxBuildMs = build;
      if (raster > _maxRasterMs) _maxRasterMs = raster;
    }
  }

  Future<void> _sample() async {
    if (_busy || _closed) return;
    _busy = true;
    try {
      final native = player.platform;
      final properties = <String, String?>{};
      if (native is NativePlayer) {
        for (final key in [
          'frame-drop-count',
          'decoder-frame-drop-count',
          'avsync',
          'demuxer-cache-duration',
          'paused-for-cache',
          'seeking',
          'hwdec-current',
          'mpv-version',
          'display-fps',
        ]) {
          if (_closed) return;
          try {
            properties[key] = await native.getProperty(key);
          } catch (_) {
            properties[key] = null;
          }
        }
      }
      final preview = previews();
      record({
        'event': 'sample',
        'rssBytes': ProcessInfo.currentRss,
        'positionSeconds': player.state.position.inMilliseconds / 1000,
        'playing': player.state.playing,
        'buffering': buffering.value,
        'previewBusy': preview.busy,
        'attempts': preview.attempts,
        'hits': preview.hits,
        'failures': preview.failures,
        'cacheBytes': preview.cacheBytes,
        'uiFrames': _frameCount,
        'maxBuildMs': _maxBuildMs,
        'maxRasterMs': _maxRasterMs,
        ...properties,
      });
      _frameCount = 0;
      _maxBuildMs = _maxRasterMs = 0;
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _closed = true;
    _timer.cancel();
    buffering.removeListener(_onBuffering);
    _playing.cancel().ignore();
    SchedulerBinding.instance.removeTimingsCallback(_frames);
  }
}
