import 'dart:io';

import 'package:dio/dio.dart';

/// Debug runs started with `--dart-define=SENTORR_OFFLINE=true` behave as
/// if the device had no connection: catalog requests and artwork fail
/// without an answer, so caches answer what they can.
///
/// Kept free of Flutter so command-line tools can use the network stack.
const simulateOffline =
    !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile') &&
    bool.fromEnvironment('SENTORR_OFFLINE');

const simulatedOfflineError = SocketException('Simulated offline');

/// Fails each request the cache did not answer, as a dropped connection.
class SimulatedOfflineInterceptor extends Interceptor {
  const SimulatedOfflineInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: simulatedOfflineError,
        ),
        true,
      );
}
