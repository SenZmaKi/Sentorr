import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

/// Per-host permits. Unlike a raw semaphore, cancelled queued work is removed
/// immediately and never acquires a slot or leaks capacity.
class ConcurrencyInterceptor extends Interceptor {
  ConcurrencyInterceptor({this.perHost = 4}) {
    if (perHost < 1) throw ArgumentError.value(perHost, 'perHost');
  }
  final int perHost;
  final _active = <String, int>{};
  final _queues = <String, Queue<_Waiter>>{};
  static const _permitKey = 'sentorr.permit';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final host = options.uri.host;
    if (options.cancelToken?.isCancelled ?? false) {
      handler.reject(options.cancelToken!.cancelError!);
      return;
    }
    if ((_active[host] ?? 0) >= perHost) {
      final waiter = _Waiter();
      final queue = _queues.putIfAbsent(host, Queue.new);
      queue.add(waiter);
      final cancellation = options.cancelToken?.whenCancel.then((error) {
        if (queue.remove(waiter)) waiter.ready.completeError(error);
      });
      // Register cancellation without awaiting it; the token owns this future.
      if (cancellation != null) unawaited(cancellation);
      try {
        await waiter.ready.future;
      } on DioException catch (err) {
        handler.reject(err);
        return;
      }
    } else {
      _active[host] = (_active[host] ?? 0) + 1;
    }
    options.extra[_permitKey] = true;
    if (options.cancelToken?.isCancelled ?? false) {
      _release(options);
      handler.reject(options.cancelToken!.cancelError!);
      return;
    }
    handler.next(options);
  }

  void _release(RequestOptions options) {
    if (options.extra.remove(_permitKey) != true) return;
    final host = options.uri.host;
    final queue = _queues[host];
    if (queue != null && queue.isNotEmpty) {
      queue.removeFirst().ready.complete();
    } else {
      _active[host] = (_active[host] ?? 1) - 1;
      _queues.remove(host);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _release(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _release(err.requestOptions);
    handler.next(err);
  }
}

class _Waiter {
  final ready = Completer<void>();
}
