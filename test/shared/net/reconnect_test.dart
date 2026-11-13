import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/images.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/shared/net/reconnect.dart';

final _unanswered = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

void main() {
  test('offline, unanswered requests are not retried; others still are', () {
    var online = true;
    final retry = offlineAwareRetry(() => online);
    expect(retry(0, _unanswered), isNotNull);
    online = false;
    expect(retry(0, _unanswered), isNull);
    expect(retry(0, Exception('parse')), isNotNull);
  });

  test('providers that failed offline reload once back online', () async {
    var reachable = false;
    var calls = 0;
    final reloader = ReconnectReloader();
    final fetch = FutureProvider<int>((ref) async {
      calls++;
      if (!reachable) throw _unanswered;
      return calls;
    });
    final container = ProviderContainer(
      observers: [reloader],
      retry: (_, _) => null,
      overrides: [
        internetProbeProvider.overrideWithValue(() async => reachable),
      ],
    );
    addTearDown(container.dispose);
    reloader.attach(container);
    container.listen(fetch, (_, _) {});
    await container.read(onlineProvider.notifier).check();
    await expectLater(container.read(fetch.future), throwsA(anything));

    reachable = true;
    await container.read(onlineProvider.notifier).check();
    expect(await container.read(fetch.future), 2);
  });

  test('renditions list the other sizes of an image, nearest first', () {
    const url = 'https://m.media-amazon.com/images/M/a._V1_QL75_UX720_.jpg';
    final others = imdbImageRenditions(url);
    expect(others, isNot(contains(url)));
    expect(others.first, contains('_UX540_'));
    expect(others, hasLength(7));
  });
}
