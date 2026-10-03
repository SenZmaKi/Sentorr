import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:logging/logging.dart';

import 'dart:io';

import 'cache.dart';
import 'cache_tiers.dart';
import 'http2_preferred_adapter.dart';
import 'interceptors/cache_freshness.dart';
import 'interceptors/concurrency.dart';
import 'interceptors/rate_limit.dart';
import 'interceptors/request_logging.dart';
import 'request_cancellation_scope.dart';
import 'size_limited_cache_store.dart';

/// The owner closes both the transport and cache. Pass a Sentorr-owned cache
/// directory to persist between app runs; CLI/tests default to memory.
class NetworkClient {
  NetworkClient({
    String? cacheDirectory,
    bool http2 = true,
    int perHost = 4,
    bool logging = true,
    CacheStore? store,
    this.ttls = defaultCacheTtls,
    this.maxCacheBytes = 0,
  }) : _ownsStore = store == null {
    cacheStore =
        store ??
        (cacheDirectory == null
            ? MemCacheStore()
            : SizeLimitedCacheStore(
                FileCacheStore(cacheDirectory),
                Directory(cacheDirectory),
                () => maxCacheBytes,
              ));
    dio = buildDio(
      store: cacheStore,
      http2: http2,
      perHost: perHost,
      logging: logging,
      ttls: (tier) => ttls(tier),
    );
  }
  late final CacheStore cacheStore;
  final bool _ownsStore;
  late final Dio dio;

  /// Each cache tier's freshness window, read as requests are sent.
  CacheTtls ttls;

  /// The disk cache's budget in bytes; zero means unlimited.
  int maxCacheBytes;

  /// Applies a changed [maxCacheBytes] now rather than on the next write.
  Future<void> trimCache() async {
    final store = cacheStore;
    if (store is SizeLimitedCacheStore) await store.trim();
  }
  Future<void> clearCache() => cacheStore.clean();
  Future<void> close() async {
    dio.close(force: true);
    if (_ownsStore) await cacheStore.close();
  }
}

Dio buildDio({
  required CacheStore store,
  bool http2 = true,
  int perHost = 4,
  bool logging = true,
  CacheTtls ttls = defaultCacheTtls,
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'User-Agent': 'Sentorr/0.1', 'Accept': 'application/json'},
    ),
  );
  final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
  adapter.createHttpClient = () => HttpClient()
    ..maxConnectionsPerHost = perHost
    ..idleTimeout = const Duration(minutes: 3);
  if (http2) preferHttp2(dio);
  dio.interceptors.addAll([
    const ScopedCancelTokenInterceptor(),
    CacheFreshnessInterceptor(store, ttls),
    CacheValidityGuard(),
    DioCacheInterceptor(
      options: CacheOptions(
        store: store,
        policy: CachePolicy.noCache,
        keyBuilder: networkCacheKey,
      ),
    ),
    ConcurrencyInterceptor(perHost: perHost),
    RateLimitInterceptor(dio),
    if (logging) RequestLoggingInterceptor(Logger('sentorr.net')),
  ]);
  return dio;
}

/// Convenience for short-lived callers. Long-lived apps use NetworkClient.
Dio createDio() => buildDio(store: MemCacheStore());
