import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Logs timing/status only. No query strings, bodies, cookies or credentials.
/// Successes are fine-level traces; failures are warnings so a release log
/// shows which host failed and how. Cache hits never reach the network, so
/// they are not logged here.
class RequestLoggingInterceptor extends Interceptor {
  final Logger logger;
  RequestLoggingInterceptor(this.logger);
  static const _clockKey = 'sentorr.requestClock';
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_clockKey] = Stopwatch()..start();
    handler.next(options);
  }

  String _describe(RequestOptions request, Object outcome) {
    final clock = request.extra[_clockKey] as Stopwatch?;
    clock?.stop();
    return '${request.method} ${request.uri.host}${request.uri.path} '
        '$outcome ${clock?.elapsedMilliseconds ?? 0}ms';
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final status = response.statusCode;
    final line = _describe(response.requestOptions, status ?? 'unknown');
    status != null && status >= 400 ? logger.warning(line) : logger.fine(line);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final outcome = err.response?.statusCode ?? err.type.name;
    final line = _describe(err.requestOptions, outcome);
    if (CancelToken.isCancel(err)) {
      logger.fine(line);
    } else {
      // The transport cause (DNS, TLS, reset) when no response arrived.
      final cause = err.response == null ? err.error : null;
      logger.warning(cause == null ? line : '$line: $cause');
    }
    handler.next(err);
  }
}
