import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/session.dart';
import '../settings/notifier.dart';
import '../shared/net/mobile_data.dart';
import '../shared/net/online.dart';

/// Why automatic downloads wait right now.
enum BackgroundHold {
  /// The player is open, even paused or docked.
  playback,
  offline,

  /// On mobile data, which automatic downloads stay off unless allowed.
  mobileData,
}

/// Why automatic downloads, of followed series and smart downloads, wait;
/// null when they may run. The queue holds the ones queued and the
/// planners start no new ones.
final backgroundHoldProvider = Provider<BackgroundHold?>((ref) {
  if (ref.watch(playerSessionProvider.select((s) => s != null))) {
    return BackgroundHold.playback;
  }
  if (!ref.watch(onlineProvider)) return BackgroundHold.offline;
  final allowMobile = ref.watch(
    settingsProvider.select((s) => s.downloads.automaticOnMobileData),
  );
  if (!allowMobile && ref.watch(onMobileDataProvider)) {
    return BackgroundHold.mobileData;
  }
  return null;
});
