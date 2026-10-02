import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/shared/net/request_cancellation_scope.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cancelled queued requests do not reach the server or leak permits',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final network = NetworkClient(http2: false, perHost: 1);
      final entered = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      server.listen((r) async {
        requests++;
        if (requests == 1) {
          entered.complete();
          await release.future;
        }
        r.response.write('ok');
        await r.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}/';
      try {
        final first = network.dio.get(url);
        await entered.future;
        final token = CancelToken();
        final second = network.dio.get(url, cancelToken: token);
        final cancelled = expectLater(
          second,
          throwsA(
            isA<DioException>().having(
              (e) => e.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
        final third = network.dio.get(url);
        token.cancel('superseded');
        await cancelled;
        release.complete();
        await first;
        await third;
        expect(requests, 2);
        await network.dio.get(url);
        expect(requests, 3);
      } finally {
        await network.close();
        await server.close(force: true);
      }
    },
  );

  test('429 retry happens once, and mutations are not replayed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final network = NetworkClient(http2: false);
    var requests = 0;
    server.listen((r) async {
      requests++;
      r.response.statusCode = 429;
      r.response.headers.set('Retry-After', '0');
      await r.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/';
    try {
      await expectLater(network.dio.get(url), throwsA(isA<DioException>()));
      expect(requests, 2);
      await expectLater(
        network.dio.post(url, data: {'mutation': 'write'}),
        throwsA(isA<DioException>()),
      );
      expect(requests, 3);
    } finally {
      await network.close();
      await server.close(force: true);
    }
  });

  test('rate-limit wait honours scoped cancellation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final network = NetworkClient(http2: false);
    final seen = Completer<void>();
    var requests = 0;
    server.listen((r) async {
      requests++;
      r.response.statusCode = 429;
      r.response.headers.set('Retry-After', '20');
      await r.response.close();
      seen.complete();
    });
    final token = CancelToken();
    try {
      final future = runWithRequestCancelToken(
        token,
        () => network.dio.get('http://127.0.0.1:${server.port}/'),
      );
      final assertion = expectLater(
        future,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await seen.future;
      token.cancel();
      await assertion;
      expect(requests, 1);
    } finally {
      await network.close();
      await server.close(force: true);
    }
  });

  test('HTTP2 preferred transport can request an HTTP1-only server', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final network = NetworkClient();
    server.listen((r) async {
      r.response.write('ok');
      await r.response.close();
    });
    try {
      expect(
        (await network.dio.get('http://127.0.0.1:${server.port}/')).data,
        'ok',
      );
    } finally {
      await network.close();
      await server.close(force: true);
    }
  });
}
