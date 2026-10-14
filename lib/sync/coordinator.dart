import 'dart:async';

/// Shared scheduling mechanics; transports own timing, validity and errors.
class SyncCoordinator {
  SyncCoordinator({required this.action, required this.active});

  final Future<void> Function() action;
  final bool Function() active;
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _pending, _periodic;
  Duration? _deadline;
  Future<void>? _running;
  bool _again = false, _disposed = false;

  bool get running => _running != null;
  bool get _active => !_disposed && active();

  /// A change during a run needs one follow-up, without starting idle work.
  void changed() {
    if (running) _again = true;
  }

  /// Keep the earliest deadline, even under continuous playback updates.
  void schedule(Duration after) {
    if (!_active) return;
    final deadline = _clock.elapsed + after;
    if (_deadline != null && _deadline! <= deadline) return;
    _deadline = deadline;
    _pending?.cancel();
    _pending = Timer(after, () {
      _deadline = null;
      _pending = null;
      unawaited(run());
    });
  }

  void repeat(Duration interval) {
    _periodic?.cancel();
    if (_disposed) return;
    _periodic = Timer.periodic(interval, (_) => unawaited(run()));
  }

  void clearFollowUp() => _again = false;

  void stopRepeating() => _periodic?.cancel();

  /// Overlapping callers await the same drain. An optional first action lets
  /// Drive sign in once; subsequent passes use the ordinary sync action.
  Future<void> run({Future<void> Function()? first}) {
    if (!_active) return Future.value();
    if (_running case final running?) {
      _again = true;
      return running;
    }
    final completion = Completer<void>();
    _running = completion.future;
    unawaited(() async {
      try {
        var next = first ?? action;
        do {
          _again = false;
          await next();
          next = action;
        } while (_again && _active);
        completion.complete();
      } catch (error, stack) {
        completion.completeError(error, stack);
      } finally {
        _running = null;
      }
    }());
    return completion.future;
  }

  void dispose() {
    _disposed = true;
    _again = false;
    _pending?.cancel();
    _periodic?.cancel();
    _clock.stop();
  }
}
