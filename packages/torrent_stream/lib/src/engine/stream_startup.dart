/// Tracks one start of playback, from opening or a seek until the player has
/// read a contiguous window, and describes how long it took.
class StreamStartup {
  StreamStartup(this.length);
  final int length;
  final _clock = Stopwatch();
  bool begun = false, starting = false;
  int _target = 0, _runStart = -1, _runEnd = -1, _pieces = 0;
  int _slowestPiece = -1;
  Duration _slowest = Duration.zero;
  String status = '';

  /// How long the latest completed start took.
  Duration? lastReady;

  Map<String, Object?> describe() => {
    'status': status,
    'starting': starting,
    if (starting) 'startingMs': _clock.elapsedMilliseconds,
    'lastReadyMs': lastReady?.inMilliseconds,
  };

  void begin(int bytes) {
    begun = starting = true;
    _target = bytes;
    _runStart = _runEnd = -1;
    _pieces = 0;
    _slowestPiece = -1;
    _slowest = Duration.zero;
    _clock
      ..reset()
      ..start();
    status = 'starting';
  }

  /// Records [count] bytes at [offset] reaching the player after waiting
  /// [waited] for [piece]. True once, when the start window completes.
  bool served(int piece, int offset, int count, Stopwatch waited) {
    if (!starting) return false;
    if (waited.elapsed > _slowest) {
      _slowest = waited.elapsed;
      _slowestPiece = piece;
    }
    if (waited.elapsedMilliseconds > 5) _pieces++;
    if (offset == _runEnd) {
      _runEnd += count;
    } else {
      _runStart = offset;
      _runEnd = offset + count;
    }
    final run = _runEnd - _runStart;
    if (run < _target && _runEnd < length) {
      status =
          'starting: ${_mib(run)} of ${_mib(_target)} MiB after '
          '${_seconds(_clock.elapsed)}s';
      return false;
    }
    starting = false;
    _clock.stop();
    lastReady = _clock.elapsed;
    status =
        'ready: ${_mib(run)} MiB in ${_seconds(_clock.elapsed)}s, '
        '$_pieces piece waits, slowest piece $_slowestPiece '
        '${_seconds(_slowest)}s';
    return true;
  }

  /// The player stopped reading before the window filled.
  void abandon() {
    starting = false;
    _clock.stop();
    status = 'no reads ${_seconds(_clock.elapsed)}s after starting';
  }

  static String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);
}
