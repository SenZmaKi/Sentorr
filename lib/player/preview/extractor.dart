import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:media_kit/media_kit.dart';

import 'seek_frame_gate.dart';

/// One paused decoder, independent of the visible player's position and tracks.
enum PreviewSeekMode { exact, keyframe }

class PreviewExtractor {
  PreviewExtractor({this.mode = PreviewSeekMode.keyframe});
  final PreviewSeekMode mode;
  Duration? framePosition;
  Map<String, Object?> timings = {};
  Player? _player;
  String? _source;
  int? _width, _height;
  SeekFrameGate? _gate;

  Future<Uint8List?> extract(String source, Duration target) async {
    framePosition = null;
    timings = {'cold': _source != source, 'mode': mode.name, 'phase': 'open'};
    final total = Stopwatch()..start();
    final player = _player ??= Player(
      configuration: const PlayerConfiguration(bufferSize: 1024 * 1024),
    );
    final native = player.platform as NativePlayer;
    await native.getProperty('idle-active');
    final gate = _gate ??= SeekFrameGate(native);
    if (_source != source) {
      for (final entry in {
        'vo': 'null',
        'vid': 'auto',
        'audio': 'no',
        'sid': 'no',
        'hwdec': 'no',
        'vd-lavc-threads': '2',
        'demuxer-readahead-secs': '0',
        'demuxer-max-bytes': '1048576',
        'network-timeout': '2',
      }.entries) {
        await native.setProperty(entry.key, entry.value);
      }
      await player.open(Media(source), play: false);
      final loading = Stopwatch()..start();
      while (double.tryParse(await native.getProperty('time-pos')) == null ||
          await native.getProperty('seeking') != 'no') {
        if (loading.elapsed > const Duration(seconds: 2)) {
          timings['failureStage'] = 'open';
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final width =
          double.tryParse(await native.getProperty('video-params/dw')) ??
          double.tryParse(await native.getProperty('video-params/w'));
      final height =
          double.tryParse(await native.getProperty('video-params/dh')) ??
          double.tryParse(await native.getProperty('video-params/h'));
      if (width == null || height == null || width <= 0 || height <= 0) {
        timings['failureStage'] = 'source-dimensions';
        return null;
      }
      final scale = math.min(1.0, math.min(240 / width, 136 / height));
      _width = (width * scale).floor().clamp(1, 240);
      _height = (height * scale).floor().clamp(1, 136);
      // Built into mpv 0.36: unlike FFmpeg's scale filter, available in the
      // packaged runtime. Explicit display size also normalizes pixel aspect.
      await native.command([
        'vf',
        'set',
        'format=w=$_width:h=$_height:dw=$_width:dh=$_height:convert=yes',
      ]);
      _source = source;
    }
    timings['targetWidth'] = _width;
    timings['targetHeight'] = _height;
    timings['openMs'] = total.elapsedMilliseconds;
    timings['phase'] = 'seek';
    final seekingWatch = Stopwatch()..start();
    gate.begin();
    await native.command([
      'seek',
      '${target.inMilliseconds / 1000}',
      mode == PreviewSeekMode.exact ? 'absolute+exact' : 'absolute+keyframes',
    ]);
    // The command reply confirms the seek was issued; mpv clears seeking
    // after the new frame restarts. Keyframes can be far from the target.
    final deadline = Stopwatch()..start();
    var restarted = false;
    while (deadline.elapsed < const Duration(seconds: 2)) {
      restarted = restarted || gate.ready;
      final seeking = await native.getProperty('seeking');
      final position = double.tryParse(await native.getProperty('time-pos'));
      if (restarted &&
          (seeking == 'no' || seeking == 'false') &&
          position != null &&
          (mode == PreviewSeekMode.keyframe ||
              (position - target.inMilliseconds / 1000).abs() < 0.1)) {
        framePosition = Duration(milliseconds: (position * 1000).round());
        timings['seekMs'] = seekingWatch.elapsedMilliseconds;
        timings['phase'] = 'capture';
        final capture = Stopwatch()..start();
        final outputWidth = int.tryParse(
          await native.getProperty('video-out-params/w'),
        );
        final outputHeight = int.tryParse(
          await native.getProperty('video-out-params/h'),
        );
        timings['outputWidth'] = outputWidth;
        timings['outputHeight'] = outputHeight;
        // Never JPEG-encode a full-resolution frame if reconfiguration failed.
        if (outputWidth != _width || outputHeight != _height) {
          timings['failureStage'] = 'resize';
          return null;
        }
        final image = await player.screenshot();
        if (image != null) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(image);
          try {
            final descriptor = await ui.ImageDescriptor.encoded(buffer);
            try {
              timings['imageWidth'] = descriptor.width;
              timings['imageHeight'] = descriptor.height;
              if (descriptor.width > 240 || descriptor.height > 136) {
                timings['failureStage'] = 'capture-dimensions';
                return null;
              }
            } finally {
              descriptor.dispose();
            }
          } finally {
            buffer.dispose();
          }
        }
        timings['captureMs'] = capture.elapsedMilliseconds;
        timings['phase'] = 'done';
        if (image == null) timings['failureStage'] = 'capture';
        return image;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    timings['failureStage'] = 'seek';
    return null;
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _source = null;
    _width = _height = null;
    _gate?.dispose();
    _gate = null;
    await player?.dispose();
  }
}
