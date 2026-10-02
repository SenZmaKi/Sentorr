import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../cache.dart';

/// One retry for replayable reads only. No mutation/upload replay, and no
/// retries for access blocks or GraphQL validation errors.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this.dio, {this.maxWait = const Duration(seconds: 30)});
  final Dio dio;
  final Duration maxWait;
  static const _retriedKey = 'sentorr.rateLimitRetried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final read =
        options.method == 'GET' ||
        options.method == 'HEAD' ||
        (options.extra[readOnlyRequestKey] == true && options.data is Map);
    if (err.response?.statusCode != 429 ||
        !read ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final raw = err.response!.headers.value('retry-after');
    Duration wait = const Duration(seconds: 2);
    final seconds = int.tryParse(raw ?? '');
    if (seconds != null) {
      wait = Duration(seconds: seconds);
    } else if (raw != null) {
      try {
        wait = HttpDate.parse(raw).difference(DateTime.now().toUtc());
      } on FormatException {
        /* use bounded default */
      }
    }
    if (wait > maxWait) {
      handler.next(err);
      return;
    }
    if (wait.isNegative) wait = Duration.zero;
    try {
      final delay = Completer<void>();
      final actualTimer = Timer(wait, delay.complete);
      try {
        await Future.any([
          delay.future,
          if (options.cancelToken != null)
            options.cancelToken!.whenCancel.then<void>((err) => throw err),
        ]);
      } finally {
        actualTimer.cancel();
      }
      if (options.cancelToken?.isCancelled ?? false) {
        throw options.cancelToken!.cancelError!;
      }
      final response = await dio.fetch<dynamic>(
        options.copyWith(extra: {...options.extra, _retriedKey: true}),
      );
      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    }
  }
}
