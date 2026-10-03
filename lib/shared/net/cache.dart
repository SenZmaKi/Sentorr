import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Include representation headers and POST body: URL alone mixes
/// GraphQL operations and locales, as in Senpwai's POST cache fix.
String networkCacheKey({
  required Uri url,
  Map<String, String>? headers,
  Object? body,
}) {
  final normalized = {
    for (final e in (headers ?? {}).entries) e.key.toLowerCase(): e.value,
  };
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'url': url.toString(),
            'representation': {
              for (final key in [
                'accept',
                'accept-language',
                'x-imdb-user-language',
                'x-imdb-user-country',
                'authorization',
                'cookie',
                'x-amzn-sessionid',
              ])
                if (normalized.containsKey(key)) key: normalized[key],
            },
            'body': body,
          }),
        ),
      )
      .toString();
}

/// Marks a POST that only reads, so it may be retried after a 429.
const readOnlyRequestKey = 'sentorr.readOnly';

/// A request's `bool Function(Object? data)` saying whether a response is
/// worth caching.
const cacheValidityKey = 'sentorr.cacheValidity';

/// Keeps error pages, access challenges and GraphQL errors delivered with
/// HTTP 200 out of the cache, without evicting the last good answer.
class CacheValidityGuard extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final extra = response.requestOptions.extra;
    final isValid = extra[cacheValidityKey];
    final options = extra[extraKey];
    if (isValid is bool Function(Object?) &&
        options is CacheOptions &&
        !_accepts(isValid, response.data)) {
      extra.addAll(options.copyWith(store: _discard).toExtra());
    }
    handler.next(response);
  }

  static bool _accepts(bool Function(Object?) isValid, Object? data) {
    try {
      return isValid(data);
    } catch (_) {
      return false;
    }
  }
}

/// GraphQL answers with data and no errors.
bool isGraphqlResult(Object? data) {
  if (data is String) {
    try {
      data = jsonDecode(data);
    } on FormatException {
      return false;
    }
  }
  return data is Map &&
      data['data'] != null &&
      !(data['errors'] is List && (data['errors'] as List).isNotEmpty);
}

final _discard = _DiscardingCacheStore();

class _DiscardingCacheStore extends MemCacheStore {
  @override
  Future<void> set(CacheResponse response) async {}
}
