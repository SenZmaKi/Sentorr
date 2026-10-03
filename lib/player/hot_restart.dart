import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Native mpv outlives the Dart isolate on hot restart. Detach its Dart
/// callback in the runner's pre-restart hook, before the trampoline disappears.
class PlayerHotRestart {
  static const _channel = MethodChannel('sentorr/player_hot_restart');

  static Future<void> register(Player player) async {
    if (!kDebugMode || !Platform.isMacOS) return;
    await _channel.invokeMethod<void>('register', await player.handle);
  }

  static Future<void> unregister(Player player) async {
    if (!kDebugMode || !Platform.isMacOS) return;
    await _channel.invokeMethod<void>('unregister', await player.handle);
  }
}
