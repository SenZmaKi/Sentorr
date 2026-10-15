/// How long a stream's playback reads waited on pieces: the time a stall
/// spends waiting on the swarm, as opposed to the player or disk.
class ReadWaits {
  final _pending = <int, Stopwatch>{};
  int waits = 0;
  Duration waited = Duration.zero, slowest = Duration.zero;
  int slowestPiece = -1;

  /// A read for [piece] begins waiting; returns its clock.
  Stopwatch begin(int piece) =>
      _pending.putIfAbsent(piece, () => Stopwatch()..start());

  /// [piece]'s bytes arrived after [clock]. Reads sharing one wait count
  /// it once.
  void end(int piece, Stopwatch clock) {
    if (_pending[piece] != clock) return;
    _pending.remove(piece);
    final elapsed = clock.elapsed;
    // Pieces already on disk return within a millisecond or two.
    if (elapsed.inMilliseconds <= 5) return;
    waits++;
    waited += elapsed;
    if (elapsed > slowest) {
      slowest = elapsed;
      slowestPiece = piece;
    }
  }

  void abandon(int piece, Stopwatch clock) {
    if (_pending[piece] == clock) _pending.remove(piece);
  }

  Map<String, Object?> describe() => {
    'waits': waits,
    'waitedMs': waited.inMilliseconds,
    'slowestMs': slowest.inMilliseconds,
    'slowestPiece': slowestPiece < 0 ? null : slowestPiece,
    // Reads blocked right now: a stall in progress names its pieces.
    'pending': [
      for (final MapEntry(:key, :value) in _pending.entries)
        {'piece': key, 'waitingMs': value.elapsedMilliseconds},
    ],
  };
}
