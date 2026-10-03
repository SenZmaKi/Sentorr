import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app_lifecycle.dart';
import 'connectivity.dart';
import 'net.dart';

final _log = Logger('sentorr.online');

/// Checks for internet access; tests override it.
final internetProbeProvider = Provider<Future<bool> Function()>(
  (ref) => hasInternet,
);

/// Requests that got no answer. Bootstrap points it at the app's
/// [NetworkClient.networkFailures]; left alone, nothing ever fails.
final networkFailuresProvider = Provider<Stream<void>>(
  (ref) => const Stream.empty(),
);

/// Whether Sentorr can reach the internet. Assumed online, and checked
/// only when a request gets no answer: answers from a fresh cache are not
/// worth a probe. While offline it checks again every few seconds and on
/// returning to the foreground, so pages can reload once it is back.
final onlineProvider = NotifierProvider<OnlineNotifier, bool>(
  OnlineNotifier.new,
);

class OnlineNotifier extends Notifier<bool> {
  static const retryInterval = Duration(seconds: 5);

  Timer? _retry;
  Future<void>? _check;

  @override
  bool build() {
    final failures = ref.watch(networkFailuresProvider).listen((_) => check());
    ref.listen(AppLifecycleNotifier.provider, (previous, next) {
      if (!state &&
          next == AppLifecycleState.resumed &&
          previous != AppLifecycleState.resumed) {
        check();
      }
    });
    ref.onDispose(() {
      failures.cancel();
      _retry?.cancel();
    });
    return true;
  }

  /// Checks now, joining a check already running.
  Future<void> check() => _check ??= _probe().whenComplete(() => _check = null);

  Future<void> _probe() async {
    if (!ref.mounted) return;
    final online = await ref.read(internetProbeProvider)();
    if (!ref.mounted) return;
    if (online != state) _log.info(online ? 'Back online' : 'Offline');
    state = online;
    _retry?.cancel();
    _retry = online ? null : Timer(retryInterval, check);
  }
}
