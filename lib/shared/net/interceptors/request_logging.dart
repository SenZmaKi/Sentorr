import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Logs timing/status only. No query strings, bodies, cookies or credentials.
class RequestLoggingInterceptor extends Interceptor {
  final Logger logger;
  RequestLoggingInterceptor(this.logger);
  static const _clockKey = 'sentorr.requestClock';
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_clockKey] = Stopwatch()..start();
    handler.next(options);
  }

  void _log(RequestOptions request, Object outcome) {
    final clock = request.extra[_clockKey] as Stopwatch?;
    clock?.stop();
    logger.fine(
      '${request.method} ${request.uri.host}${request.uri.path} '
      '$outcome ${clock?.elapsedMilliseconds ?? 0}ms',
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, response.statusCode ?? 'unknown');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode ?? err.type.name);
    handler.next(err);
  }
}
