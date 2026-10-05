import 'dart:async';

import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';

final _log = Logger('sentorr.player.stream');

/// MediaKit errors include recoverable codec/network messages. Recover only
/// once the current load finishes and mpv reports no active playback.
class PlaybackErrors {
  PlaybackErrors({
    required this.player,
    required this.generation,
    required this.opening,
    required this.eligible,
    required this.onFailure,
  }) {
    _subscription = player.stream.error.listen((_) => _schedule(generation()));
  }

  final Player player;
  final int Function() generation;
  final bool Function() opening, eligible;
  final void Function() onFailure;
  late final StreamSubscription<String> _subscription;
  Timer? _timer;
  bool _disposed = false;

  void _schedule(int owner) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => _check(owner));
  }

  Future<void> _check(int owner) async {
    if (_disposed || owner != generation() || !eligible()) return;
    if (opening()) {
      _schedule(owner);
      return;
    }
    try {
      final native = player.platform;
      final stopped = native is NativePlayer
          ? await native.getProperty('idle-active') == 'yes'
          : !player.state.playing && !player.state.completed;
      if (!_disposed && owner == generation() && eligible() && stopped) {
        onFailure();
      }
    } catch (error, stack) {
      _log.fine('Could not inspect playback after an error', error, stack);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription.cancel());
  }
}
