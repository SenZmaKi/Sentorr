import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../player/models.dart';
import '../player/session.dart';
import '../player/stream/reusable_torrent.dart';
import '../player/stream/session_config.dart';
import '../sync/shared_streams.dart';
import '../watching/notifier.dart';
import 'planner.dart';

typedef StreamDownloadOffer = ({
  ReusableTorrent torrent,
  bool playing,
  Future<bool> Function() save,
});

final streamDownloadProvider = Provider<StreamDownloads>(StreamDownloads.new);

/// Resolves a download from playback or the local cache before searching.
class StreamDownloads {
  StreamDownloads(this._ref);
  final Ref _ref;

  Future<StreamDownloadOffer?> offer(PlaybackItem item) async {
    final cache = _ref.read(torrentCacheProvider);
    final planner = _ref.read(downloadPlannerProvider);
    final live = _ref.read(sharedStreamsProvider)[item.id];
    final source = live?.session.source;
    final playing = _ref.read(playerSessionProvider)?.current?.id == item.id;
    Future<CachedTorrent?> find() => cache.find(
      item.id,
      previous: _ref
          .read(watchHistoryProvider)
          .where((entry) => entry.id == item.id)
          .firstOrNull
          ?.release,
    );
    Future<bool> saveCached(CachedTorrent cached) =>
        cache.reuse(cached, () async {
          await planner.downloadStream(
            item,
            cached.torrent,
            metadata: cached.torrent.fileIndex == null
                ? null
                : await cachedTorrentMetadata(cached.directory).readAsBytes(),
            directory: cached.directory,
            storage: TorrentStorage.cached,
          );
        });

    if (live != null && source is TorrentMetadataSource) {
      final session = live.session;
      final torrent = ReusableTorrent.fromFile(
        live.candidate.release,
        live.stream.file,
      );
      return (
        torrent: torrent,
        playing: playing,
        save: () async {
          final snapshot = session.engine.torrent(
            torrent.release.infoHash.toLowerCase(),
          );
          if (snapshot != null && snapshot.owners.contains(session.owner)) {
            if (snapshot.storage == TorrentStorage.cached) {
              final cached = (torrent: torrent, directory: snapshot.savePath);
              if (await cache.reuse(
                cached,
                () => planner.downloadStream(
                  item,
                  torrent,
                  metadata: source.bytes,
                  directory: snapshot.savePath,
                  storage: TorrentStorage.cached,
                ),
                requirePayload: false,
              )) {
                return true;
              }
            } else {
              await planner.downloadStream(
                item,
                torrent,
                metadata: source.bytes,
                directory: session.config.cacheDirectory,
                storage: TorrentStorage.temporary,
              );
              return true;
            }
          }
          final cached = await find();
          return cached != null &&
              cached.torrent.release.infoHash == torrent.release.infoHash &&
              await saveCached(cached);
        },
      );
    }

    final cached = await find();
    if (cached == null) return null;
    return (
      torrent: cached.torrent,
      playing: false,
      save: () => saveCached(cached),
    );
  }
}
