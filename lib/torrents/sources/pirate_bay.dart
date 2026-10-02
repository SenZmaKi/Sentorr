import 'package:dio/dio.dart';

import '../models.dart';
import '../parsing.dart';
import 'source.dart';

class PirateBaySource implements TorrentSource {
  PirateBaySource(Dio dio, {this.endpoint = 'https://apibay.org/q.php'})
    : client = SourceClient(dio);
  final SourceClient client;
  final String endpoint;
  @override
  TorrentSourceId get id => TorrentSourceId.pirateBay;
  @override
  bool supports(TorrentQuery query) => true;
  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async {
    final data = await client.get(
      Uri.parse(endpoint)
          .replace(queryParameters: {'q': query.searchText, 'cat': '200'}),
      cancelToken: cancelToken,
    );
    if (data is! List) {
      throw const SourceException('Unexpected Pirate Bay response');
    }
    final results = <TorrentRelease>[];
    for (final row in data.whereType<Map>()) {
      final category = integer(row['category']);
      final hash = infoHash(row['info_hash']);
      final name = row['name'];
      final seeds = integer(row['seeders']), size = integer(row['size']);
      if (category == null ||
          category < 200 ||
          category >= 300 ||
          hash == null ||
          name is! String ||
          seeds == null ||
          seeds <= 0 ||
          size == null ||
          size <= 0) {
        continue;
      }
      final imdb = row['imdb'];
      final knownIdentity =
          imdb is String &&
          imdb.isNotEmpty &&
          (imdb == query.imdbId || imdb == query.episodeImdbId);
      if (imdb is String &&
          imdb.isNotEmpty &&
          query.imdbId != null &&
          !knownIdentity) {
        continue;
      }
      if (!matchesRelease(query, name, trustedIdentity: knownIdentity)) {
        continue;
      }
      results.add(
        TorrentRelease(
          source: id,
          name: name,
          infoHash: hash,
          magnet: magnetFor(hash, name),
          seeders: seeds,
          sizeBytes: size,
          resolution: resolutionOf(name),
          uploadedAt: unixDate(row['added']),
          isSeasonPack: query.isSeasonPack,
        ),
      );
    }
    return results;
  }
}
