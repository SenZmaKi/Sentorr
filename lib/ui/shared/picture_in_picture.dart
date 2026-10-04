import 'dart:io';

import 'package:flutter/foundation.dart';

import 'android_pip.dart';
import 'pop_out_window.dart';

/// What a system Picture-in-Picture window's own controls should offer.
class PipControls {
  const PipControls({required this.playing, required this.hasNext});

  final bool playing;
  final bool hasNext;
}

/// The window's own controls, as the viewer pressed them.
enum PipAction { previous, playPause, next }

/// Shrinks the player into a small floating video window over other apps.
/// Desktop resizes its own window; Android hands the activity to the OS.
abstract interface class PictureInPicture {
  static final PictureInPicture instance = switch (null) {
    _ when !kIsWeb && Platform.isAndroid => AndroidPip.instance,
    _ => PopOutWindow.instance,
  };

  bool get supported;

  /// Whether the OS draws the window's controls, so the app draws none.
  bool get systemControls;

  /// False when the platform refused, so nothing changed.
  Future<bool> enter();

  /// A no-op where the user leaves the floating window themselves.
  Future<void> exit();

  /// Whether the window is open, reported when the OS opens or closes it
  /// on its own: leaving the app while playing, or the user expanding it.
  Stream<bool> get changes;

  /// Presses on the OS window's controls.
  Stream<PipAction> get actions;

  /// Tells the OS what its controls show. Null means nothing is playing,
  /// so leaving the app does not open the window.
  Future<void> sync(PipControls? controls);
}
