import 'package:dio/dio.dart';

import 'models.dart';
import 'sources/bitsearch.dart';
import 'sources/pirate_bay.dart';
import 'sources/source.dart';
import 'sources/yts.dart';

class TorrentRepository {
  TorrentRepository(Iterable<TorrentSource> sources)
    : sources = List.unmodifiable(sources) {
    if (this.sources.map((s) => s.id).toSet().length != this.sources.length) {
      throw ArgumentError('Duplicate source identifiers');
    }
  }
  factory TorrentRepository.defaults(Dio dio) => TorrentRepository([
    PirateBaySource(dio),
    YtsSource(dio),
    BitsearchSource(dio),
  ]);
  final List<TorrentSource> sources;

  Future<TorrentSearchResult> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async {
    final batches = await Future.wait(
      sources.where((s) => s.supports(query)).map((source) async {
        try {
          final releases = await source.search(query, cancelToken: cancelToken);
          return TorrentSearchResult(releases, []);
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) rethrow;
          return TorrentSearchResult([], [
            SourceFailure(
              source.id,
              error.response == null
                  ? 'Network ${error.type.name}'
                  : 'HTTP ${error.response!.statusCode}',
            ),
          ]);
        } on SourceException catch (error) {
          return TorrentSearchResult([], [
            SourceFailure(source.id, error.message),
          ]);
        }
      }),
    );
    if (cancelToken?.isCancelled ?? false) {
      throw cancelToken!.cancelError!;
    }
    final byHash = <String, TorrentRelease>{};
    for (final release in batches.expand((b) => b.releases)) {
      final previous = byHash[release.infoHash];
      if (previous == null || release.seeders > previous.seeders) {
        byHash[release.infoHash] = release;
      }
    }
    final releases = byHash.values.toList()
      ..sort((a, b) {
        final seedOrder = b.seeders.compareTo(a.seeders);
        return seedOrder == 0 ? a.infoHash.compareTo(b.infoHash) : seedOrder;
      });
    return TorrentSearchResult(releases, batches.expand((b) => b.failures));
  }
}
