import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../shared/persistence/json_file_store.dart';
import '../torrents/engine.dart';
import 'models.dart';
import 'queue.dart';
import 'repository.dart';
import 'torrents.dart';

/// The download queue, polled each second while the app runs. Bootstrap
/// initializes it and awaits its writes on shutdown.
final downloadQueueProvider = Provider<DownloadQueue>((ref) {
  final queue = DownloadQueue(
    EngineTorrents(ref.watch(torrentEngineProvider)),
    DownloadRepository(
      JsonFileStore(ref.watch(appPathsProvider).downloadsFile),
    ),
  );
  final timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => unawaited(queue.tick()),
  );
  ref.onDispose(() {
    timer.cancel();
    unawaited(queue.dispose());
  });
  return queue;
});

/// Every download, newest state first published.
final downloadsProvider = StreamProvider<List<DownloadItem>>((ref) async* {
  final queue = ref.watch(downloadQueueProvider);
  yield queue.items;
  yield* queue.changes;
});
