import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import '../cache_tiers.dart';

/// Refetches tiered entries older than their tier's TTL.
///
/// The cache interceptor's `maxStale` slides forward on every hit, so on its
/// own a page opened often would never refresh. Freshness is measured from
/// when the response arrived; `maxStale` only decides when to evict.
class CacheFreshnessInterceptor extends Interceptor {
  CacheFreshnessInterceptor(this.store, this.ttls, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final CacheStore store;
  final CacheTtls ttls;
  final DateTime Function() _now;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tier = options.extra[cacheTierKey];
    final cache = options.getCacheOptions();
    if (tier is CacheTier &&
        cache != null &&
        cache.policy == CachePolicy.forceCache) {
      try {
        final headers = options.getFlattenHeaders()
          ..removeWhere((key, _) => conditionalRequestHeaders.contains(key));
        final entry = await (cache.store ?? store).get(
          cache.keyBuilder(
            url: options.uri,
            headers: headers,
            body: options.data,
          ),
        );
        if (entry != null &&
            _now().difference(entry.responseDate) > ttls(tier)) {
          options.extra.addAll(
            cache.copyWith(policy: CachePolicy.refresh).toExtra(),
          );
        }
      } catch (_) {
        // An unreadable entry is replaced by the next response.
      }
    }
    handler.next(options);
  }
}
