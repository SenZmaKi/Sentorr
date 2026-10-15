import 'dart:async';
import 'dart:io';

import '../../../player/diagnostics.dart';
import '../../../player/playback_events.dart';
import '../../../player/stats_recording.dart';
import '../../../shared/persistence/app_paths.dart';
import 'nerd_stats_rows.dart';
import 'stats_export.dart';

/// Owns stats for nerds' current recording: sampling it each diagnostics
/// tick, describing its session, and keeping it if the player closes
/// before it is exported.
class StatsRecorder {
  StatsRecorder({
    required this.diagnostics,
    required this.snapshot,
    required this.events,
    required this.describe,
    required this.paths,
  });

  final PlaybackDiagnostics diagnostics;
  final NerdStatsSnapshot Function() snapshot;
  final PlaybackEvents events;
  final Future<Map<String, Object?>> Function() describe;
  final AppPaths? paths;

  StatsRecording? recording;
  Future<void>? _described;
  int _ticks = 0;

  /// The engine's full detail (peers, requests) every few samples; the
  /// headline numbers are in every one.
  static const _engineEvery = 5;

  void sample() {
    final r = recording;
    if (r != null && !r.stopped) _add(r);
  }

  void _add(StatsRecording r) {
    final s = snapshot();
    final engine = diagnostics.torrent;
    r.add(
      {
        ...s.metrics,
        if (engine != null && _ticks++ % _engineEvery == 0) 'engine': engine,
      },
      segmentKey: s.segmentKey,
      segment: s.segment,
    );
  }

  StatsRecording _begin(StatsRecording r) {
    _ticks = 0;
    _add(r);
    _described = describe()
        .then(r.session.addAll)
        .catchError((Object e) => r.session['describeError'] = '$e');
    return recording = r;
  }

  StatsRecording start() => _begin(StatsRecording());

  /// The event log's whole window and one sample now: for a problem that
  /// already happened, without having recorded it.
  StatsRecording recent() =>
      _begin(StatsRecording(preRoll: events.keep))..stop();

  void stop() => recording?.stop();

  void discard() => recording = null;

  Future<String?> encode() async {
    final r = recording;
    if (r == null) return null;
    await _described?.timeout(const Duration(seconds: 3), onTimeout: () {});
    return StatsExport.encode(r, events);
  }

  /// Saves an unexported recording to the app's diagnostics folder.
  Future<File?> keepIfUnexported() async {
    final r = recording, paths = this.paths;
    if (r == null || r.exported || paths == null) return null;
    r.stop();
    final json = await encode();
    return json == null ? null : StatsExport.keep(json, paths, r.startedAt);
  }
}
