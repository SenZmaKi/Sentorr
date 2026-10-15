import 'dart:io';
import 'dart:ui';

import 'package:media_kit/media_kit.dart';

import '../../../player/diagnostics.dart';
import '../../../player/stream/stream_status.dart';
import '../../../player/stream/subtitles.dart';
import 'stats_captions.dart';
import 'stats_network.dart';
import 'stats_readout.dart';
import 'stats_swarm.dart';

/// One moment of stats for nerds: readable sections for the overlay and
/// typed, unit-stable metrics for recordings.
class NerdStatsSnapshot {
  NerdStatsSnapshot({
    required PlaybackDiagnostics diagnostics,
    required PlayerState playback,
    required StreamStatus? status,
    required PlaybackSubtitles captions,
    required this.title,
    required this.itemId,
    required this.viewport,
    required this.pixelRatio,
  }) : _d = NativeReadout(diagnostics.values),
       _p = playback,
       _network = NetworkStats(
         status,
         NativeReadout(diagnostics.values),
         playback.position.inMilliseconds / 1000,
       ),
       _swarm = SwarmStats(diagnostics.torrent),
       _captions = CaptionStats(
         captions,
         NativeReadout(diagnostics.values),
         playback.subtitle,
       );

  final NativeReadout _d;
  final PlayerState _p;
  final NetworkStats _network;
  final CaptionStats _captions;
  final SwarmStats _swarm;
  final String title;
  final String? itemId;
  final Size viewport;
  final double pixelRatio;

  String get _playback => _p.buffering
      ? 'Buffering'
      : _p.playing
      ? 'Playing'
      : 'Paused';

  List<StatsSection> get sections => [
    (
      title: 'Video',
      rows: [
        (
          'Viewport',
          '${viewport.width.round()} × ${viewport.height.round()} · ${pixelRatio.toStringAsFixed(2)}×',
        ),
        (
          'Resolution / source FPS',
          '${_d['video-params/w']} × ${_d['video-params/h']} / ${_d['container-fps']}',
        ),
        (
          'Video / audio codec',
          '${_d['video-codec']} / ${_d['audio-codec-name']}',
        ),
        ('Hardware decoder', _d['hwdec-current']),
        (
          'Pixel format / transfer',
          '${_d['video-params/pixelformat']} / ${_d['video-params/gamma']}',
        ),
        (
          'Estimated FPS / display Hz',
          '${_d['estimated-vf-fps']} / ${_d['display-fps']}',
        ),
        (
          'Dropped frames (decode / output)',
          '${_d['decoder-frame-drop-count']} / ${_d['frame-drop-count']}',
        ),
        ('A/V difference (s)', _d['avsync']),
        ('Playback', '$_playback · ${_p.rate}× · volume ${_p.volume.round()}%'),
      ],
    ),
    _network.buffer,
    _network.network,
    ..._swarm.sections,
    _captions.section,
  ];

  Map<String, Object?> get metrics => {
    'state': _playback.toLowerCase(),
    'positionSeconds': _p.position.inMilliseconds / 1000,
    'rate': _p.rate,
    'volume': _p.volume.round(),
    'viewportWidth': viewport.width.round(),
    'viewportHeight': viewport.height.round(),
    'devicePixelRatio': pixelRatio,
    for (final key in PlaybackDiagnostics.video) key: _d.typed(key),
    // Resident memory: leaks and pressure show as a climb over a session.
    'memoryBytes': ProcessInfo.currentRss,
    ..._network.metrics,
    ..._swarm.metrics,
    ..._captions.metrics,
  };

  /// Which item and source is playing; a change starts a recording segment.
  Object get segmentKey => (itemId, _network.key);

  Map<String, Object?> get segment => {
    'title': title,
    'itemId': itemId,
    ..._network.identity,
  };
}
