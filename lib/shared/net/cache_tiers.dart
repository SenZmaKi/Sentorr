import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import 'cache.dart';

/// How long a cached response stays fresh depends on what it holds, as in
/// Senpwai: the viewer can tune each tier under Settings → Storage.
enum CacheTier {
  /// Search results, which change as titles and torrents come and go.
  liveSearch(Duration(minutes: 2)),

  /// Catalog pages: trending, titles, episodes, reviews.
  catalogue(Duration(hours: 1)),

  /// Data that rarely changes: credits and artwork.
  reference(Duration(hours: 24));

  const CacheTier(this.defaultTtl);
  final Duration defaultTtl;
}

/// Resolves each tier's freshness window when a request is sent, so
/// changed settings apply without rebuilding the client.
typedef CacheTtls = Duration Function(CacheTier tier);

Duration defaultCacheTtls(CacheTier tier) => tier.defaultTtl;

/// How long an unused response stays on disk. Each hit extends it, so this
/// evicts what nobody opens while keeping expired answers for offline use.
const cacheRetention = Duration(days: 30);

const cacheTierKey = 'sentorr.cacheTier';

/// Request extras that cache a response under [tier]. [refresh] skips a
/// fresh entry; [isValid] keeps error pages delivered with HTTP 200 out of
/// the cache.
Map<String, dynamic> cachedRequest(
  CacheTier tier, {
  bool refresh = false,
  bool post = false,
  bool Function(Object? data)? isValid,
}) => {
  cacheTierKey: tier,
  ...?(isValid == null ? null : {cacheValidityKey: isValid}),
  ...CacheOptions(
    store: null,
    policy: refresh ? CachePolicy.refresh : CachePolicy.forceCache,
    allowPostMethod: post,
    maxStale: cacheRetention,
    // Offline, the last answer beats an error.
    hitCacheOnNetworkFailure: true,
    keyBuilder: networkCacheKey,
  ).toExtra(),
};
