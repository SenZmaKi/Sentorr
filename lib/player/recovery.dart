import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../settings/streaming_settings.dart';
import '../shared/persistence/json_file_store.dart';
import '../watching/models.dart';

/// Device-local active playback, separate from synced watch history.
class PlaybackRecovery {
  PlaybackRecovery(this.store);
  final JsonFileStore store;
  Future<void> Function()? checkpoint;

  Future<WatchEntry?> load() async =>
      WatchEntry.fromJson((await store.read())?['active']);

  Future<void> save(WatchEntry? entry) =>
      store.write({'version': 1, 'active': entry?.toJson()});

  Future<void> flush() async {
    await checkpoint?.call();
    await store.flushed;
  }

  static Duration start(
    WatchEntry entry, {
    StreamingSettings settings = const StreamingSettings(),
  }) => settings.resumePosition(entry.position);
}

final playbackRecoveryProvider = Provider((ref) {
  return PlaybackRecovery(
    JsonFileStore(ref.read(appPathsProvider).playbackRecoveryFile),
  );
});
