import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sentorr/imdb/repository.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late NetworkClient network;
  late ImdbRepository repository;
  var requests = 0;
  var error = false;
  setUp(() async {
    requests = 0;
    error = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      requests++;
      final body = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
      final first = body['variables']['first'];
      r.response.headers.contentType = ContentType.json;
      r.response.write(
        jsonEncode(
          error
              ? {
                  'data': null,
                  'errors': [
                    {'message': 'temporary'},
                  ],
                }
              : {
                  'data': {
                    'topMeterTitles': {
                      'edges': [
                        {
                          'node': {
                            'id': 'tt$first',
                            'titleText': {'text': 'Title $first'},
                          },
                        },
                      ],
                    },
                  },
                },
        ),
      );
      await r.response.close();
    });
    network = NetworkClient(http2: false);
    repository = ImdbRepository(
      network.dio,
      endpoint: 'http://127.0.0.1:${server.port}/',
    );
  });
  tearDown(() async {
    await network.close();
    await server.close(force: true);
  });

  test(
    'POST bodies isolate entries, cache hits reuse reads and refresh bypasses',
    () async {
      expect((await repository.trendingTitles(limit: 1)).single.id, 'tt1');
      expect((await repository.trendingTitles(limit: 2)).single.id, 'tt2');
      expect((await repository.trendingTitles(limit: 1)).single.id, 'tt1');
      expect(requests, 2);
      await repository.trendingTitles(limit: 1, refresh: true);
      expect(requests, 3);
      await network.clearCache();
      await repository.trendingTitles(limit: 1);
      expect(requests, 4);
    },
  );

  test('GraphQL errors delivered as HTTP 200 are never cached', () async {
    error = true;
    await expectLater(repository.trendingTitles(), throwsException);
    error = false;
    expect(await repository.trendingTitles(), isNotEmpty);
    expect(requests, 2);
  });

  test(
    'file-backed cache survives a new client with the same Sentorr directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sentorr-cache-test-',
      );
      final url = 'http://127.0.0.1:${server.port}/';
      try {
        final first = NetworkClient(
          cacheDirectory: directory.path,
          http2: false,
        );
        await ImdbRepository(first.dio, endpoint: url).trendingTitles();
        await first.close();
        final second = NetworkClient(
          cacheDirectory: directory.path,
          http2: false,
        );
        try {
          await ImdbRepository(second.dio, endpoint: url).trendingTitles();
        } finally {
          await second.close();
        }
        expect(requests, 1);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  group('tier freshness', () {
    const ttl = Duration(milliseconds: 300);
    setUp(() => network.ttls = (_) => ttl);

    test('entries read often still refresh once their TTL passes', () async {
      await repository.trendingTitles(limit: 1);
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(ttl ~/ 4);
        await repository.trendingTitles(limit: 1);
      }
      expect(requests, 1);
      await Future<void>.delayed(ttl ~/ 2);
      await repository.trendingTitles(limit: 1);
      expect(requests, 2);
    });

    test('expired entries answer when the network fails', () async {
      await repository.trendingTitles(limit: 1);
      await Future<void>.delayed(ttl * 2);
      await server.close(force: true);
      expect((await repository.trendingTitles(limit: 1)).single.id, 'tt1');
    });

    test('invalid responses keep the last good answer', () async {
      await repository.trendingTitles(limit: 1);
      await Future<void>.delayed(ttl * 2);
      error = true;
      await expectLater(repository.trendingTitles(limit: 1), throwsException);
      await server.close(force: true);
      expect((await repository.trendingTitles(limit: 1)).single.id, 'tt1');
    });

    test('settings change TTLs without rebuilding the client', () async {
      network.ttls = (_) => Duration.zero;
      await repository.trendingTitles(limit: 1);
      await repository.trendingTitles(limit: 1);
      expect(requests, 2);
    });
  });

  test('request logs exclude query values, bodies and credentials', () async {
    final records = <String>[];
    final logger = Logger('sentorr.net');
    final oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = logger.onRecord.listen((r) => records.add(r.message));
    try {
      await network.dio.post(
        'http://127.0.0.1:${server.port}/?key=secret',
        data: {
          'variables': {'first': 1},
          'private': 'body-secret',
        },
        options: Options(headers: {'Authorization': 'Bearer token-secret'}),
      );
      expect(records.join(), contains('POST 127.0.0.1/'));
      expect(records.join(), isNot(contains('secret')));
    } finally {
      await subscription.cancel();
      Logger.root.level = oldLevel;
    }
  });
}
