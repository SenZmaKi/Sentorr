import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'connectivity.dart';
import 'online.dart';

bool _unanswered(Object error) =>
    error is DioException && isNetworkFailure(error);

/// Riverpod's retry, except that a request with no answer is not retried
/// while offline: each retry would show loading again for nothing.
/// [ReconnectReloader] reloads those providers once the connection is back.
Duration? Function(int, Object) offlineAwareRetry(bool Function() online) =>
    (count, error) => _unanswered(error) && !online()
    ? null
    : ProviderContainer.defaultRetry(count, error);

/// Remembers providers that failed for want of a connection and reloads
/// them when it returns, so every page recovers without a manual retry.
final class ReconnectReloader extends ProviderObserver {
  final _failed = <ProviderOrFamily>{};

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_unanswered(error)) _failed.add(context.provider);
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) =>
      _failed.remove(context.provider);

  /// Reloads failed providers whenever [container] comes back online.
  void attach(ProviderContainer container) {
    container.listen(onlineProvider, (was, online) {
      if (was != false || !online) return;
      final failed = [..._failed];
      _failed.clear();
      failed.forEach(container.invalidate);
    });
  }
}
