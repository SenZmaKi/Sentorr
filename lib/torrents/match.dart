import 'resolution_models.dart';

/// Why the best candidate is not exactly what was asked for. Identity is
/// already validated by the sources; these are preference compromises.
enum MatchConcern {
  /// Quality differs from the preferred resolution.
  otherResolution,

  /// The release does not state its quality.
  unknownResolution,

  /// A season pack; the episode is chosen from its files at playback.
  seasonPack,
  seriesPack;

  String describe(TorrentPreferences preferences) => switch (this) {
    otherResolution => 'Not available in ${preferences.preferredResolution}p.',
    unknownResolution => 'The release does not state its quality.',
    seasonPack =>
      'This is a whole season; the episode is picked from its files.',
    seriesPack => 'This is a series batch; the season and episode are checked in its files.',
  };
}

/// The best candidate of a resolution, judged against the preferences that
/// produced it: exact matches may start on their own, close ones ask first.
class TorrentMatch {
  TorrentMatch._(this.candidate, Iterable<MatchConcern> concerns)
    : concerns = List.unmodifiable(concerns);

  /// Null when the resolution has no candidates.
  static TorrentMatch? of(
    TorrentResolution resolution,
    TorrentPreferences preferences,
  ) {
    final best = resolution.best;
    return best == null ? null : forCandidate(best, preferences);
  }

  /// [best] judged against [preferences], wherever it ranked.
  static TorrentMatch forCandidate(
    TorrentCandidate best,
    TorrentPreferences preferences,
  ) {
    final quality = best.release.resolution;
    return TorrentMatch._(best, [
      if (quality == null)
        MatchConcern.unknownResolution
      else if (quality != preferences.preferredResolution)
        MatchConcern.otherResolution,
      if (best.requiresFileSelection)
        best.release.isSeriesPack
            ? MatchConcern.seriesPack
            : MatchConcern.seasonPack,
    ]);
  }

  final TorrentCandidate candidate;
  final List<MatchConcern> concerns;

  bool get exact => concerns.isEmpty;
}
