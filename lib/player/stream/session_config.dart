import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../app/services.dart';
import '../../library/notifier.dart';
import '../../settings/notifier.dart';
import '../../shared/persistence/json_file_store.dart';
import '../../torrents/models.dart';
import '../../torrents/providers.dart';
import '../../torrents/metadata_identity.dart';
import 'reusable_torrent.dart';
import 'torrent_cache.dart';

final torrentCacheProvider = Provider<TorrentCache>((ref) {
  final cache = TorrentCache(
    JsonFileStore(ref.watch(appPathsProvider).torrentCacheIndexFile),
    budget: () => ref.read(settingsProvider).streaming.torrentBudgetBytes,
  );
  ref.listen(settingsProvider.select((s) => s.streaming.torrentBudgetBytes), (
    before,
    now,
  ) {
    if (before != null && now < before) unawaited(cache.trim());
  });
  ref.onDispose(cache.close);
  return cache;
});

final torrentCacheRevisionProvider = StreamProvider<int>(
  (ref) => ref.watch(torrentCacheProvider).changes,
);

/// The app wires its cache catalog into device sharing. Lightweight hosts can
/// share only their download library.
final cachedStreamLibraryProvider =
    Provider<({Future<List<CachedTorrent>> Function() list, int revision})>(
      (ref) => (list: () async => const [], revision: 0),
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
final keptTorrentsSizeProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(torrentCacheRevisionProvider);
  return ref.watch(torrentCacheProvider).size(ref.watch(torrentRootsProvider));
});

/// Engine settings for a session streaming [release], keeping its files
/// when watched torrents have a budget.
Future<TorrentStreamConfig> sessionConfigFor(
  Ref ref,
  TorrentRelease release,
) async {
  final s = ref.read(settingsProvider).streaming;
  final cache = ref.read(torrentCacheProvider);
  final existing = await cache.directoryFor(release.infoHash);
  final root = existing == null
      ? ref.read(torrentDirectoryProvider)
      : p.dirname(existing);
  // A download keeps its own files; the cache would only hold a copy.
  final downloaded = ref
      .read(libraryProvider)
      .any((e) => e.infoHash == release.infoHash);
  final retained = downloaded
      ? null
      : await ref.read(torrentCacheProvider).use(root, release.infoHash);
  return TorrentStreamConfig(
    cacheDirectory: root,
    // Small urgent read window while media duration is still being discovered.
    // The playback-position window independently drives disk prefetch.
    readAheadBytes: 2 * 1024 * 1024,
    downloadAheadMinutes: s.limitDownloadAhead ? s.downloadAheadMinutes : 0,
    // File reads use the OS cache; MediaKit owns playback packet caching.
    pieceCacheBytes: 0,
    metadataTimeout: Duration(seconds: s.metadataTimeoutSeconds),
    pieceTimeout: Duration(seconds: s.pieceTimeoutSeconds),
    retainedDirectory: retained,
  );
}

/// Metadata saved with retained streams avoids another provider request.
Future<Uint8List> streamMetadataFor(
  Ref ref,
  TorrentRelease release,
  CancelToken cancel,
) async {
  final directory = await ref
      .read(torrentCacheProvider)
      .directoryFor(release.infoHash);
  if (directory != null) {
    final file = cachedTorrentMetadata(directory);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      try {
        validateMetadataIdentity(bytes, release.infoHash);
        if (cancel.isCancelled) throw cancel.cancelError!;
        return bytes;
      } on FormatException {
        // Old or damaged metadata falls back to the normal verified fetch.
      }
    }
  }
  return ref.read(torrentMetadataProvider).fetch(release, cancel);
}
