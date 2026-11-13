import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Debug runs started with `--dart-define=SENTORR_OFFLINE=true` behave as
/// if the device had no connection: catalog requests and artwork fail
/// without an answer, so caches answer what they can.
const simulateOffline = kDebugMode && bool.fromEnvironment('SENTORR_OFFLINE');

const _offline = SocketException('Simulated offline');

/// Fails each request the cache did not answer, as a dropped connection.
class SimulatedOfflineInterceptor extends Interceptor {
  const SimulatedOfflineInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: _offline,
        ),
        true,
      );
}

/// Artwork downloads fail, leaving only what is already on disk.
class SimulatedOfflineFileService extends FileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) =>
      Future.error(_offline);
}
