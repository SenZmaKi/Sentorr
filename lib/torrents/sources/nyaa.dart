import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import '../diagnostics.dart';
import '../models.dart';
import '../parsing.dart';
import 'source.dart';
import 'specialized_source.dart';

/// Nyaa supplements general indexes for titles catalogued as Animation.
/// English-translated anime is the same category used by Senpwai.
class NyaaSource extends SpecializedTorrentSource {
  NyaaSource(
    Dio dio, {
    this.endpointResolver,
    String endpoint = 'https://nyaa.si/',
    // ignore: prefer_initializing_formals
  }) : _endpoint = endpoint,
       client = SourceClient(dio);

  static final _requests = SourceRequestGate(5);
  final SourceClient client;
  final String _endpoint;
  final String Function()? endpointResolver;
  String get endpoint => endpointResolver?.call() ?? _endpoint;

  @override
  TorrentSourceId get id => TorrentSourceId.nyaa;

  @override
  bool appliesTo(TorrentQuery query) => query.hasGenre('Animation');

  @override
  Future<List<TorrentRelease>> searchWithDiagnostics(
    TorrentQuery query, {
    CancelToken? cancelToken,
    required void Function(TorrentRejection) onRejected,
  }) async {
    if (!supports(query)) return [];
    final page = await _requests.run(
      () => client.get(
        Uri.parse(endpoint).replace(
          queryParameters: {
            'q': query.searchText,
            'c': '1_2',
            's': 'seeders',
            'o': 'desc',
            'p': '1',
          },
        ),
        cancelToken: cancelToken,
        html: true,
        isResult: (body) =>
            html.parse('$body').querySelector('table.torrent-list') != null,
      ),
      cancelToken,
    );
    final table = html.parse('$page').querySelector('table.torrent-list');
    if (table == null) {
      throw const SourceException('Unrecognized Nyaa search page');
    }
    final releases = <TorrentRelease>[];
    for (final row in table.querySelectorAll('tbody tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 8) {
        onRejected(TorrentRejection.invalidMetadata);
        continue;
      }
      if (cells[0].querySelector('a')?.attributes['title'] !=
          'Anime - English-translated') {
        onRejected(TorrentRejection.nonVideo);
        continue;
      }
      // Comment links follow the title on some rows; select by href.
      final name = cells[1]
          .querySelectorAll('a[href^="/view/"]')
          .where((a) => !(a.attributes['href'] ?? '').contains('#'))
          .firstOrNull
          ?.text
          .trim();
      final magnet = Uri.tryParse(
        cells[2].querySelector('a[href^="magnet:"]')?.attributes['href'] ?? '',
      );
      final hash = magnetHash(magnet);
      final size = parseSize(cells[3].text.trim());
      final seeds = integer(cells[5].text.trim());
      if (name == null ||
          name.isEmpty ||
          hash == null ||
          size == null ||
          size <= 0 ||
          seeds == null) {
        onRejected(TorrentRejection.invalidMetadata);
        continue;
      }
      if (seeds <= 0) {
        onRejected(TorrentRejection.noSeeders);
        continue;
      }
      // IMDb season numbering cannot safely be inferred from an absolute
      // anime episode number. Keep the shared conservative identity checks.
      final rejection = releaseRejection(query, name);
      if (rejection != null) {
        onRejected(rejection);
        continue;
      }
      releases.add(
        TorrentRelease(
          source: id,
          name: name,
          infoHash: hash,
          magnet: magnet!,
          torrentUrls: [
            ?torrentHttpUrl(
              cells[2]
                  .querySelector('a[href*="/download/"]')
                  ?.attributes['href'],
              Uri.parse(endpoint),
            ),
          ],
          seeders: seeds,
          sizeBytes: size,
          uploadedAt: unixDate(cells[4].attributes['data-timestamp']),
          resolution: resolutionOf(name),
          isSeasonPack: query.isSeasonPack,
          isSeriesPack: query.searchSeriesPacks,
        ),
      );
    }
    return releases;
  }
}
