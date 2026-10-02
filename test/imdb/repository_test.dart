import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/repository.dart';
import 'package:test/test.dart';

Map<String, dynamic> evidence(String stem) => jsonDecode(
  File('docs/IMDB/imdb-research/$stem.response.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  late Dio dio;
  late ImdbRepository repository;
  late Object payload;
  late RequestOptions request;
  var calls = 0;
  setUp(() {
    calls = 0;
    payload = {};
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls++;
            request = o;
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: payload),
            );
          },
        ),
      );
    repository = ImdbRepository(dio);
  });
  tearDown(() => dio.close());

  test('combined movie detail decodes sparse episode metadata and polymorphic credits', () async {
    payload = evidence('title-combined-movie');
    // Append a known image page to the earlier research projection.
    final title = ((payload as Map)['data'] as Map)['title'] as Map;
    title['images'] = {
      'edges': [
        {
          'node': {
            'url': 'portrait',
            'width': 2000,
            'height': 3000,
            'type': 'poster',
          },
        },
        {
          'node': {
            'url': 'landscape',
            'width': 1920,
            'height': 1080,
            'type': 'still_frame',
          },
        },
      ],
      'pageInfo': {'hasNextPage': false},
    };
    final details = await repository.getTitleDetails(
      'tt0133093',
      previewLimit: 2,
    );
    expect(details.title.title, 'The Matrix');
    expect(details.seasons, isEmpty);
    expect(details.episodeCount, isNull);
    expect(
      details.principalCredits.map((c) => c.kind),
      containsAll(['Crew', 'Cast']),
    );
    expect(details.backdropCandidate?.url, 'landscape');
    expect(calls, 1);
    expect(request.method, 'POST');
    expect((request.data as Map).containsKey('extensions'), isFalse);
  });

  test('series details preserve numeric seasons and total episodes', () async {
    payload = evidence('title-combined-series');
    final title = ((payload as Map)['data'] as Map)['title'] as Map;
    title['images'] = {
      'edges': [],
      'pageInfo': {'hasNextPage': false},
    };
    final details = await repository.getTitleDetails('tt0903747');
    expect(details.title.canHaveEpisodes, isTrue);
    expect(details.seasons, [1, 2, 3, 4, 5]);
    expect(details.episodeCount, 62);
    expect(details.videos, isNotEmpty);
  });

  test(
    'episode cursors pass through and season numbers remain numeric',
    () async {
      payload = evidence('title-episodes-page1');
      final first = await repository.getEpisodes('tt0903747', 2, limit: 2);
      expect(first.items.map((e) => e.episodeNumber), [1, 2]);
      expect(first.total, 13);
      payload = evidence('title-episodes-page2');
      final second = await repository.getEpisodes(
        'tt0903747',
        2,
        limit: 2,
        cursor: first.nextCursor,
      );
      expect(second.items.map((e) => e.episodeNumber), [3, 4]);
      expect((request.data as Map)['variables']['after'], first.nextCursor);
      expect((request.data as Map)['variables']['season'], '2');
    },
  );

  test('reviews preserve spoiler information and second page IDs', () async {
    payload = evidence('title-reviews-page1');
    final first = await repository.getReviews('tt0133093', limit: 2);
    expect(first.items.every((r) => r.spoiler == false), isTrue);
    expect(first.items.first.content, isNotEmpty);
    payload = evidence('title-reviews-page2');
    final second = await repository.getReviews(
      'tt0133093',
      limit: 2,
      cursor: first.nextCursor,
    );
    expect(second.items.first.id, isNot(first.items.first.id));
    expect((request.data as Map)['variables']['filter'], {
      'spoiler': 'EXCLUDE',
    });
  });

  test('search maps node.title and preserves sparse optional fields', () async {
    payload = {
      'data': {
        'advancedTitleSearch': {
          'total': 1,
          'pageInfo': {'hasNextPage': false, 'endCursor': 'ignored'},
          'edges': [
            {
              'node': {
                'title': {
                  'id': 'tt0133093',
                  'titleText': {'text': 'The Matrix'},
                },
              },
            },
          ],
        },
      },
    };
    final filters = ImdbSearchFilters(
      term: 'matrix',
      genres: ['Action'],
      rating: ImdbRange(min: 5.0, max: 10.0),
      runtimeMinutes: ImdbRange(min: 60, max: 240),
    );
    final results = await repository.searchTitles(filters);
    expect(results.items.single.rating, isNull);
    expect(results.nextCursor, isNull);
    final variables = (request.data as Map)['variables'] as Map;
    expect(variables['constraints']['genreConstraint'], {
      'allGenreIds': ['Action'],
    });
    expect(variables['sort'], {'sortBy': 'POPULARITY', 'sortOrder': 'ASC'});
  });

  test('structured GraphQL errors fail once even with partial data', () async {
    payload = {
      'data': {
        'topMeterTitles': {'edges': []},
      },
      'errors': [
        {
          'message': 'Denied',
          'path': ['topMeterTitles'],
          'extensions': {'code': 'FORBIDDEN'},
        },
      ],
    };
    await expectLater(
      repository.trendingTitles(),
      throwsA(
        isA<ImdbException>()
            .having((e) => e.codes, 'codes', ['FORBIDDEN'])
            .having((e) => e.paths, 'paths', [
              ['topMeterTitles'],
            ]),
      ),
    );
    expect(calls, 1);
  });

  test(
    'missing title, broken cursor, and malformed JSON fail explicitly',
    () async {
      payload = {
        'data': {'title': null},
      };
      await expectLater(
        repository.getTitleDetails('tt0000000'),
        throwsA(isA<ImdbException>()),
      );
      payload = {
        'data': {
          'advancedTitleSearch': {
            'edges': [],
            'pageInfo': {'hasNextPage': true},
          },
        },
      };
      await expectLater(
        repository.searchTitles(ImdbSearchFilters()),
        throwsA(isA<ImdbException>()),
      );
      payload = '<html>challenge</html>';
      await expectLater(
        repository.trendingTitles(),
        throwsA(isA<ImdbException>()),
      );
    },
  );

  test('input errors occur before any request', () async {
    await expectLater(repository.trendingTitles(limit: 0), throwsRangeError);
    await expectLater(
      repository.getTitleDetails('invalid'),
      throwsArgumentError,
    );
    await expectLater(
      repository.getEpisodes('tt0903747', -1),
      throwsRangeError,
    );
    expect(() => ImdbRange(min: 10, max: 1), throwsArgumentError);
    expect(calls, 0);
  });

  test('suggestions exclude people and franchise records', () async {
    payload = {
      'd': [
        {'id': 'tt0133093', 'l': 'The Matrix', 'y': 1999, 'qid': 'movie'},
        {'id': 'nm0000206', 'l': 'Keanu Reeves'},
        {'id': 'in0000304', 'l': 'Matrix franchise'},
      ],
    };
    expect(await repository.suggestTitles(' '), isEmpty);
    final titles = await repository.suggestTitles(' Matrix & Friends ');
    expect(titles.map((t) => t.id), ['tt0133093']);
    expect(request.path, endsWith('matrix%20%26%20friends.json'));
  });
}
