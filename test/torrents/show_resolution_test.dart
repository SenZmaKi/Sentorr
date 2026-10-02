import 'package:dio/dio.dart';
import 'package:sentorr/torrents/diagnostics.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

Map<String, Object> row(
  int id,
  String name, {
  int seeds = 10,
  int size = 1000000000,
}) => {
  'name': name,
  'info_hash': id.toRadixString(16).padLeft(40, '0'),
  'seeders': '$seeds',
  'size': '$size',
  'category': '205',
};

void main() {
  late Dio dio;
  late List<String> requests;
  late Object Function(String) response;
  setUp(() {
    requests = [];
    response = (_) => [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final term = options.uri.queryParameters['q']!;
            requests.add(term);
            if (options.uri.host == 'bitsearch.eu') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: options, statusCode: 403),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: response(term),
                ),
              );
            }
          },
        ),
      );
  });
  tearDown(() => dio.close(force: true));
  final show = TorrentQuery(
    title: 'Breaking Bad',
    year: 2008,
    season: 1,
    episode: 1,
  );
  TorrentResolver engine() => TorrentResolver(TorrentRepository.defaults(dio));

  test('full adapter path ranks only matching episodes and reports rejection causes', () async {
    response = (_) => [
      row(1, 'Breaking.Bad.2008.S01E01.1080p.English', seeds: 20),
      row(2, 'Breaking.Bad.S01E01.720p.English', seeds: 100),
      row(3, 'Breaking.Bad.S01E02.1080p.English', seeds: 1000),
      row(4, 'Breaking.Bad.S02E01.1080p.English'),
      row(5, 'Breaking.Bad.2020.S01E01.1080p.English'),
      row(6, 'Better.Call.Saul.S01E01.1080p.English'),
      row(7, 'Breaking.Bad.S01E01.1080p.French'),
      row(8, 'Breaking.Bad.S01E01.1080p.English', seeds: 0),
    ];
    final result = await engine().resolve(
      TorrentQuery(
        title: show.title,
        year: show.year,
        season: show.season,
        episode: show.episode,
        languages: {'en'},
      ),
    );
    expect(result.status, TorrentResolutionStatus.resolved);
    expect(result.candidates, hasLength(2));
    expect(result.best!.release.resolution, 1080);
    expect(result.failures.single.message, 'HTTP 403');
    expect(result.attempts, hasLength(1));
    expect(result.rejectionCounts, {
      TorrentRejection.episodeMismatch: 1,
      TorrentRejection.seasonMismatch: 1,
      TorrentRejection.yearMismatch: 1,
      TorrentRejection.titleMismatch: 1,
      TorrentRejection.languageUnconfirmed: 1,
      TorrentRejection.noSeeders: 1,
    });
    expect(
      result.attempts.single.sources
          .singleWhere((s) => s.source == TorrentSourceId.yts)
          .status,
      SourceSearchStatus.unsupported,
    );
  });

  test(
    'alternate long-form query recovers; trace retains exact failed search',
    () async {
      response = (term) => term.contains('Season')
          ? [row(1, 'Breaking Bad Season 1 Episode 1 1080p')]
          : [];
      final result = await engine().resolve(show);
      expect(result.best, isNotNull);
      expect(result.attempts.map((a) => a.query.searchText), [
        'Breaking Bad S01E01',
        'Breaking Bad Season 1 Episode 1',
      ]);
      expect(result.attempts.last.stage, TorrentResolutionStage.alternate);
      expect(result.failures.first.searchText, 'Breaking Bad S01E01');
    },
  );

  test('cross-form query recovers without changing episode identity', () async {
    response = (term) =>
        term.contains('1x01') ? [row(1, 'Breaking Bad 1x01 1080p')] : [];
    final result = await engine().resolve(show);
    expect(result.best, isNotNull);
    expect(result.attempts, hasLength(3));
    expect(result.query.episode, 1);
  });

  test(
    'fallback is bounded to three episode and two pack query forms',
    () async {
      final result = await engine().resolve(
        show,
        preferences: TorrentPreferences(allowSeasonPackFallback: true),
      );
      expect(result.attempts, hasLength(5));
      expect(
        result.attempts.map((a) => a.query.searchText).toSet(),
        hasLength(5),
      );
      expect(
        result.attempts.where(
          (a) => a.stage == TorrentResolutionStage.seasonPack,
        ),
        hasLength(2),
      );
      expect(result.status, TorrentResolutionStatus.unavailable);
    },
  );

  test(
    'preference rejection is reported and does not relax size or language',
    () async {
      response = (term) => term.contains('E01')
          ? [row(1, 'Breaking.Bad.S01E01.1080p.English', size: 3000000000)]
          : [row(2, 'Breaking.Bad.S01.Complete.1080p.French')];
      final result = await engine().resolve(
        TorrentQuery(
          title: show.title,
          season: 1,
          episode: 1,
          languages: {'en'},
        ),
        preferences: TorrentPreferences(
          maximumSizeBytes: 2000000000,
          allowSeasonPackFallback: true,
          allowAlternateSearchFallback: false,
        ),
      );
      expect(result.best, isNull);
      expect(result.rejectionCounts[TorrentRejection.sizeLimit], 1);
      expect(result.rejectionCounts[TorrentRejection.languageUnconfirmed], 1);
      expect(
        result.recoverySuggestions,
        contains('Increase the maximum torrent size.'),
      );
      expect(
        result.recoverySuggestions,
        contains(
          'Try another allowed language, or remove the language restriction.',
        ),
      );
    },
  );

  test(
    'strict resolution rejects other quality and reports recovery',
    () async {
      response = (_) => [row(1, 'Breaking.Bad.S01E01.720p')];
      final result = await engine().resolve(
        show,
        preferences: TorrentPreferences(
          allowResolutionFallback: false,
          allowAlternateSearchFallback: false,
        ),
      );
      expect(result.best, isNull);
      expect(result.rejectionCounts[TorrentRejection.resolutionMismatch], 1);
      expect(
        result.recoverySuggestions,
        contains('Allow other or unknown resolutions.'),
      );
      final relaxed = await engine().resolve(show);
      expect(relaxed.best!.release.resolution, 720);
    },
  );

  test(
    'all-provider failure stops fallback instead of repeating blocked searches',
    () async {
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            h.reject(
              DioException(
                requestOptions: o,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          },
        ),
      );
      final result = await engine().resolve(
        show,
        preferences: TorrentPreferences(allowSeasonPackFallback: true),
      );
      expect(result.attempts, hasLength(1));
      expect(result.failures, hasLength(2));
      expect(result.message, contains('Some sources could not be searched'));
      expect(result.failures.first.message, 'Network connectionTimeout');
    },
  );

  test('an already-cancelled request never contacts a provider', () async {
    await expectLater(
      engine().resolve(show, cancelToken: CancelToken()..cancel()),
      throwsA(isA<DioException>()),
    );
    expect(requests, isEmpty);
  });

  test('no-match report distinguishes healthy empty providers from unavailable ones', () async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: o.uri.host == 'bitsearch.eu'
                  ? '<div data-impression-ids="[]"></div>'
                  : [],
            ),
          );
        },
      ),
    );
    final result = await engine().resolve(show);
    expect(result.status, TorrentResolutionStatus.noMatch);
    expect(result.rejectionCounts, isEmpty);
    expect(result.message, 'Searches completed without matching releases.');
    expect(
      result.recoverySuggestions,
      isNot(contains('Retry the failed sources later.')),
    );
  });
}
