import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:sentorr/shared/net/size_limited_cache_store.dart';
import 'package:test/test.dart';

CacheResponse _response(String key) => CacheResponse(
  cacheControl: CacheControl(),
  content: List.filled(1000, 1),
  date: null,
  eTag: null,
  expires: null,
  headers: null,
  key: key,
  lastModified: null,
  maxStale: null,
  priority: CachePriority.normal,
  requestDate: DateTime.now(),
  responseDate: DateTime.now(),
  url: 'https://example.com/$key',
  statusCode: 200,
);

void main() {
  late Directory directory;
  late SizeLimitedCacheStore store;
  var limit = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sentorr-cache-limit-');
    limit = 0;
    store = SizeLimitedCacheStore(
      FileCacheStore(directory.path),
      directory,
      () => limit,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> put(String key) async {
    await store.set(_response(key));
    await store.trim();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('evicts the least recently used responses past the budget', () async {
    limit = 3800;
    for (final key in ['a', 'b', 'c']) {
      await put(key);
    }
    await store.get('a');
    await put('d');
    expect(await store.exists('a'), isTrue);
    expect(await store.exists('b'), isFalse);
    expect(await store.exists('c'), isTrue);
    expect(await store.exists('d'), isTrue);
  });

  test('zero is unlimited, and lowering the limit trims at once', () async {
    for (final key in ['a', 'b', 'c', 'd']) {
      await put(key);
    }
    expect(await store.exists('a'), isTrue);
    limit = 2500;
    await store.trim();
    expect(await store.exists('a'), isFalse);
    expect(await store.exists('b'), isFalse);
    expect(await store.exists('d'), isTrue);
  });
}
