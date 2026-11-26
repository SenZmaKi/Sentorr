import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/repository.dart';
import 'package:test/test.dart';

Map<String, Object?> title(String id, String? type) => {
  'id': id,
  'titleText': {'text': id},
  'titleType': type == null ? null : {'id': type},
};

Map<String, Object?> connection(
  List<Map<String, Object?>> titles, {
  bool nested = false,
  String? cursor,
}) => {
  'edges': [
    for (final title in titles)
      {
        'node': nested ? {'title': title} : title,
      },
  ],
  'total': titles.length,
  'pageInfo': {'hasNextPage': cursor != null, 'endCursor': cursor},
};

void main() {
  late Dio dio;
  late ImdbRepository repository;
  late Object payload;
  late RequestOptions request;

  setUp(() {
    payload = {};
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: payload),
            );
          },
        ),
      );
    repository = ImdbRepository(dio);
  });
  tearDown(() => dio.close());

  final mixedTitles = [
    title('tt1', 'movie'),
    title('tt2', 'videoGame'),
    title('tt3', 'tvSeries'),
    title('tt4', 'podcastSeries'),
    title('tt5', 'podcastEpisode'),
    title('tt6', 'futureType'),
    title('tt7', null),
  ];

  test('trending excludes games, podcasts and unidentified types', () async {
    payload = {
      'data': {'topMeterTitles': connection(mixedTitles)},
    };
    final results = await repository.trendingTitles();
    expect(results.map((title) => title.id), ['tt1', 'tt3']);
  });

  test(
    'search filters results and preserves the upstream cursor and total',
    () async {
      payload = {
        'data': {
          'advancedTitleSearch': connection(
            mixedTitles,
            nested: true,
            cursor: 'next-search',
          ),
        },
      };
      final results = await repository.searchTitles(ImdbSearchFilters());
      expect(results.items.map((title) => title.id), ['tt1', 'tt3']);
      expect(results.total, mixedTitles.length);
      expect(results.nextCursor, 'next-search');
    },
  );

  test('an entirely filtered recommendation page still advances', () async {
    payload = {
      'data': {
        'title': {
          'moreLikeThisTitles': connection([
            title('tt2', 'videoGame'),
          ], cursor: 'next-related'),
        },
      },
    };
    final first = await repository.getRecommendations('tt1');
    expect(first.items, isEmpty);
    expect(first.nextCursor, 'next-related');
    expect(first.total, 1);
    payload = {
      'data': {
        'title': {'moreLikeThisTitles': connection(mixedTitles)},
      },
    };
    final next = await repository.getRecommendations(
      'tt1',
      cursor: first.nextCursor,
    );
    expect((request.data as Map)['variables']['after'], 'next-related');
    expect(next.items.map((title) => title.id), ['tt1', 'tt3']);
    expect(next.nextCursor, isNull);
  });

  test('detail recommendation previews use the same filtering', () async {
    final fixture = jsonDecode(
      File('test/imdb/fixtures/title-combined-movie.response.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final movie = fixture['data']['title'] as Map;
    movie['images'] = connection([]);
    movie['moreLikeThisTitles'] = connection(
      mixedTitles,
      cursor: 'next-preview',
    );
    payload = fixture;
    final details = await repository.getTitleDetails('tt0133093');
    expect(details.recommendations.items.map((title) => title.id), [
      'tt1',
      'tt3',
    ]);
    expect(details.recommendations.nextCursor, 'next-preview');
  });

  for (final type in [
    'videoGame',
    'podcastSeries',
    'podcastEpisode',
    'unknown',
    null,
  ]) {
    test('direct details reject unsupported type $type', () async {
      payload = {
        'data': {'title': title('tt2', type)},
      };
      await expectLater(
        repository.getTitleDetails('tt2'),
        throwsA(
          isA<ImdbException>().having(
            (error) => error.message,
            'message',
            contains('not a supported watchable title'),
          ),
        ),
      );
    });
  }

  test(
    'autocomplete excludes non-watchable titles and non-title records',
    () async {
      payload = {
        'd': [
          for (final item in mixedTitles)
            {
              'id': item['id'],
              'l': item['id'],
              'qid': (item['titleType'] as Map?)?['id'],
            },
          {'id': 'nm1', 'l': 'Person', 'qid': 'movie'},
          {'id': 'in1', 'l': 'Franchise'},
        ],
      };
      final results = await repository.suggestTitles('test');
      expect(results.map((title) => title.id), ['tt1', 'tt3']);
    },
  );

  test('all supported audiovisual types survive trending filtering', () async {
    const types = [
      'movie',
      'short',
      'tvMovie',
      'tvShort',
      'tvSpecial',
      'tvSeries',
      'tvMiniSeries',
      'tvEpisode',
      'video',
      'musicVideo',
    ];
    payload = {
      'data': {
        'topMeterTitles': connection([
          for (var i = 0; i < types.length; i++) title('tt${i + 1}', types[i]),
        ]),
      },
    };
    final results = await repository.trendingTitles();
    expect(results.map((title) => title.typeId), types);
  });
}
