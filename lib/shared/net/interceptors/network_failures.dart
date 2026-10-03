import 'package:dio/dio.dart';

import '../connectivity.dart';

/// Reports requests that got no answer, before the cache can answer them
/// from disk, so the app can check whether it went offline.
class NetworkFailureInterceptor extends Interceptor {
  NetworkFailureInterceptor(this.onFailure);

  final void Function() onFailure;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isNetworkFailure(err)) onFailure();
    handler.next(err);
  }
}
