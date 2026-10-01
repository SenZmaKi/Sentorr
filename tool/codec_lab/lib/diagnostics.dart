import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';

class Diagnostics extends ChangeNotifier {
  final Player player;
  Timer? _timer;
  bool _busy = false, _closed = false;
  Map<String, String> values = {};
  double buildMs = 0, rasterMs = 0;
  int uiFrames = 0, uiOverBudget = 0;
  final List<FrameTiming> _timings = [];
  final int _budgetUs;
  static const properties = {
    'video-codec': 'Video codec',
    'audio-codec-name': 'Audio codec',
    'hwdec-current': 'Active hardware decoder',
    'video-format': 'Video format',
    'container-fps': 'Source FPS',
    'estimated-vf-fps': 'Estimated video FPS',
    'display-fps': 'Display refresh Hz',
    'decoder-frame-drop-count': 'Decoder drops',
    'frame-drop-count': 'Output drops',
    'mistimed-frame-count': 'Mistimed frames',
    'video-params/w': 'Width',
    'video-params/h': 'Height',
    'video-params/pixelformat': 'Pixel format',
    'video-params/gamma': 'Transfer function',
    'video-bitrate': 'Video bitrate (bit/s)',
    'audio-bitrate': 'Audio bitrate (bit/s)',
    'demuxer-cache-duration': 'Read-ahead seconds',
    'avsync': 'A/V difference (s)',
  };
  Diagnostics(this.player, double refreshRate)
    : _budgetUs = (1000000 / (refreshRate > 0 ? refreshRate : 60)).round() {
    SchedulerBinding.instance.addTimingsCallback(_onTiming);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }
  void _onTiming(List<FrameTiming> timings) {
    if (timings.isEmpty || _closed) return;
    _timings.addAll(timings);
    if (_timings.length > 120) _timings.removeRange(0, _timings.length - 120);
    uiFrames += timings.length;
    uiOverBudget += timings
        .where(
          (t) =>
              t.buildDuration.inMicroseconds > _budgetUs ||
              t.rasterDuration.inMicroseconds > _budgetUs,
        )
        .length;
    buildMs =
        _timings
            .map((t) => t.buildDuration.inMicroseconds)
            .reduce((a, b) => a + b) /
        _timings.length /
        1000;
    rasterMs =
        _timings
            .map((t) => t.rasterDuration.inMicroseconds)
            .reduce((a, b) => a + b) /
        _timings.length /
        1000;
  }

  void reset() {
    values = {};
    uiFrames = 0;
    uiOverBudget = 0;
    _timings.clear();
    buildMs = 0;
    rasterMs = 0;
    notifyListeners();
  }

  Future<void> _poll() async {
    if (_busy || _closed) return;
    _busy = true;
    final next = <String, String>{};
    try {
      final native = player.platform;
      if (native is NativePlayer) {
        for (final property in properties.keys) {
          if (_closed) return;
          try {
            final value = await native.getProperty(property);
            next[property] = value.isEmpty ? 'Unavailable' : value;
          } catch (_) {
            next[property] = 'Unavailable';
          }
        }
      }
      if (!_closed) {
        values = next;
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  Map<String, dynamic> snapshot() => {
    'mpv': values,
    'uiBuildMs': buildMs,
    'uiRasterMs': rasterMs,
    'uiFramesObserved': uiFrames,
    'uiFramesOverBudget': uiOverBudget,
    'uiBudgetMicroseconds': _budgetUs,
  };
  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTiming);
    super.dispose();
  }
}

class StatsOverlay extends StatelessWidget {
  final Diagnostics diagnostics;
  const StatsOverlay({super.key, required this.diagnostics});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ListenableBuilder(
      listenable: diagnostics,
      builder: (context, _) => Container(
        width: 330,
        padding: const EdgeInsets.all(12),
        color: const Color(0xe6101720),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STATS FOR NERDS · sampled every 1s',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final key in [
                'video-codec',
                'audio-codec-name',
                'hwdec-current',
                'container-fps',
                'estimated-vf-fps',
                'display-fps',
                'decoder-frame-drop-count',
                'frame-drop-count',
                'mistimed-frame-count',
                'video-bitrate',
                'demuxer-cache-duration',
                'avsync',
              ])
                Text(
                  '${Diagnostics.properties[key]}: ${diagnostics.values[key] ?? 'Waiting'}',
                ),
              Text(
                'Pixels: ${diagnostics.values['video-params/w'] ?? '?'} × ${diagnostics.values['video-params/h'] ?? '?'}',
              ),
              Text(
                'Format: ${diagnostics.values['video-params/pixelformat'] ?? '?'}',
              ),
              Text(
                'UI build/raster: ${diagnostics.buildMs.toStringAsFixed(2)} / ${diagnostics.rasterMs.toStringAsFixed(2)} ms',
              ),
              Text(
                'UI over budget: ${diagnostics.uiOverBudget}/${diagnostics.uiFrames}',
              ),
              const Text('UI timing ≠ video FPS. Drops are mpv counters.'),
            ],
          ),
        ),
      ),
    ),
  );
}
