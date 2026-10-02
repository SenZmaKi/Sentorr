import 'dart:convert';
import 'dart:io';

import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolver.dart';

/// Live metadata resolution only. No torrent metadata or media is downloaded.
Future<void> main(List<String> args) async {
  final query = TorrentQuery(
    title: args.isEmpty ? 'Big Buck Bunny' : args[0],
    imdbId: args.length > 1 && args[1] != '-'
        ? args[1]
        : args.isEmpty
        ? 'tt1254207'
        : null,
    season: args.length > 2 ? int.parse(args[2]) : null,
    episode: args.length > 3 && args[3] != '-' ? int.parse(args[3]) : null,
    year: args.length > 4 ? int.parse(args[4]) : null,
  );
  final network = NetworkClient(logging: false);
  try {
    final result = await TorrentResolver(
      TorrentRepository.defaults(network.dio),
    ).resolve(query);
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'query': query.searchText,
        'status': result.status.name,
        'message': result.message,
        'recoverySuggestions': result.recoverySuggestions,
        'rejections': {
          for (final e in result.rejectionCounts.entries) e.key.name: e.value,
        },
        'attempts': result.attempts
            .map(
              (a) => {
                'search': a.query.searchText,
                'stage': a.stage.name,
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
              },
            )
            .toList(),
        'candidates': result.candidates
            .map(
              (candidate) => {
                'source': candidate.release.source.name,
                'name': candidate.release.name,
                'resolution': candidate.release.resolution,
                'seeders': candidate.release.seeders,
                'score': candidate.score,
                'requiresFileSelection': candidate.requiresFileSelection,
              },
            )
            .toList(),
        'failures': result.failures
            .map(
              (failure) => {
                'source': failure.source.name,
                'message': failure.message,
              },
            )
            .toList(),
      }),
    );
    if (result.best == null) exitCode = 1;
  } finally {
    await network.close();
  }
}
