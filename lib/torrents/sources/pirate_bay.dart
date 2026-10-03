import 'package:dio/dio.dart';

import '../models.dart';
import '../diagnostics.dart';
import '../parsing.dart';
import 'source.dart';

class PirateBaySource implements DiagnosticTorrentSource {
  PirateBaySource(
    Dio dio, {
    this.endpointResolver,
    String endpoint = 'https://apibay.org/q.php',
    // ignore: prefer_initializing_formals
  }) : _endpoint = endpoint,
       client = SourceClient(dio);
  final SourceClient client;
  final String _endpoint;
  final String Function()? endpointResolver;
  String get endpoint => endpointResolver?.call() ?? _endpoint;
  @override
  TorrentSourceId get id => TorrentSourceId.pirateBay;
  @override
  bool supports(TorrentQuery query) => true;
  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async => searchWithDiagnostics(
    query,
    cancelToken: cancelToken,
    onRejected: (_) {},
  );

  @override
  Future<List<TorrentRelease>> searchWithDiagnostics(
    TorrentQuery query, {
    CancelToken? cancelToken,
    required void Function(TorrentRejection) onRejected,
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
    for (final row in data) {
      if (row is! Map) {
        onRejected(TorrentRejection.invalidMetadata);
        continue;
      }
      if (row['name'] == 'No results returned' &&
          row['info_hash'] == '0' * 40) {
        continue;
      }
      final category = integer(row['category']);
      final hash = infoHash(row['info_hash']);
      final name = row['name'];
      final seeds = integer(row['seeders']), size = integer(row['size']);
      if (category == null ||
          hash == null ||
          name is! String ||
          seeds == null ||
          size == null ||
          size <= 0) {
        onRejected(TorrentRejection.invalidMetadata);
        continue;
      }
      if (category < 200 || category >= 300) {
        onRejected(TorrentRejection.nonVideo);
        continue;
      }
      if (seeds <= 0) {
        onRejected(TorrentRejection.noSeeders);
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
        onRejected(TorrentRejection.identityMismatch);
        continue;
      }
      final rejection = releaseRejection(
        query,
        name,
        trustedIdentity: knownIdentity,
      );
      if (rejection != null) {
        onRejected(rejection);
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
          isSeriesPack: query.searchSeriesPacks,
        ),
      );
    }
    return results;
  }
}
