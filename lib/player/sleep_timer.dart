import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine.dart';

/// An armed sleep timer: a fixed time, or the end of the current item.
class SleepTimer {
  const SleepTimer.after(Duration this.duration, this.endsAt)
    : endOfItem = false;
  const SleepTimer.endOfItem()
    : duration = null,
      endsAt = null,
      endOfItem = true;

  final Duration? duration;
  final DateTime? endsAt;
  final bool endOfItem;
}

/// Pauses playback when the timer runs out. Lives with the player page.
final sleepTimerProvider =
    NotifierProvider.autoDispose<SleepTimerNotifier, SleepTimer?>(
      SleepTimerNotifier.new,
    );

class SleepTimerNotifier extends Notifier<SleepTimer?> {
  Timer? _timer;

  @override
  SleepTimer? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void set(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, _expire);
    state = SleepTimer.after(duration, DateTime.now().add(duration));
  }

  void endOfItem() {
    _timer?.cancel();
    state = const SleepTimer.endOfItem();
  }

  void cancel() {
    _timer?.cancel();
    state = null;
  }

  /// Called when an item finishes; true when the timer claims it, so the
  /// next item does not autoplay.
  bool consumeEndOfItem() {
    if (state?.endOfItem != true) return false;
    state = null;
    return true;
  }

  void _expire() {
    state = null;
    ref.read(playbackEngineProvider).player.pause();
  }
}
