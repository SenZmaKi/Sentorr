import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'stream/stream_status.dart';

typedef TimelineSpan = ({double start, double end});

/// Cache coverage is transient; never accumulate ranges across seeks or files.
class PlaybackCacheRanges extends ValueNotifier<List<TimelineSpan>> {
  PlaybackCacheRanges({
    required this.status,
    required this.read,
    required this.duration,
  }) : super(const []) {
    status.addListener(_changed);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  }

  factory PlaybackCacheRanges.forPlayer(
    Player player,
    ValueListenable<StreamStatus?> status,
  ) => PlaybackCacheRanges(
    status: status,
    duration: () => player.state.duration,
    read: () async {
      final native = player.platform;
      return native is NativePlayer
          ? native.getProperty('demuxer-cache-state')
          : '';
    },
  );

  final ValueListenable<StreamStatus?> status;
  final Future<String> Function() read;
  final Duration Function() duration;
  late final Timer _timer;
  int _generation = 0;
  bool _busy = false, _closed = false;

  bool get _eligible {
    final current = status.value;
    return current?.stage == StreamStage.streaming &&
        !current!.hasDownloadedTimeline;
  }

  void _changed() {
    if (!_eligible) invalidate();
  }

  void invalidate() {
    _generation++;
    if (value.isNotEmpty) value = const [];
  }

  Future<void> sample() async {
    if (_closed || _busy || !_eligible) return;
    _busy = true;
    final generation = _generation;
    try {
      final raw = await read();
      if (_closed || generation != _generation || !_eligible) return;
      final next = parseCacheRanges(raw, duration());
      if (!listEquals(value, next)) value = next;
    } catch (_) {
      if (!_closed && generation == _generation) value = const [];
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _timer.cancel();
    status.removeListener(_changed);
    super.dispose();
  }
}

/// mpv serializes its node property as JSON through get_property_string.
List<TimelineSpan> parseCacheRanges(String raw, Duration duration) {
  final total = duration.inMicroseconds / 1e6;
  if (total <= 0 || raw.isEmpty) return const [];
  dynamic node;
  try {
    node = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (node is! Map || node['seekable-ranges'] is! List) return const [];
  final ranges = <TimelineSpan>[];
  for (final entry in node['seekable-ranges'] as List) {
    if (entry is! Map) continue;
    final a = entry['start'], b = entry['end'];
    if (a is! num || b is! num || !a.isFinite || !b.isFinite || b <= a) {
      continue;
    }
    final start = (a / total).clamp(0.0, 1.0).toDouble();
    final end = (b / total).clamp(0.0, 1.0).toDouble();
    if (end > start) ranges.add((start: start, end: end));
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <TimelineSpan>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((
        start: last.start,
        end: range.end > last.end ? range.end : last.end,
      ));
    } else {
      merged.add(range);
    }
  }
  // Keeping only some ranges is conservative and bounds paint work.
  return List.unmodifiable(merged.take(512));
}
