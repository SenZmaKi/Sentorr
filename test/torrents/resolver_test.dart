import 'package:dio/dio.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:sentorr/torrents/sources/source.dart';
import 'package:test/test.dart';

TorrentRelease release(
  int id, {
  int? resolution = 1080,
  int seeders = 50,
  int size = 1000000000,
  bool pack = false,
}) {
  final hash = id.toRadixString(16).padLeft(40, '0');
  return TorrentRelease(
    source: TorrentSourceId.pirateBay,
    name: 'Example Movie 2020',
    infoHash: hash,
    magnet: magnetFor(hash, 'Example Movie'),
    seeders: seeders,
    sizeBytes: size,
    resolution: resolution,
    isSeasonPack: pack,
  );
}

class FakeSource implements TorrentSource {
  FakeSource(this.id, this.searcher);
  @override
  final TorrentSourceId id;
  final Future<List<TorrentRelease>> Function(TorrentQuery, CancelToken?)
  searcher;
  final queries = <TorrentQuery>[];
  @override
  bool supports(TorrentQuery query) => true;
  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) {
    queries.add(query);
    return searcher(query, cancelToken);
  }
}

void main() {
  final movie = TorrentQuery(title: 'Example Movie', year: 2020);
  test('preferred quality outranks over-sized higher resolution', () {
    final ranked = TorrentResolver.rank([
      release(1, resolution: 2160, seeders: 100, size: 20000000000),
      release(2),
      release(3, resolution: null),
    ], TorrentPreferences());
    expect(ranked.first.release.infoHash, release(2).infoHash);
    expect(ranked.last.release.resolution, isNull);
    expect(() => ranked.clear(), throwsUnsupportedError);
  });

  test('size, unknown quality and seed limits are hard filters', () {
    final ranked = TorrentResolver.rank(
      [
        release(1, seeders: 0),
        release(2, seeders: 2),
        release(3, size: 2000000000),
        release(4, resolution: null),
        release(5),
      ],
      TorrentPreferences(
        minimumSeeders: 5,
        maximumSizeBytes: 1000000000,
        allowUnknownResolution: false,
      ),
    );
    expect(ranked.single.release.infoHash, release(5).infoHash);
  });

  test('scores do not depend on other candidates; ties are deterministic', () {
    final prefs = TorrentPreferences();
    final alone = TorrentResolver.rank([release(2)], prefs).single.score;
    final batch = TorrentResolver.rank([release(2), release(1)], prefs);
    expect(batch.first.release.infoHash, release(1).infoHash);
    expect(batch.last.score, alone);
  });

  test(
    'partial provider failure retains ranked and deduplicated results',
    () async {
      final engine = TorrentResolver(
        TorrentRepository([
          FakeSource(TorrentSourceId.pirateBay, (_, _) async => [release(1)]),
          FakeSource(TorrentSourceId.bitsearch, (_, _) async => [release(1)]),
          FakeSource(TorrentSourceId.yts, (_, _) async {
            throw const SourceException('Unavailable');
          }),
        ]),
      );
      final result = await engine.resolve(movie);
      expect(result.status, TorrentResolutionStatus.resolved);
      expect(result.candidates, hasLength(1));
      expect(result.failures.single.source, TorrentSourceId.yts);
    },
  );

  test('empty searches distinguish no match from provider failure', () async {
    final empty = TorrentResolver(
      TorrentRepository([
        FakeSource(TorrentSourceId.pirateBay, (_, _) async => []),
      ]),
    );
    expect(
      (await empty.resolve(movie)).status,
      TorrentResolutionStatus.noMatch,
    );
    final broken = TorrentResolver(
      TorrentRepository([
        FakeSource(TorrentSourceId.pirateBay, (_, _) async {
          throw const SourceException('Unavailable');
        }),
      ]),
    );
    expect(
      (await broken.resolve(movie)).status,
      TorrentResolutionStatus.unavailable,
    );
  });

  test('pack fallback preserves intent and requires file inspection', () async {
    final source = FakeSource(
      TorrentSourceId.pirateBay,
      (q, _) async => q.isSeasonPack ? [release(1, pack: true)] : [],
    );
    final engine = TorrentResolver(TorrentRepository([source]));
    final query = TorrentQuery(
      title: 'Example Show',
      imdbId: 'tt123',
      episodeImdbId: 'tt456',
      year: 2020,
      season: 2,
      episode: 0,
      languages: {'en'},
    );
    final result = await engine.resolve(
      query,
      preferences: TorrentPreferences(
        allowSeasonPackFallback: true,
        allowAlternateSearchFallback: false,
      ),
    );
    expect(result.query, same(query));
    expect(result.best!.requiresFileSelection, isTrue);
    expect(source.queries, hasLength(2));
    final fallback = source.queries.last;
    expect(fallback.season, 2);
    expect(fallback.episode, isNull);
    expect(fallback.episodeImdbId, isNull);
    expect(fallback.imdbId, 'tt123');
    expect(fallback.languages, {'en'});
    expect(fallback.year, 2020);
  });

  test('fallback is opt-in and never replaces an eligible episode', () async {
    final source = FakeSource(
      TorrentSourceId.pirateBay,
      (_, _) async => [release(1)],
    );
    final engine = TorrentResolver(TorrentRepository([source]));
    final query = TorrentQuery(title: 'Example Show', season: 1, episode: 1);
    await engine.resolve(
      query,
      preferences: TorrentPreferences(allowSeasonPackFallback: true),
    );
    expect(source.queries, hasLength(1));
    final empty = FakeSource(TorrentSourceId.bitsearch, (_, _) async => []);
    await TorrentResolver(TorrentRepository([empty])).resolve(
      query,
      preferences: TorrentPreferences(allowAlternateSearchFallback: false),
    );
    expect(empty.queries, hasLength(1));
  });

  test('cancellation propagates and does not trigger fallback', () async {
    final token = CancelToken();
    final source = FakeSource(TorrentSourceId.pirateBay, (_, passed) async {
      expect(passed, same(token));
      token.cancel('Stopped');
      throw token.cancelError!;
    });
    final future = TorrentResolver(TorrentRepository([source])).resolve(
      TorrentQuery(title: 'Example Show', season: 1, episode: 1),
      cancelToken: token,
      preferences: TorrentPreferences(allowSeasonPackFallback: true),
    );
    await expectLater(future, throwsA(isA<DioException>()));
    expect(source.queries, hasLength(1));
  });

  test('invalid preferences fail before any search', () {
    expect(() => TorrentPreferences(minimumSeeders: 0), throwsArgumentError);
    expect(
      () => TorrentPreferences(preferredResolution: 0),
      throwsArgumentError,
    );
    expect(() => TorrentPreferences(maximumSizeBytes: 0), throwsArgumentError);
  });
}
