import 'dart:convert';

import 'playback_events.dart';

/// Stats for nerds sampled over time, exported as JSON for debugging.
///
/// Each source played during the recording (item, torrent, downloaded file)
/// is a segment with its own details and numeric summary, because native
/// counters restart with the source. Non-numeric metrics (states, phases,
/// decoders) are logged as changes so transitions read at a glance. The
/// playback event log, from [preRoll] before the start, gives exact times
/// for seeks, stalls and errors between samples. Samples follow one per
/// line.
class StatsRecording {
  StatsRecording({
    Map<String, Object?>? session,
    DateTime? startedAt,
    this.preRoll = const Duration(minutes: 2),
  }) : session = {...?session},
       startedAt = startedAt ?? DateTime.now();

  /// Facts for the whole recording, e.g. device and settings; may fill in
  /// after it starts.
  final Map<String, Object?> session;

  /// How much of the event log before [startedAt] to include: what led up
  /// to pressing record.
  final Duration preRoll;

  /// Sent somewhere, or saved on closing; nothing is lost if dropped now.
  bool exported = false;
  final DateTime startedAt;
  DateTime? stoppedAt;
  final _segments = <({double start, Map<String, Object?> info})>[];
  final _samples = <({double t, int segment, Map<String, Object?> metrics})>[];
  Object? _segmentKey;

  int get length => _samples.length;
  int get segments => _segments.length;
  bool get stopped => stoppedAt != null;
  Duration get elapsed => (stoppedAt ?? DateTime.now()).difference(startedAt);

  /// [segmentKey] identifies the source; a new key starts a segment. Within
  /// one, non-null [segment] details fill in as they become known.
  void add(
    Map<String, Object?> metrics, {
    Object? segmentKey,
    Map<String, Object?> segment = const {},
    DateTime? at,
  }) {
    if (stopped) return;
    final t =
        (at ?? DateTime.now()).difference(startedAt).inMilliseconds / 1000;
    if (_segments.isEmpty || segmentKey != _segmentKey) {
      _segmentKey = segmentKey;
      _segments.add((start: t, info: {...segment}));
    } else {
      final info = _segments.last.info;
      for (final MapEntry(:key, :value) in segment.entries) {
        if (value != null) info[key] = value;
      }
    }
    _samples.add((t: t, segment: _segments.length - 1, metrics: {...metrics}));
  }

  void stop({DateTime? at}) => stoppedAt ??= at ?? DateTime.now();

  /// Native readouts arrive as text; numbers become numbers and missing
  /// values null, so the export compares without parsing.
  static Object? typed(String? value) =>
      value == null || value.isEmpty || value == 'Unavailable'
      ? null
      : num.tryParse(value) ?? value;

  /// First, last, min and max of every numeric metric in [segment];
  /// counters such as dropped frames read as last − first.
  Map<String, Map<String, num>> summary(int segment) {
    final out = <String, Map<String, num>>{};
    for (final s in _samples.where((s) => s.segment == segment)) {
      for (final MapEntry(:key, :value) in s.metrics.entries) {
        if (value is! num) continue;
        final m = out[key];
        if (m == null) {
          out[key] = {
            'first': value,
            'last': value,
            'min': value,
            'max': value,
          };
        } else {
          m['last'] = value;
          if (value < m['min']!) m['min'] = value;
          if (value > m['max']!) m['max'] = value;
        }
      }
    }
    return out;
  }

  /// Transitions of non-numeric metrics within each segment.
  List<Map<String, Object?>> get changes {
    final out = <Map<String, Object?>>[];
    Map<String, Object?>? previous;
    var segment = -1;
    for (final s in _samples) {
      if (s.segment != segment) {
        segment = s.segment;
        previous = null;
      }
      if (previous != null) {
        for (final key in {...previous.keys, ...s.metrics.keys}) {
          final from = previous[key], to = s.metrics[key];
          if (from is num || to is num || from == to) continue;
          // Nested detail, e.g. the engine's peers, is sampled not compared.
          if (from is Map || to is Map || from is List || to is List) {
            continue;
          }
          out.add({'t': s.t, 'metric': key, 'from': from, 'to': to});
        }
      }
      previous = s.metrics;
    }
    return out;
  }

  /// [events], from the playback log, with times relative to the start.
  String toJson({
    Map<String, Object?> extra = const {},
    List<PlaybackEvent> events = const [],
  }) {
    final duration = elapsed.inMilliseconds / 1000;
    const pretty = JsonEncoder.withIndent('  ');
    final head = pretty.convert({
      'session': {...session, ...extra},
      'startedAt': startedAt.toIso8601String(),
      'stoppedAt': stoppedAt?.toIso8601String(),
      'durationSeconds': duration,
      'sampleCount': length,
      'segments': [
        for (final (i, s) in _segments.indexed)
          {
            'index': i,
            'startSeconds': s.start,
            'endSeconds': i + 1 < _segments.length
                ? _segments[i + 1].start
                : duration,
            ...s.info,
            'summary': summary(i),
          },
      ],
      'changes': changes,
    });
    String lines(Iterable<Map<String, Object?>> rows) =>
        rows.map((r) => '    ${jsonEncode(r)}').join(',\n');
    final eventLines = lines(
      events.map(
        (e) => {
          't': e.at.difference(startedAt).inMilliseconds / 1000,
          'kind': e.kind,
          ...e.data,
        },
      ),
    );
    final sampleLines = lines(
      _samples.map((s) => {'t': s.t, 'segment': s.segment, ...s.metrics}),
    );
    // Events and samples one per line: the file scans and diffs like a log.
    return '${head.substring(0, head.length - 2)},\n'
        '  "events": [\n$eventLines\n  ],\n'
        '  "samples": [\n$sampleLines\n  ]\n}\n';
  }
}
