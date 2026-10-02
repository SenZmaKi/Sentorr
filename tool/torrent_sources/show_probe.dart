import 'dart:convert';
import 'dart:io';

import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';

/// Opt-in live metadata checks. No torrent files or media are fetched.
Future<void> main(List<String> args) async {
  final queries = [
    TorrentQuery(
      title: 'Breaking Bad',
      imdbId: 'tt0903747',
      season: 1,
      episode: 1,
    ),
    TorrentQuery(
      title: 'The Office',
      imdbId: 'tt0386676',
      year: 2005,
      season: 2,
      episode: 3,
    ),
    TorrentQuery(
      title: 'Chernobyl',
      imdbId: 'tt7366338',
      year: 2019,
      season: 1,
      episode: 1,
    ),
    TorrentQuery(title: 'Doctor Who', year: 2005, season: 0, episode: 1),
    TorrentQuery(
      title: 'Planet Earth',
      imdbId: 'tt0795176',
      year: 2006,
      season: 1,
    ),
    TorrentQuery(
      title: 'Breaking Bad',
      imdbId: 'tt0903747',
      season: 1,
      episode: 1,
      languages: {'en'},
    ),
  ];
  final network = NetworkClient(logging: false);
  try {
    final resolver = TorrentResolver(TorrentRepository.defaults(network.dio));
    final reports = <Map<String, Object?>>[];
    // Sequential cases keep provider load bounded and show progress per case.
    for (final query in queries) {
      final watch = Stopwatch()..start();
      final result = await resolver.resolve(
        query,
        preferences: TorrentPreferences(allowSeasonPackFallback: true),
      );
      reports.add({
        'query': query.searchText,
        'year': query.year,
        'languages': query.languages.toList(),
        'status': result.status.name,
        'message': result.message,
        'candidates': result.candidates.length,
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
                          for (final e in s.rejected.entries)
                            e.key.name: e.value,
                        },
                        if (s.failure != null) 'failure': s.failure!.message,
                      },
                    )
                    .toList(),
                'preferenceRejections': {
                  for (final e in a.preferenceRejections.entries)
                    e.key.name: e.value,
                },
              },
            )
            .toList(),
        'sample': result.candidates
            .take(3)
            .map(
              (c) => {
                'name': c.release.name,
                'source': c.release.source.name,
                'seeders': c.release.seeders,
                'bytes': c.release.sizeBytes,
                'resolution': c.release.resolution,
                'score': c.score,
                'requiresFileSelection': c.requiresFileSelection,
              },
            )
            .toList(),
        'recoverySuggestions': result.recoverySuggestions,
        'elapsedMs': watch.elapsedMilliseconds,
      });
      stdout.writeln(
        '${query.searchText} ${query.languages}: '
        '${result.status.name}, ${result.candidates.length} candidates, '
        '${result.attempts.length} attempts, ${result.failures.length} source failures',
      );
    }
    final path = args.firstOrNull ?? 'docs/Torrent/show-live-validation.json';
    await File(path).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({'checkedAt': DateTime.now().toUtc().toIso8601String(), 'scope': 'Metadata discovery, matching, ranking and diagnostics only', 'results': reports})}\n',
    );
    stdout.writeln('Saved $path');
  } finally {
    await network.close();
  }
}
