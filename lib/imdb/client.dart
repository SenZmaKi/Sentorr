import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../shared/net/cache.dart';
import '../shared/net/cache_tiers.dart';
import 'models.dart';
import 'website.dart';

final _log = Logger('sentorr.imdb');

class ImdbClient {
  ImdbClient(this.dio, {this.endpoint = imdbGraphqlUrl});
  final Dio dio;
  final String endpoint;
  Future<Map<String, dynamic>> query(
    String operation,
    String document,
    Map<String, Object?> variables, {
    CancelToken? cancelToken,
    CacheTier tier = CacheTier.catalogue,
    bool refresh = false,
  }) async {
    final clock = Stopwatch()..start();
    final response = await dio.post<Object?>(
      endpoint,
      data: {
        'operationName': operation,
        'query': document,
        'variables': variables,
      },
      cancelToken: cancelToken,
      options: Options(
        headers: imdbWebsiteHeaders,
        responseType: ResponseType.json,
        extra: {
          readOnlyRequestKey: true,
          ...cachedRequest(
            tier,
            refresh: refresh,
            post: true,
            isValid: isGraphqlResult,
          ),
        },
      ),
    );
    if (response.statusCode != 200) {
      throw ImdbException('IMDb returned HTTP ${response.statusCode}.');
    }
    final json = decodeJson(response.data);
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      final maps = errors.whereType<Map>().toList();
      _log.warning(
        '$operation returned ${maps.length} GraphQL errors: '
        '${maps.map((e) => e['message']).join('; ')}',
      );
      throw ImdbException(
        '$operation failed: '
        '${maps.map((e) => e['message']).join('; ')}',
        codes: List.unmodifiable(
          maps
              .map((e) => (e['extensions'] as Map?)?['code'])
              .whereType<String>(),
        ),
        paths: List.unmodifiable(
          maps
              .map((e) => e['path'])
              .whereType<List>()
              .map((p) => List<Object?>.unmodifiable(p)),
        ),
      );
    }
    if (json['data'] is! Map<String, dynamic>) {
      _log.warning('$operation returned no GraphQL data');
      throw const ImdbException('IMDb returned no GraphQL data.');
    }
    // Cache hits return in a few milliseconds; the network logs the rest.
    _log.fine(
      '$operation ${_describe(variables)} ${clock.elapsedMilliseconds}ms',
    );
    return json['data'] as Map<String, dynamic>;
  }

  /// The identifying variables, without the query constraints' bulk.
  static String _describe(Map<String, Object?> variables) => [
    for (final key in const ['id', 'season', 'first', 'after'])
      if (variables[key] != null) '$key=${variables[key]}',
  ].join(' ');

  static Map<String, dynamic> decodeJson(Object? value) {
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      return decoded as Map<String, dynamic>;
    } catch (_) {
      throw const ImdbException('IMDb returned invalid JSON.');
    }
  }
}
