/// A decoder failure alone cannot distinguish damaged data from codec support.
enum IntegrityState {
  valid,
  damaged,

  /// Pieces shared with neighbouring files could not be confirmed. Recovery
  /// is safe: it keeps valid data and downloads only failing pieces.
  inconclusive,
  unavailable;

  /// Recovering may repair the file.
  bool get recoverable => this == damaged || this == inconclusive;
}

class IntegrityResult {
  const IntegrityResult(this.state, this.message);
  final IntegrityState state;
  final String message;
}

class UnverifiableMedia implements Exception {
  const UnverifiableMedia();
  @override
  String toString() =>
      'Some torrent pieces could not be verified. '
      'Neighbouring files may be needed to check shared boundary pieces.';
}

/// Where a check has reached, in the order a check runs.
enum IntegrityStage { details, file, pieces }

class IntegrityProgress {
  const IntegrityProgress(this.stage, [this.fraction]);
  final IntegrityStage stage;

  /// Share of pieces hashed; null until hashing reports.
  final double? fraction;
}

typedef OnIntegrityProgress = void Function(IntegrityProgress progress);
