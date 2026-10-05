import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import 'models.dart';
import 'diagnostics.dart';
import 'sources/bitsearch.dart';
import 'sources/pirate_bay.dart';
import 'sources/source.dart';
import 'sources/yts.dart';

final _log = Logger('sentorr.torrents');

class TorrentRepository {
  TorrentRepository(Iterable<TorrentSource> sources, {this.beforeSearch})
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
  final Future<void> Function()? beforeSearch;

  Future<TorrentSearchResult> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) async {
    await beforeSearch?.call();
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    final clock = Stopwatch()..start();
    final batches = await Future.wait(
      sources.map((source) async {
        if (!source.supports(query)) {
          return TorrentSearchResult(
            [],
            [],
            diagnostics: [
              SourceSearchDiagnostics(
                source: source.id,
                status: SourceSearchStatus.unsupported,
              ),
            ],
          );
        }
        final rejected = <TorrentRejection, int>{};
        SourceFailure? failure;
        try {
          final releases = source is DiagnosticTorrentSource
              ? await source.searchWithDiagnostics(
                  query,
                  cancelToken: cancelToken,
                  onRejected: (reason) =>
                      rejected.update(reason, (n) => n + 1, ifAbsent: () => 1),
                )
              : await source.search(query, cancelToken: cancelToken);
          _log.fine(
            '${source.id.name}: ${releases.length} accepted'
            '${rejected.isEmpty ? '' : ', rejected ${describeRejections(rejected)}'} '
            'for "${query.searchText}"',
          );
          return TorrentSearchResult(
            releases,
            [],
            diagnostics: [
              SourceSearchDiagnostics(
                source: source.id,
                status: SourceSearchStatus.succeeded,
                acceptedCount: releases.length,
                rejected: rejected,
              ),
            ],
          );
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) rethrow;
          failure = SourceFailure(
            source.id,
            error.response == null
                ? 'Network ${error.type.name}'
                : 'HTTP ${error.response!.statusCode}',
            searchText: query.searchText,
          );
        } on SourceException catch (error) {
          failure = SourceFailure(
            source.id,
            error.message,
            searchText: query.searchText,
          );
        }
        _log.warning(
          '${source.id.name} failed for "${query.searchText}": '
          '${failure.message}',
        );
        return TorrentSearchResult(
          [],
          [failure],
          diagnostics: [
            SourceSearchDiagnostics(
              source: source.id,
              status: SourceSearchStatus.failed,
              failure: failure,
            ),
          ],
        );
      }),
    );
    if (cancelToken?.isCancelled ?? false) {
      throw cancelToken!.cancelError!;
    }
    final byHash = <String, TorrentRelease>{};
    for (final release in batches.expand((b) => b.releases)) {
      final previous = byHash[release.infoHash];
      byHash[release.infoHash] = previous?.merge(release) ?? release;
    }
    final releases = byHash.values.toList()
      ..sort((a, b) {
        final seedOrder = b.seeders.compareTo(a.seeders);
        return seedOrder == 0 ? a.infoHash.compareTo(b.infoHash) : seedOrder;
      });
    _log.info(
      'Searched "${query.searchText}": ${releases.length} releases from '
      '${sources.where((s) => s.supports(query)).length} sources '
      'in ${clock.elapsedMilliseconds}ms',
    );
    return TorrentSearchResult(
      releases,
      batches.expand((b) => b.failures),
      diagnostics: batches.expand((b) => b.diagnostics),
    );
  }
}
