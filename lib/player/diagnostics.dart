import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Samples only while diagnostics are visible. Missing native properties are
/// explicit, because backend support varies across devices.
class PlaybackDiagnostics extends ChangeNotifier {
  PlaybackDiagnostics(this.read) {
    unawaited(sample());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  }

  factory PlaybackDiagnostics.forPlayer(Player player) =>
      PlaybackDiagnostics((property) async {
        final native = player.platform;
        return native is NativePlayer ? native.getProperty(property) : '';
      });

  final Future<String> Function(String) read;
  late final Timer _timer;
  bool _closed = false, _busy = false;
  Map<String, String> values = {};
  static const properties = [
    'video-codec',
    'audio-codec-name',
    'hwdec-current',
    'video-params/w',
    'video-params/h',
    'container-fps',
    'estimated-vf-fps',
    'display-fps',
    'decoder-frame-drop-count',
    'frame-drop-count',
    'demuxer-cache-duration',
    'avsync',
    'video-params/pixelformat',
    'video-params/gamma',
  ];

  Future<void> sample() async {
    if (_busy || _closed) return;
    _busy = true;
    final next = <String, String>{};
    try {
      for (final key in properties) {
        if (_closed) return;
        try {
          final value = await read(key);
          next[key] = value.isEmpty ? 'Unavailable' : value;
        } catch (_) {
          next[key] = 'Unavailable';
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

  @override
  void dispose() {
    _closed = true;
    _timer.cancel();
    super.dispose();
  }
}
