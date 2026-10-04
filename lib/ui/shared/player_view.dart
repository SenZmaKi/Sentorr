import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/session.dart';
import 'picture_in_picture.dart';

/// How the open player is presented.
enum PlayerView {
  /// A layer over the whole app.
  full,

  /// Docked in the app's corner; the app stays usable beneath it.
  mini,

  /// A small floating video window: the app's own on desktop, the system's
  /// Picture-in-Picture on Android.
  popOut,
}

final playerViewProvider = NotifierProvider<PlayerViewNotifier, PlayerView>(
  PlayerViewNotifier.new,
);

class PlayerViewNotifier extends Notifier<PlayerView> {
  @override
  PlayerView build() {
    // A new session opens full; a closed one leaves no pop-out behind.
    // Closing otherwise keeps the view, so the player fades out as it was
    // instead of flashing the full chrome on its way out.
    ref.listen(playerSessionProvider.select((s) => s?.request), (_, request) {
      if (request == null) {
        if (state != PlayerView.popOut) return;
        unawaited(PictureInPicture.instance.exit());
        state = PlayerView.mini;
      } else if (state == PlayerView.mini) {
        state = PlayerView.full;
      }
    });
    // The OS opens the window itself when leaving the app mid-playback and
    // closes it when the viewer taps back into the app.
    final changes = PictureInPicture.instance.changes.listen((active) {
      if (active) {
        state = PlayerView.popOut;
      } else if (state == PlayerView.popOut) {
        state = PlayerView.full;
      }
    });
    ref.onDispose(changes.cancel);
    return PlayerView.full;
  }

  void expand() {
    if (state == PlayerView.popOut) unawaited(PictureInPicture.instance.exit());
    state = PlayerView.full;
  }

  void minimize() {
    if (state == PlayerView.popOut) unawaited(PictureInPicture.instance.exit());
    state = PlayerView.mini;
  }

  Future<void> popOut() async {
    if (state == PlayerView.popOut || !PictureInPicture.instance.supported) {
      return;
    }
    final previous = state;
    state = PlayerView.popOut;
    if (!await PictureInPicture.instance.enter()) state = previous;
  }
}
