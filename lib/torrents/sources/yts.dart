import 'package:dio/dio.dart';

import '../models.dart';
import '../parsing.dart';
import 'source.dart';

class YtsSource implements TorrentSource {
  YtsSource(
    Dio dio, {
    this.endpoint = 'https://movies-api.accel.li/api/v2/list_movies.json',
  }) : client = SourceClient(dio);
  final SourceClient client;
  final String endpoint;
  @override
  TorrentSourceId get id => TorrentSourceId.yts;
  @override
  bool supports(TorrentQuery query) => !query.isSeries && query.imdbId != null;
  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async {
    if (!supports(query)) return [];
    final json = await client.get(
      Uri.parse(
        endpoint,
      ).replace(queryParameters: {'query_term': query.imdbId!, 'limit': '50'}),
      cancelToken: cancelToken,
    );
    if (json is! Map || json['status'] != 'ok' || json['data'] is! Map) {
      throw const SourceException('Unexpected YTS response');
    }
    final data = json['data'] as Map;
    final movies = data['movies'];
    if (movies == null && integer(data['movie_count']) == 0) return [];
    if (movies is! List) throw const SourceException('Missing YTS movies');
    final results = <TorrentRelease>[];
    for (final movie in movies.whereType<Map>()) {
      if (movie['imdb_code'] != query.imdbId ||
          (query.year != null && integer(movie['year']) != query.year)) {
        continue;
      }
      if (query.languages.isNotEmpty &&
          !query.languages.any(
            (l) =>
                normalizeLanguage(l) ==
                normalizeLanguage('${movie['language']}'),
          )) {
        continue;
      }
      final torrents = movie['torrents'];
      if (torrents is! List) continue;
      for (final row in torrents.whereType<Map>()) {
        final hash = infoHash(row['hash']);
        final seeds = integer(row['seeds']), size = integer(row['size_bytes']);
        if (hash == null ||
            seeds == null ||
            seeds <= 0 ||
            size == null ||
            size <= 0) {
          continue;
        }
        final name =
            '${movie['title'] ?? query.title} (${movie['year']}) ${row['quality']} ${row['type'] ?? ''}';
        results.add(
          TorrentRelease(
            source: id,
            name: name,
            infoHash: hash,
            magnet: magnetFor(hash, name),
            seeders: seeds,
            sizeBytes: size,
            resolution: resolutionOf('${row['quality']}'),
            uploadedAt: unixDate(row['date_uploaded_unix']),
          ),
        );
      }
    }
    return results;
  }
}
