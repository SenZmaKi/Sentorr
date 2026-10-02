import 'package:dio/dio.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:sentorr/torrents/sources/pirate_bay.dart';
import 'package:test/test.dart';

Map<String, Object> row(int id, String name, {int seeds = 100, int gb = 10}) =>
    {
      'name': name,
      'info_hash': id.toRadixString(16).padLeft(40, '0'),
      'seeders': '$seeds',
      'size': '${gb * 1024 * 1024 * 1024}',
      'category': '205',
    };

void main() {
  late Dio dio;
  late Object Function(String) response;
  setUp(() {
    response = (_) => [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: response(o.uri.queryParameters['q']!),
              ),
            );
          },
        ),
      );
  });
  tearDown(() => dio.close(force: true));
  TorrentResolver engine() =>
      TorrentResolver(TorrentRepository([PirateBaySource(dio)]));
  TorrentQuery episode({bool ended = false}) => TorrentQuery(
    title: 'Breaking Bad',
    season: 2,
    episode: 3,
    seriesEnded: ended,
  );
  final preferences = TorrentPreferences(
    includeBatchCandidates: true,
    allowAlternateSearchFallback: false,
  );

  test(
    'well-seeded season pack competes and wins while episode remains available',
    () async {
      response = (q) => q.contains('E03')
          ? [row(1, 'Breaking.Bad.S02E03.1080p.English', seeds: 2, gb: 1)]
          : [row(2, 'Breaking.Bad.S02.Complete.1080p.English', seeds: 1000)];
      final result = await engine().resolve(
        episode(),
        preferences: preferences,
      );
      expect(result.best!.release.isSeasonPack, isTrue);
      expect(result.best!.requiresFileSelection, isTrue);
      expect(result.candidates, hasLength(2));
      expect(result.candidates.last.release.isPack, isFalse);
      expect(result.attempts.map((a) => a.stage), [
        TorrentResolutionStage.primary,
        TorrentResolutionStage.seasonPack,
      ]);
    },
  );

  test(
    'completed series batch can beat both season and single-episode releases',
    () async {
      response = (q) => q.contains('E03')
          ? [row(1, 'Breaking.Bad.S02E03.1080p', seeds: 2, gb: 1)]
          : q.contains('complete')
          ? [row(3, 'Breaking.Bad.S01-S05.Complete.1080p', seeds: 2000, gb: 40)]
          : [row(2, 'Breaking.Bad.S02.Complete.1080p', seeds: 10)];
      final query = episode(ended: true);
      final result = await engine().resolve(query, preferences: preferences);
      expect(result.query, same(query));
      expect(result.candidates, hasLength(3));
      expect(result.best!.release.isSeriesPack, isTrue);
      expect(result.best!.requiresFileSelection, isTrue);
      expect(result.attempts.last.stage, TorrentResolutionStage.seriesPack);
      expect(result.message, contains('batch torrent'));
    },
  );

  test(
    'ongoing or unknown series never triggers complete-series discovery',
    () async {
      final result = await engine().resolve(
        episode(),
        preferences: preferences,
      );
      expect(
        result.attempts.any(
          (a) => a.stage == TorrentResolutionStage.seriesPack,
        ),
        isFalse,
      );
    },
  );

  test(
    'failed batch searches retain a healthy episode and report failure',
    () async {
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.uri.queryParameters['q']!.contains('E03')) {
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: [row(1, 'Breaking.Bad.S02E03.1080p')],
                ),
              );
            } else {
              h.reject(
                DioException(
                  requestOptions: o,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: o, statusCode: 403),
                ),
              );
            }
          },
        ),
      );
      final result = await engine().resolve(
        episode(ended: true),
        preferences: preferences,
      );
      expect(result.best!.release.isPack, isFalse);
      expect(result.status, TorrentResolutionStatus.resolved);
      expect(result.failures.single.message, 'HTTP 403');
      expect(result.message, contains('Some sources could not be searched'));
    },
  );

  test(
    'batch competition preserves language and total-size restrictions',
    () async {
      response = (q) => q.contains('E03')
          ? [row(1, 'Breaking.Bad.S02E03.1080p.English', gb: 1)]
          : [
              row(2, 'Breaking.Bad.S02.Complete.1080p.French', seeds: 1000),
              row(3, 'Breaking.Bad.S02.Complete.1080p.English', seeds: 1000),
            ];
      final result = await engine().resolve(
        TorrentQuery(
          title: 'Breaking Bad',
          season: 2,
          episode: 3,
          languages: {'en'},
        ),
        preferences: TorrentPreferences(
          includeBatchCandidates: true,
          allowAlternateSearchFallback: false,
          maximumSizeBytes: 2 * 1024 * 1024 * 1024,
        ),
      );
      expect(result.candidates, hasLength(1));
      expect(result.best!.release.isPack, isFalse);
      expect(result.attempts.last.query.languages, {'en'});
    },
  );

  test(
    'batch competition can be disabled while fallback remains available',
    () async {
      response = (_) => [row(1, 'Breaking.Bad.S02E03.1080p')];
      final result = await engine().resolve(
        episode(ended: true),
        preferences: TorrentPreferences(allowSeasonPackFallback: true),
      );
      expect(result.attempts, hasLength(1));
    },
  );

  final batch = TorrentQuery(
    title: 'Breaking Bad',
    season: 2,
    searchSeriesPacks: true,
  );
  final cases = <String, bool>{
    'Breaking.Bad.S01-S05.Complete.1080p': true,
    'Breaking.Bad.Seasons.1-5.Complete.1080p': true,
    'Breaking.Bad.Season.1.to.5.Complete.1080p': true,
    'Breaking.Bad.S01.S02.S03.Complete.1080p': true,
    'Breaking.Bad.Complete.Series.1080p': true,
    'Breaking.Bad.Entire.Series.1080p': true,
    'Breaking.Bad.S03-S05.Complete.1080p': false,
    'Breaking.Bad.S05-S01.Complete.1080p': false,
    'Breaking.Bad.S01-S03.S05.Complete.1080p': false,
    'Breaking.Bad.S02E03.1080p': false,
    'Breaking.Bad.S01E01-S05E16.Complete.1080p': false,
    'Breaking.Bad.S02.Complete.1080p': false,
    'Better.Call.Saul.Complete.Series.1080p': false,
    'Breaking.Bad.1080p': false,
  };
  for (final c in cases.entries) {
    test('series batch matches=${c.value}: ${c.key}', () {
      expect(matchesRelease(batch, c.key), c.value);
    });
  }
  test('complete in the title is not proof of a complete series', () {
    expect(
      matchesRelease(
        TorrentQuery(
          title: 'Complete Savages',
          season: 1,
          searchSeriesPacks: true,
        ),
        'Complete.Savages.1080p',
      ),
      isFalse,
    );
  });
}
