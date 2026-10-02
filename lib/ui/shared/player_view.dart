import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/session.dart';
import 'pop_out_window.dart';

/// How the open player is presented.
enum PlayerView {
  /// A layer over the whole app.
  full,

  /// Docked in the app's corner; the app stays usable beneath it.
  mini,

  /// The window itself becomes a small always-on-top video window.
  popOut,
}

final playerViewProvider = NotifierProvider<PlayerViewNotifier, PlayerView>(
  PlayerViewNotifier.new,
);

class PlayerViewNotifier extends Notifier<PlayerView> {
  @override
  PlayerView build() {
    // A new session opens full; a closed one leaves no pop-out behind.
    ref.listen(playerSessionProvider.select((s) => s?.request), (_, request) {
      if (request == null) {
        if (state == PlayerView.popOut) unawaited(PopOutWindow.instance.exit());
        state = PlayerView.full;
      } else if (state == PlayerView.mini) {
        state = PlayerView.full;
      }
    });
    return PlayerView.full;
  }

  void expand() {
    if (state == PlayerView.popOut) unawaited(PopOutWindow.instance.exit());
    state = PlayerView.full;
  }

  void minimize() {
    if (state == PlayerView.popOut) unawaited(PopOutWindow.instance.exit());
    state = PlayerView.mini;
  }

  Future<void> popOut() async {
    if (state == PlayerView.popOut || !PopOutWindow.instance.supported) return;
    state = PlayerView.popOut;
    await PopOutWindow.instance.enter();
  }
}
