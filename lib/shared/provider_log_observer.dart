import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Logs every provider that fails, so a row or page showing an error has a
/// matching line naming which provider and argument failed. Screens still
/// present the error themselves; this only traces it.
final class ProviderLogObserver extends ProviderObserver {
  const ProviderLogObserver();

  static final _log = Logger('sentorr.providers');

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is DioException && CancelToken.isCancel(error)) return;
    // Unnamed providers describe themselves by type and family argument.
    _log.warning('${context.provider} failed', error, stackTrace);
  }
}
