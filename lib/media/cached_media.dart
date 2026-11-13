import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:torrent_stream/torrent_stream.dart';

import '../player/models.dart';
import '../player/stream/file_choice.dart';
import '../player/stream/offline_source.dart';
import '../player/stream/reusable_torrent.dart';
import '../player/stream/session_config.dart';
import '../sync/shared_streams.dart';
import '../torrents/engine.dart';
import '../torrents/resolution_models.dart';
import '../watching/notifier.dart';

TorrentCandidate cachedCandidate(ReusableTorrent torrent) => TorrentCandidate(
  release: torrent.release,
  score: 0,
  qualityScore: 0,
  availabilityScore: 0,
  sizeScore: 0,
  requiresFileSelection: torrent.release.isPack,
);

Future<CachedTorrent?> cachedMediaFor(Ref ref, PlaybackItem item) => ref
    .read(torrentCacheProvider)
    .find(
      item.id,
      previous: ref
          .read(watchHistoryProvider)
          .where((entry) => entry.id == item.id)
          .firstOrNull
          ?.release,
    );

Future<OfflineSource?> cachedPlaybackFor(Ref ref, PlaybackItem item) async {
  final cached = await cachedMediaFor(ref, item);
  if (cached == null) return null;
  // Legacy entries choose the episode from verified torrent metadata.
  final index = cached.torrent.fileIndex;
  return CachedPlayback(cachedCandidate(cached.torrent), index);
}

/// Restores a dormant torrent through the native engine. The cache lease
/// survives eviction until this verified-byte server closes.
Future<SharedStream?> openCachedStream(
  Ref ref,
  String itemId,
  String hash,
) async {
  final cache = ref.read(torrentCacheProvider);
  final cached = await cache.find(itemId);
  final torrent = cached?.torrent;
  if (cached == null ||
      torrent == null ||
      torrent.release.infoHash.toLowerCase() != hash.toLowerCase()) {
    return null;
  }
  final item =
      torrent.item ??
      ref
          .read(watchHistoryProvider)
          .where((entry) => entry.id == itemId)
          .firstOrNull
          ?.item;
  if (item == null) return null;
  final release = await cache.acquire(cached);
  if (release == null) return null;
  final session = TorrentStreamSession(
    engine: ref.read(torrentEngineProvider),
    config: TorrentStreamConfig(
      cacheDirectory: p.dirname(cached.directory),
      retainedDirectory: p.basename(cached.directory),
      readAheadBytes: 2 * 1024 * 1024,
      pieceCacheBytes: 0,
    ),
  );
  final subscription = session.states.listen((state) {
    if (state.phase == TorrentStreamPhase.closed) unawaited(release());
  });
  try {
    final metadata = await streamMetadataFor(
      ref,
      torrent.release,
      CancelToken(),
    );
    final files = await session.open(
      TorrentSource.metadata(
        metadata,
        expectedInfoHash: torrent.release.infoHash,
        trackers: torrent.release.trackers,
      ),
    );
    final file =
        files.where((f) => f.index == torrent.fileIndex).firstOrNull ??
        playableFile(
          files,
          item,
          pack: torrent.release.isPack,
          seriesPack: torrent.release.isSeriesPack,
        );
    if (file == null) throw StateError('The cached episode is unavailable');
    final stream = await session.prepareFile(
      file.index,
      prepareContainer: false,
      indexMedia: false,
    );
    return SharedStream(item, cachedCandidate(torrent), session, stream);
  } catch (_) {
    await session.close();
    await subscription.cancel();
    await release();
    rethrow;
  }
}

Future<void> pinCachedPlayback(
  Ref ref,
  SharedStream stream,
  String directory,
) async {
  final cache = ref.read(torrentCacheProvider);
  final release = await cache.acquire((
    torrent: ReusableTorrent.fromFile(
      stream.candidate.release,
      stream.stream.file,
      item: stream.item,
    ),
    directory: directory,
  ));
  if (release == null) return;
  if (stream.session.state.phase == TorrentStreamPhase.closed) return release();
  stream.session.states.listen((state) {
    if (state.phase == TorrentStreamPhase.closed) unawaited(release());
  });
}
