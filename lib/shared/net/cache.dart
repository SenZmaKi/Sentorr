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

const readOnlyRequestKey = 'sentorr.readOnly';

/// Avoid persisting GraphQL errors/partial failures delivered with HTTP 200.
class GraphqlCacheGuard extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra[readOnlyRequestKey] == true) {
      Object? data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = null;
        }
      }
      if (data is! Map ||
          data['data'] == null ||
          (data['errors'] is List && (data['errors'] as List).isNotEmpty)) {
        final options =
            response.requestOptions.extra[extraKey] as CacheOptions?;
        if (options != null) {
          response.requestOptions.extra.addAll(
            options.copyWith(policy: CachePolicy.noCache).toExtra(),
          );
        }
      }
    }
    handler.next(response);
  }
}
