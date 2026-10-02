import 'models.dart';
import 'diagnostics.dart';

/// Preferences affect selection, never the identity of the requested title.
class TorrentPreferences {
  TorrentPreferences({
    this.preferredResolution = 1080,
    this.minimumSeeders = 1,
    this.maximumSizeBytes,
    this.allowUnknownResolution = true,
    this.allowSeasonPackFallback = false,
    this.allowAlternateSearchFallback = true,
    this.allowResolutionFallback = true,
  }) {
    if (preferredResolution <= 0 ||
        minimumSeeders < 1 ||
        (maximumSizeBytes != null && maximumSizeBytes! <= 0)) {
      throw ArgumentError('Invalid torrent preferences');
    }
  }

  final int preferredResolution, minimumSeeders;
  final int? maximumSizeBytes;
  final bool allowUnknownResolution, allowSeasonPackFallback;
  final bool allowAlternateSearchFallback, allowResolutionFallback;
}

enum TorrentResolutionStage { primary, alternate, seasonPack }

class TorrentResolutionAttempt {
  TorrentResolutionAttempt({
    required this.query,
    required this.stage,
    required this.releaseCount,
    required this.eligibleCount,
    required Iterable<SourceFailure> failures,
    Iterable<SourceSearchDiagnostics> sources = const [],
    Map<TorrentRejection, int> preferenceRejections = const {},
  }) : failures = List.unmodifiable(failures),
       sources = List.unmodifiable(sources),
       preferenceRejections = Map.unmodifiable(preferenceRejections);
  final TorrentQuery query;
  final TorrentResolutionStage stage;
  final int releaseCount, eligibleCount;
  final List<SourceFailure> failures;
  final List<SourceSearchDiagnostics> sources;
  final Map<TorrentRejection, int> preferenceRejections;
}

class TorrentCandidate {
  const TorrentCandidate({
    required this.release,
    required this.score,
    required this.qualityScore,
    required this.availabilityScore,
    required this.sizeScore,
    required this.requiresFileSelection,
  });

  final TorrentRelease release;
  final double score, qualityScore, availabilityScore, sizeScore;

  /// A pack is only a potential episode match until its files are inspected.
  final bool requiresFileSelection;
}

enum TorrentResolutionStatus { resolved, noMatch, unavailable }

class TorrentResolution {
  TorrentResolution({
    required this.query,
    required Iterable<TorrentCandidate> candidates,
    required Iterable<SourceFailure> failures,
    Iterable<TorrentResolutionAttempt> attempts = const [],
  }) : candidates = List.unmodifiable(candidates),
       failures = List.unmodifiable(failures),
       attempts = List.unmodifiable(attempts);

  final TorrentQuery query;
  final List<TorrentCandidate> candidates;
  final List<SourceFailure> failures;
  final List<TorrentResolutionAttempt> attempts;
  TorrentCandidate? get best => candidates.firstOrNull;

  /// Counts are observations across attempts, not unique torrents.
  Map<TorrentRejection, int> get rejectionCounts {
    final counts = <TorrentRejection, int>{};
    for (final attempt in attempts) {
      for (final rejected in [
        attempt.preferenceRejections,
        ...attempt.sources.map((s) => s.rejected),
      ]) {
        for (final entry in rejected.entries) {
          counts.update(
            entry.key,
            (n) => n + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }
    }
    return Map.unmodifiable(counts);
  }

  String get message {
    if (best != null) {
      final found = best!.requiresFileSelection
          ? query.episode != null
                ? 'Found a season pack. Check its files for the requested episode.'
                : 'Found a season pack. Check its files before playback.'
          : 'Found ${candidates.length} matching torrents.';
      return failures.isEmpty
          ? found
          : '$found Some sources could not be searched.';
    }
    if (attempts.isNotEmpty &&
        attempts.every(
          (a) => a.sources.every(
            (s) => s.status == SourceSearchStatus.unsupported,
          ),
        )) {
      return 'No configured source supports this request.';
    }
    if (status == TorrentResolutionStatus.unavailable) {
      return 'No eligible torrent was found. Some sources could not be searched.';
    }
    if (rejectionCounts.isNotEmpty) {
      return 'Searches completed, but releases did not match the request or preferences.';
    }
    return 'Searches completed without matching releases.';
  }

  List<String> get recoverySuggestions {
    if (best != null) return const [];
    final counts = rejectionCounts;
    return List.unmodifiable([
      if (attempts.isNotEmpty &&
          attempts.every(
            (a) => a.sources.every(
              (s) => s.status == SourceSearchStatus.unsupported,
            ),
          ))
        'Enable a source that supports this request.',
      if (failures.isNotEmpty) 'Retry the failed sources later.',
      if (counts.containsKey(TorrentRejection.languageUnconfirmed))
        'Try another allowed language, or remove the language restriction.',
      if (counts.containsKey(TorrentRejection.sizeLimit))
        'Increase the maximum torrent size.',
      if (counts.containsKey(TorrentRejection.insufficientSeeders))
        'Lower the minimum seeder count.',
      if (counts.containsKey(TorrentRejection.resolutionMismatch) ||
          counts.containsKey(TorrentRejection.unknownResolution))
        'Allow other or unknown resolutions.',
      if (query.episode != null &&
          !attempts.any((a) => a.stage == TorrentResolutionStage.seasonPack))
        'Try season-pack fallback and inspect the files for this episode.',
      if (counts.containsKey(TorrentRejection.titleMismatch))
        'Check the title or use an alternate title.',
      if (counts.containsKey(TorrentRejection.seasonMismatch) ||
          counts.containsKey(TorrentRejection.episodeMismatch))
        'Check the season and episode numbers.',
      if (counts.containsKey(TorrentRejection.yearMismatch))
        'Check the release year.',
    ]);
  }

  /// Failures make an empty result inconclusive, even if another source worked.
  TorrentResolutionStatus get status => candidates.isNotEmpty
      ? TorrentResolutionStatus.resolved
      : failures.isNotEmpty ||
            (attempts.isNotEmpty &&
                attempts.every(
                  (a) => a.sources.every(
                    (s) => s.status == SourceSearchStatus.unsupported,
                  ),
                ))
      ? TorrentResolutionStatus.unavailable
      : TorrentResolutionStatus.noMatch;
}
