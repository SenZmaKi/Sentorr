import 'dart:collection';

/// One thing that happened during playback, at its exact time.
class PlaybackEvent {
  PlaybackEvent(this.at, this.kind, this.data);
  final DateTime at;
  final String kind;
  final Map<String, Object?> data;
}

/// An always-on, bounded log of what playback did: opens, seeks, stalls,
/// stage changes, errors and native warnings. Cheap enough to keep running,
/// so a recording or export can include what happened before anyone
/// thought to record.
///
/// It also times the moments viewers feel: an open or seek is "ready" once
/// the playhead advances while playing, and a stall is buffering after that.
class PlaybackEvents {
  PlaybackEvents({
    this.keep = const Duration(minutes: 15),
    this.maxEvents = 4000,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration keep;
  final int maxEvents;
  final DateTime Function() _now;
  final _events = Queue<PlaybackEvent>();

  /// The open or seek waiting for playback to advance.
  ({String after, DateTime at})? _awaiting;
  Duration? _baseline;
  DateTime? _openedAt, _stalledAt;
  bool _playing = false, _buffering = false;

  void add(String kind, [Map<String, Object?> data = const {}]) {
    final now = _now();
    _events.add(PlaybackEvent(now, kind, data));
    final cutoff = now.subtract(keep);
    while (_events.length > maxEvents ||
        (_events.isNotEmpty && _events.first.at.isBefore(cutoff))) {
      _events.removeFirst();
    }
  }

  /// Events from [from] up to [to], oldest first.
  List<PlaybackEvent> between(DateTime from, [DateTime? to]) => [
    for (final e in _events)
      if (!e.at.isBefore(from) && (to == null || !e.at.isAfter(to))) e,
  ];

  int _since(DateTime? start) =>
      start == null ? -1 : _now().difference(start).inMilliseconds;

  void opened(Map<String, Object?> item, Duration start) {
    _openedAt = _now();
    _stalledAt = null;
    _awaiting = (after: 'open', at: _openedAt!);
    _baseline = null;
    add('open', {...item, 'startSeconds': _seconds(start)});
  }

  void seeking(Duration from, Duration to) {
    _endStall();
    _awaiting = (after: 'seek', at: _now());
    _baseline = null;
    add('seek', {'fromSeconds': _seconds(from), 'toSeconds': _seconds(to)});
  }

  /// A stream stage or source change, timed from the open.
  void stage(String kind, Map<String, Object?> data) =>
      add(kind, {...data, 'sinceOpenMs': _since(_openedAt)});

  void playing(bool value) {
    if (value == _playing) return;
    _playing = value;
    add(value ? 'play' : 'pause');
    if (!value) _endStall();
  }

  void buffering(bool value) {
    if (value == _buffering) return;
    _buffering = value;
    if (value && _playing && _awaiting == null) {
      _stalledAt = _now();
      add('stall');
    } else if (!value) {
      _endStall();
    }
  }

  void _endStall() {
    final at = _stalledAt;
    if (at == null) return;
    _stalledAt = null;
    add('stall-end', {'ms': _since(at)});
  }

  void position(Duration position) {
    final awaiting = _awaiting;
    if (awaiting == null || !_playing || _buffering) {
      _baseline = null;
      return;
    }
    // Ready once the playhead advances naturally, not on the jump that
    // lands an open or seek, nor on a stale position from before it.
    final base = _baseline;
    _baseline = position;
    if (base == null) return;
    final step = position - base;
    if (step < const Duration(milliseconds: 100) ||
        step > const Duration(seconds: 2)) {
      return;
    }
    _awaiting = null;
    _baseline = null;
    add('ready', {
      'after': awaiting.after,
      'ms': _since(awaiting.at),
      'positionSeconds': _seconds(position),
    });
  }

  static double _seconds(Duration d) => d.inMilliseconds / 1000;
}
