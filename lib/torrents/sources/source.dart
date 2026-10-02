import 'dart:convert';

import 'package:dio/dio.dart';

import '../models.dart';

abstract interface class TorrentSource {
  TorrentSourceId get id;
  bool supports(TorrentQuery query);
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  });
}

/// Uses the app transport's bounded rate-limit retry and concurrency controls.
class SourceClient {
  SourceClient(this.dio);
  final Dio dio;
  Future<Object?> get(
    Uri uri, {
    CancelToken? cancelToken,
    bool html = false,
  }) async {
    final response = await dio.getUri<Object?>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Accept': html ? 'text/html' : 'application/json'},
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    if (response.statusCode != 200) {
      throw SourceException('HTTP ${response.statusCode}');
    }
    if (html) return response.data;
    try {
      return response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
    } on FormatException {
      throw const SourceException('Invalid JSON / access challenge');
    }
  }
}
