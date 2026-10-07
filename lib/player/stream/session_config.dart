import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../app/services.dart';
import '../../library/notifier.dart';
import '../../settings/notifier.dart';
import '../../shared/persistence/json_file_store.dart';
import '../../torrents/models.dart';
import 'torrent_cache.dart';

final torrentCacheProvider = Provider<TorrentCache>(
  (ref) => TorrentCache(
    JsonFileStore(ref.watch(appPathsProvider).torrentCacheIndexFile),
  ),
);

/// Where torrents are saved: the viewer's folder or the app's own.
final torrentDirectoryProvider = Provider<String>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.streaming.torrentDirectory)) ??
      ref.watch(appPathsProvider).streamCacheDirectory.path,
);

/// Every folder kept torrents may be in: the current one and the app's own.
final torrentRootsProvider = Provider<List<String>>(
  (ref) => {
    ref.watch(torrentDirectoryProvider),
    ref.watch(appPathsProvider).streamCacheDirectory.path,
  }.toList(),
);

/// Disk used by kept torrents and sessions' leftovers.
final keptTorrentsSizeProvider = FutureProvider.autoDispose<int>(
  (ref) =>
      ref.watch(torrentCacheProvider).size(ref.watch(torrentRootsProvider)),
);

/// Engine settings for a session streaming [release], keeping its files
/// when recent torrents are kept.
Future<TorrentStreamConfig> sessionConfigFor(
  Ref ref,
  TorrentRelease release,
) async {
  final s = ref.read(settingsProvider).streaming;
  final root = ref.read(torrentDirectoryProvider);
  // A download keeps its own files; the cache would only hold a copy.
  final downloaded = ref
      .read(libraryProvider)
      .any((e) => e.infoHash == release.infoHash);
  final retained = downloaded
      ? null
      : await ref
            .read(torrentCacheProvider)
            .use(root, release.infoHash, keep: s.keepRecentTorrents);
  return TorrentStreamConfig(
    cacheDirectory: root,
    // Small urgent read window while media duration is still being discovered.
    // The playback-position window independently drives disk prefetch.
    readAheadBytes: 2 * 1024 * 1024,
    downloadAheadMinutes: s.limitDownloadAhead ? s.downloadAheadMinutes : 0,
    // MediaKit owns packet caching; avoid retaining duplicate raw pieces.
    pieceCacheBytes: 0,
    metadataTimeout: Duration(seconds: s.metadataTimeoutSeconds),
    pieceTimeout: Duration(seconds: s.pieceTimeoutSeconds),
    retainedDirectory: retained,
  );
}
