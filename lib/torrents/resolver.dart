import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'models.dart';
import 'diagnostics.dart';
import 'parsing.dart';
import 'repository.dart';
import 'resolution_models.dart';

/// Resolves video search intent to ranked magnets; does not start transfers.
/// Source adapters own identity validation, including provider-attested IMDb IDs.
class TorrentResolver {
  TorrentResolver(this.repository);
  final TorrentRepository repository;

  Future<TorrentResolution> resolve(
    TorrentQuery query, {
    TorrentPreferences? preferences,
    CancelToken? cancelToken,
  }) async {
    final prefs = preferences ?? TorrentPreferences();
    final attempts = <TorrentResolutionAttempt>[];
    final failures = <SourceFailure>[];
    var candidates = <TorrentCandidate>[];
    var allSourcesFailed = false;

    Future<void> search(
      TorrentQuery intent,
      TorrentResolutionStage stage,
    ) async {
      final result = await repository.search(intent, cancelToken: cancelToken);
      final rejected = <TorrentRejection, int>{};
      candidates = rank(
        result.releases,
        prefs,
        onRejected: (reason) =>
            rejected.update(reason, (n) => n + 1, ifAbsent: () => 1),
      );
      failures.addAll(result.failures);
      attempts.add(
        TorrentResolutionAttempt(
          query: intent,
          stage: stage,
          releaseCount: result.releases.length,
          eligibleCount: candidates.length,
          failures: result.failures,
          sources: result.diagnostics,
          preferenceRejections: rejected,
        ),
      );
      final supported = repository.sources
          .where((s) => s.supports(intent))
          .length;
      allSourcesFailed = supported == 0 || result.failures.length == supported;
    }

    Future<void> searchVariants(
      TorrentQuery intent,
      TorrentResolutionStage stage,
    ) async {
      await search(intent, stage);
      if (!prefs.allowAlternateSearchFallback || !intent.isSeries) return;
      final seen = {intent.searchText};
      for (final style in TorrentSearchStyle.values) {
        if (candidates.isNotEmpty || allSourcesFailed) break;
        final variant = intent.withSearchStyle(style);
        if (!seen.add(variant.searchText)) continue;
        await search(
          variant,
          stage == TorrentResolutionStage.seasonPack
              ? stage
              : TorrentResolutionStage.alternate,
        );
      }
    }

    await searchVariants(query, TorrentResolutionStage.primary);
    if (candidates.isEmpty &&
        !allSourcesFailed &&
        query.episode != null &&
        prefs.allowSeasonPackFallback) {
      await searchVariants(
        TorrentQuery(
          title: query.title,
          imdbId: query.imdbId,
          year: query.year,
          season: query.season,
          languages: query.languages,
        ),
        TorrentResolutionStage.seasonPack,
      );
    }
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    return TorrentResolution(
      query: query,
      candidates: candidates,
      failures: failures,
      attempts: attempts,
    );
  }

  /// Fixed scales keep scores stable when unrelated candidates are added.
  /// Quality and capped availability dominate; size is a small tiebreaker.
  static List<TorrentCandidate> rank(
    Iterable<TorrentRelease> releases,
    TorrentPreferences preferences, {
    void Function(TorrentRejection)? onRejected,
  }) {
    final candidates = <TorrentCandidate>[];
    for (final release in releases) {
      final rejection = _preferenceRejection(release, preferences);
      if (rejection != null) {
        onRejected?.call(rejection);
        continue;
      }
      final quality = release.resolution == null
          ? 0.0
          : math.min(release.resolution!, preferences.preferredResolution) /
                math.max(release.resolution!, preferences.preferredResolution);
      final availability =
          math.log(1 + math.min(release.seeders, 100)) / math.log(101);
      final size = 1 / (1 + release.sizeBytes / (4 * 1024 * 1024 * 1024));
      candidates.add(
        TorrentCandidate(
          release: release,
          score: .55 * quality + .40 * availability + .05 * size,
          qualityScore: quality,
          availabilityScore: availability,
          sizeScore: size,
          requiresFileSelection: release.isSeasonPack,
        ),
      );
    }
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final seeds = b.release.seeders.compareTo(a.release.seeders);
      if (seeds != 0) return seeds;
      return a.release.infoHash.compareTo(b.release.infoHash);
    });
    return List.unmodifiable(candidates);
  }

  static TorrentRejection? _preferenceRejection(
    TorrentRelease release,
    TorrentPreferences prefs,
  ) {
    if (release.sizeBytes <= 0 ||
        (release.resolution != null && release.resolution! <= 0)) {
      return TorrentRejection.invalidMetadata;
    }
    if (infoHash(release.infoHash) == null ||
        magnetHash(release.magnet) != infoHash(release.infoHash)) {
      return TorrentRejection.invalidMagnet;
    }
    if (release.seeders < prefs.minimumSeeders) {
      return TorrentRejection.insufficientSeeders;
    }
    if (prefs.maximumSizeBytes != null &&
        release.sizeBytes > prefs.maximumSizeBytes!) {
      return TorrentRejection.sizeLimit;
    }
    if (release.resolution == null && !prefs.allowUnknownResolution) {
      return TorrentRejection.unknownResolution;
    }
    if (!prefs.allowResolutionFallback &&
        release.resolution != prefs.preferredResolution) {
      return TorrentRejection.resolutionMismatch;
    }
    return null;
  }
}
