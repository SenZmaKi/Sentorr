import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import '../models.dart';
import '../parsing.dart';
import 'source.dart';

/// Bitsearch metadata search. No scripts or download links run.
class BitsearchSource implements TorrentSource {
  BitsearchSource(Dio dio, {this.endpoint = 'https://bitsearch.eu/search'})
    : client = SourceClient(dio);
  final SourceClient client;
  final String endpoint;
  @override
  TorrentSourceId get id => TorrentSourceId.bitsearch;
  @override
  bool supports(TorrentQuery query) => true;
  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async {
    final page = await client.get(
      Uri.parse(endpoint)
          .replace(queryParameters: {'q': query.searchText, 'sort': 'seeders'}),
      cancelToken: cancelToken,
      html: true,
    );
    final doc = html.parse('$page');
    final container = doc.querySelector('[data-impression-ids]');
    if (container == null) {
      // A challenge/layout change must not be reported as an empty search.
      throw const SourceException('Unrecognized Bitsearch search page');
    }
    final results = <TorrentRelease>[];
    for (final card in container.children) {
      final name = card.querySelector('h3 a[href^="/torrent/"]')?.text.trim();
      final uri = Uri.tryParse(
        card.querySelector('a[href^="magnet:"]')?.attributes['href'] ?? '',
      );
      final hash = magnetHash(uri);
      final sizeText = card
          .querySelector('.fa-download')
          ?.parent
          ?.querySelector('span')
          ?.text
          .trim();
      final category = card
          .querySelector('.fa-download')
          ?.parent
          ?.parent
          ?.children
          .first
          .text
          .trim()
          .toLowerCase();
      final seeds = integer(
        card
            .querySelector('.fa-arrow-up')
            ?.parent
            ?.querySelector('span')
            ?.text
            .trim(),
      );
      final size = parseSize(sizeText ?? '');
      if (name == null ||
          hash == null ||
          seeds == null ||
          seeds <= 0 ||
          size == null ||
          size <= 0 ||
          category == null ||
          !{
            'movies',
            'tv',
            'other/video',
            'video',
            'anime',
          }.contains(category)) {
        continue;
      }
      if (!matchesRelease(query, name)) continue;
      // Site dates are locale-ambiguous; unknown is more honest than guessing UTC.
      results.add(
        TorrentRelease(
          source: id,
          name: name,
          infoHash: hash,
          magnet: uri!,
          seeders: seeds,
          sizeBytes: size,
          resolution: resolutionOf(name),
          isSeasonPack: query.isSeasonPack,
        ),
      );
    }
    return results;
  }
}
