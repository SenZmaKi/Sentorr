import 'dart:convert';
import 'dart:io';

import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';

/// Metadata-only proof of episode/season/finished-series batch competition.
Future<void> main() async {
  final network = NetworkClient(logging: false);
  try {
    final result =
        await TorrentResolver(TorrentRepository.defaults(network.dio)).resolve(
          TorrentQuery(
            title: 'Breaking Bad',
            imdbId: 'tt0903747',
            year: 2008,
            season: 2,
            episode: 3,
            seriesEnded: true,
          ),
          preferences: TorrentPreferences(includeBatchCandidates: true),
        );
    final report = {
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': 'Metadata ranking only; does not open magnets or download media',
      'query': result.query.searchText,
      'status': result.status.name,
      'message': result.message,
      'candidates': result.candidates
          .map(
            (c) => {
              'name': c.release.name,
              'source': c.release.source.name,
              'seeders': c.release.seeders,
              'bytes': c.release.sizeBytes,
              'resolution': c.release.resolution,
              'score': c.score,
              'seasonPack': c.release.isSeasonPack,
              'seriesPack': c.release.isSeriesPack,
              'requiresFileSelection': c.requiresFileSelection,
            },
          )
          .toList(),
      'attempts': result.attempts
          .map(
            (a) => {
              'stage': a.stage.name,
              'search': a.query.searchText,
              'releases': a.releaseCount,
              'eligible': a.eligibleCount,
              'sources': a.sources
                  .map(
                    (s) => {
                      'source': s.source.name,
                      'status': s.status.name,
                      'accepted': s.acceptedCount,
                      'rejections': {
                        for (final e in s.rejected.entries) e.key.name: e.value,
                      },
                      if (s.failure != null) 'failure': s.failure!.message,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    const path = 'docs/Torrent/batch-live-validation.json';
    await File(
      path,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
    stdout.writeln(
      '${result.status.name}: ${result.candidates.length} candidates; '
      '${result.candidates.where((c) => c.release.isSeasonPack).length} season packs; '
      '${result.candidates.where((c) => c.release.isSeriesPack).length} series batches; '
      '${result.failures.length} failures',
    );
    stdout.writeln('Best: ${result.best?.release.name}');
    stdout.writeln('Saved $path');
  } finally {
    await network.close();
  }
}
