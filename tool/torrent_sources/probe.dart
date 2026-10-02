import 'dart:convert';
import 'dart:io';

import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/sources/bitsearch.dart';
import 'package:sentorr/torrents/sources/pirate_bay.dart';
import 'package:sentorr/torrents/sources/yts.dart';

/// Metadata-only live smoke check. Does not fetch torrents or start downloads.
Future<void> main(List<String> args) async {
  final network = NetworkClient(logging: false);
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
  try {
    final report = await Future.wait(
      [
        PirateBaySource(network.dio),
        YtsSource(network.dio),
        BitsearchSource(network.dio),
      ].map((source) async {
        final watch = Stopwatch()..start();
        try {
          if (!source.supports(query)) {
            return {'source': source.id.name, 'status': 'unsupported'};
          }
          final results = await source.search(query);
          return {
            'source': source.id.name,
            'status': 'ok',
            'matches': results.length,
            'sample': results
                .take(2)
                .map(
                  (r) => {
                    'name': r.name,
                    'seeders': r.seeders,
                    'resolution': r.resolution,
                  },
                )
                .toList(),
            'elapsedMs': watch.elapsedMilliseconds,
          };
        } catch (e) {
          return {
            'source': source.id.name,
            'status': 'failed',
            'error': '$e',
            'elapsedMs': watch.elapsedMilliseconds,
          };
        }
      }),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    if (report.any((r) => r['status'] == 'failed')) exitCode = 1;
  } finally {
    await network.close();
  }
}
