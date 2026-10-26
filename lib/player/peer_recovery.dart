import 'dart:async';

/// Bounds peer recovery across probes and native opens, not just each request.
class PeerRecoveryPolicy {
  const PeerRecoveryPolicy({
    this.budget = const Duration(seconds: 20),
    this.attemptTimeout = const Duration(seconds: 4),
    this.delays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });
  final Duration budget, attemptTimeout;
  final List<Duration> delays;

  Future<bool> run({
    required Future<bool> Function(Duration remaining) attempt,
    required bool Function() current,
    required Future<void> Function(Duration) wait,
  }) async {
    final clock = Stopwatch()..start();
    var index = 0;
    while (current() && clock.elapsed < budget) {
      final left = budget - clock.elapsed;
      try {
        if (await attempt(left < attemptTimeout ? left : attemptTimeout)
            .timeout(left < attemptTimeout ? left : attemptTimeout)) {
          return current();
        }
      } on Object {
        // Transport and native failures share this finite retry budget.
      }
      if (!current()) return false;
      final delay = delays[index.clamp(0, delays.length - 1)];
      index++;
      final remaining = budget - clock.elapsed;
      if (remaining <= Duration.zero) break;
      await wait(delay < remaining ? delay : remaining);
    }
    return false;
  }
}

/// Detects a peer player that stays active/buffering without advancing. Paused
/// playback, seeks, completions and source changes restart the grace period.
class PeerStallWatchdog {
  PeerStallWatchdog({
    required this.sample,
    required this.recover,
    this.grace = const Duration(seconds: 10),
    Duration interval = const Duration(seconds: 1),
  }) {
    _timer = Timer.periodic(interval, (_) => check());
  }
  final ({Object source, Duration position, bool playing, bool completed})?
  Function()
  sample;
  final void Function() recover;
  final Duration grace;
  Timer? _timer;
  Object? _source;
  Duration? _position;
  final _stationary = Stopwatch();
  bool _triggered = false;

  void check() {
    final state = sample();
    if (state == null || !state.playing || state.completed) {
      reset();
      return;
    }
    if (!identical(_source, state.source) || _position != state.position) {
      _source = state.source;
      _position = state.position;
      _triggered = false;
      _stationary
        ..reset()
        ..start();
    } else if (!_triggered && _stationary.elapsed >= grace) {
      _triggered = true;
      recover();
    }
  }

  void reset() {
    _source = null;
    _position = null;
    _triggered = false;
    _stationary
      ..stop()
      ..reset();
  }

  void dispose() => _timer?.cancel();
}
