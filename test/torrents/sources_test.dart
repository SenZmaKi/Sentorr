import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/sources/bitsearch.dart';
import 'package:sentorr/torrents/sources/pirate_bay.dart';
import 'package:sentorr/torrents/sources/yts.dart';
import 'package:test/test.dart';

const hash = '0123456789abcdef0123456789abcdef01234567';
Map<String, Object?> pirate({
  String name = 'Big.Buck.Bunny.2008.1080p',
  String hashValue = hash,
  Object seeds = '3',
}) => {
  'name': name,
  'info_hash': hashValue,
  'seeders': seeds,
  'size': '1234567',
  'category': '207',
  'added': '1234567890',
};

void main() {
  late Dio dio;
  late Object? payload;
  late List<RequestOptions> requests;
  setUp(() {
    payload = [];
    requests = [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: payload),
            );
          },
        ),
      );
  });
  tearDown(() => dio.close(force: true));
  final movie = TorrentQuery(title: 'Big Buck Bunny', year: 2008);

  test(
    'repository deduplicates across sources rather than by resolution',
    () async {
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            final Object body = o.uri.host == 'apibay.org'
                ? [pirate(seeds: '2')]
                : {
                    'status': 'ok',
                    'data': {
                      'movies': [
                        {
                          'imdb_code': 'tt1254207',
                          'year': 2008,
                          'torrents': [
                            {
                              'hash': hash.toUpperCase(),
                              'url': 'https://yts.example/download/$hash',
                              'seeds': 8,
                              'size_bytes': 500,
                              'quality': '720p',
                            },
                          ],
                        },
                      ],
                    },
                  };
            h.resolve(Response(requestOptions: o, statusCode: 200, data: body));
          },
        ),
      );
      final result = await TorrentRepository([
        PirateBaySource(dio),
        YtsSource(dio),
      ]).search(TorrentQuery(title: movie.title, imdbId: 'tt1254207'));
      expect(result.failures, isEmpty);
      expect(result.releases, hasLength(1));
      expect(result.releases.single.source, TorrentSourceId.yts);
      expect(result.releases.single.seeders, 8);
      expect(
        result.releases.single.torrentUrls,
        contains(Uri.parse('https://yts.example/download/$hash')),
      );
    },
  );

  test('Bitsearch categories do not depend on a video icon', () async {
    payload = File('test/torrents/fixtures/bitsearch.html')
        .readAsStringSync()
        .replaceAll('fa-video', 'fa-file')
        .replaceAll('Other/Video', 'Movies');
    expect(await BitsearchSource(dio).search(movie), isNotEmpty);
    payload = (payload as String).replaceAll('Movies', 'XXX');
    expect(await BitsearchSource(dio).search(movie), isEmpty);
  });

  test(
    'Pirate Bay filters invalid rows without discarding valid releases',
    () async {
      payload = [
        pirate(),
        pirate(name: 'Unrelated.2008.1080p'),
        pirate(hashValue: '0' * 40),
        pirate(seeds: '-1'),
        {...pirate(), 'category': '500'},
        {...pirate(), 'size': 'NaN'},
        {...pirate(), 'added': 'bad'},
      ];
      final releases = await PirateBaySource(dio).search(movie);
      expect(releases, hasLength(2));
      expect(releases.first.infoHash, hash);
      expect(releases.last.uploadedAt, isNull);
      expect(releases.first.uploadedAt!.isUtc, isTrue);
      expect(requests.single.uri.queryParameters['cat'], '200');
    },
  );
  test(
    'Pirate Bay no-results sentinel is empty, invalid response is failure',
    () async {
      payload = [
        {'name': 'No results returned', 'info_hash': '0' * 40},
      ];
      expect(await PirateBaySource(dio).search(movie), isEmpty);
      payload = '<html>Challenge</html>';
      expect(
        PirateBaySource(dio).search(movie),
        throwsA(isA<SourceException>()),
      );
    },
  );
  test(
    'Pirate Bay IMDb mismatch fails and matching IMDb still checks episode',
    () async {
      final query = TorrentQuery(
        title: 'Example Show',
        imdbId: 'tt123',
        season: 2,
        episode: 3,
      );
      payload = [
        {...pirate(name: 'Alternate.Title.S02E03.1080p'), 'imdb': 'tt123'},
        {...pirate(name: 'Example.Show.S02E03.1080p'), 'imdb': 'tt999'},
        {...pirate(name: 'Alternate.Title.S01E03.1080p'), 'imdb': 'tt123'},
      ];
      expect(await PirateBaySource(dio).search(query), hasLength(1));
    },
  );
  test(
    'search text is encoded as a parameter rather than interpolated URL',
    () async {
      await PirateBaySource(dio).search(TorrentQuery(title: 'A & B # C'));
      expect(requests.single.uri.queryParameters['q'], 'A & B # C');
    },
  );
  test(
    'YTS filters by IMDb and produces a magnet from the hash, not download URL',
    () async {
      payload = {
        'status': 'ok',
        'data': {
          'movies': [
            {'imdb_code': 'tt999', 'torrents': []},
            {
              'imdb_code': 'tt1254207',
              'title': 'Big Buck Bunny',
              'year': 2008,
              'language': 'en',
              'torrents': [
                {
                  'hash': hash,
                  'seeds': 2,
                  'size_bytes': 100,
                  'quality': '1080p',
                  'date_uploaded_unix': 1234567890,
                  'url': 'https://untrusted.example/torrent',
                },
                {'hash': hash, 'seeds': 0, 'size_bytes': 100},
                {'hash': 'bad', 'seeds': 2, 'size_bytes': 100},
              ],
            },
          ],
        },
      };
      final releases = await YtsSource(dio).search(
        TorrentQuery(title: movie.title, imdbId: 'tt1254207', year: 2008),
      );
      expect(releases, hasLength(1));
      expect(releases.single.magnet.scheme, 'magnet');
      expect(releases.single.resolution, 1080);
      expect(requests.single.uri.host, 'movies-api.accel.li');
    },
  );
  test('YTS skips unsupported intent without HTTP requests', () async {
    expect(
      await YtsSource(dio)
          .search(TorrentQuery(title: 'Title', season: 1, imdbId: 'tt123')),
      isEmpty,
    );
    expect(await YtsSource(dio).search(movie), isEmpty);
    expect(requests, isEmpty);
  });
  test('YTS empty result and broken schema are distinguishable', () async {
    final query = TorrentQuery(title: movie.title, imdbId: 'tt1254207');
    payload = {
      'status': 'ok',
      'data': {'movie_count': 0},
    };
    expect(await YtsSource(dio).search(query), isEmpty);
    payload = {'status': 'ok', 'data': {}};
    expect(YtsSource(dio).search(query), throwsA(isA<SourceException>()));
    payload = {
      'status': 'error',
      'data': {'movie_count': 0},
    };
    expect(YtsSource(dio).search(query), throwsA(isA<SourceException>()));
  });
  test('current Bitsearch captured HTML parses title, stats, entities and duplicate links', () async {
    payload = File('test/torrents/fixtures/bitsearch.html').readAsStringSync();
    final releases = await BitsearchSource(dio).search(movie);
    expect(releases, isNotEmpty);
    expect(releases.first.name, 'big.buck.bunny.1080p.surround.avi');
    expect(releases.first.seeders, 2);
    expect(releases.first.sizeBytes, parseSize('885.65 MB'));
    expect(releases.first.infoHash, '68ac70b766fd6e8880cab4026a7f74ab4d04dbfd');
    expect(
      releases.first.magnet.queryParameters['xt'],
      startsWith('urn:btih:'),
    );
    expect(releases.first.uploadedAt, isNull);
    expect(
      releases.first.torrentUrls.single.toString(),
      startsWith('https://bitsearch.eu/download/torrent/68AC70'),
    );
  });
  test(
    'Bitsearch empty search container is success; challenge is failure',
    () async {
      payload = '<div data-impression-ids="[]"></div>';
      expect(await BitsearchSource(dio).search(movie), isEmpty);
      payload = '<html>Just a moment...</html>';
      expect(
        BitsearchSource(dio).search(movie),
        throwsA(isA<SourceException>()),
      );
    },
  );
  test('repository returns partial success, deduplicates hash, preserves strongest swarm', () async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (o.uri.host == 'bitsearch.eu') {
            h.reject(
              DioException(
                requestOptions: o,
                response: Response(requestOptions: o, statusCode: 403),
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: [
                  pirate(seeds: '2'),
                  pirate(seeds: '8'),
                ],
              ),
            );
          }
        },
      ),
    );
    final result = await TorrentRepository.defaults(dio).search(movie);
    expect(result.releases, hasLength(1));
    expect(result.releases.single.seeders, 8);
    expect(result.failures.single.source, TorrentSourceId.bitsearch);
    expect(result.failures.single.message, 'HTTP 403');
  });
  test(
    'cancellation propagates instead of turning into empty results',
    () async {
      final token = CancelToken()..cancel('test');
      expect(
        TorrentRepository.defaults(dio).search(movie, cancelToken: token),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    },
  );
}
