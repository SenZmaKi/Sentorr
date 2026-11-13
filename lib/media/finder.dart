import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../library/playback.dart';
import '../library/stream_download.dart';
import '../player/models.dart';
import '../player/stream/offline_source.dart';
import '../player/torrent_search.dart';
import '../sync/copies.dart';
import '../sync/copy_offer.dart';
import '../torrents/resolution_models.dart';
import 'source_lookup.dart';

final _log = Logger('sentorr.media.finder');
final mediaFinderProvider = Provider<MediaFinder>((ref) {
  final finder = MediaFinder(ref);
  ref.onDispose(finder.close);
  return finder;
});

/// The app supplies a bounded refresh of nearby paired devices. Tests and
/// offline hosts can use the last known library without network discovery.
final peerDownloadLookupProvider =
    Provider<Future<CopyOffer?> Function(PlaybackItem)>(
      (ref) => (item) async {
        final offer = ref
            .read(peerCopiesProvider)
            .offer((i) => i.id == item.id);
        return offer.isEmpty ? null : offer;
      },
    );

typedef PlaybackSources = SourceLookup<OfflineSource, PeerFile>;
typedef DownloadSources = SourceLookup<StreamDownloadOffer, CopyOffer>;

/// The same discovery order for streaming and saving. Each intent adapts a
/// found source to its existing player or download action.
class MediaFinder {
  MediaFinder(this._ref);
  final Ref _ref;
  final _downloads = <String, DownloadSources>{};

  void close() {
    for (final lookup in _downloads.values.toList()) {
      lookup.close();
    }
  }

  PlaybackSources playback(
    PlaybackItem item, {
    CancelToken? cancel,
    bool peers = true,
    Set<Uri> excluded = const {},
    Future<TorrentResolution> Function(CancelToken)? search,
  }) => SourceLookup(
    local: () => _optional(() async {
      final local = offlineSourceFor(_ref, item);
      if (local != null && local is! PeerFile) return local;
      return _ref.read(cachedPlaybackProvider)(item);
    }),
    peer: () => _optional(
      () async =>
          peers ? await _ref.read(peerPlaybackProvider)(item, excluded) : null,
    ),
    search:
        search ??
        (token) => _ref.read(torrentSearchProvider)(item, cancel: token),
    cancel: cancel,
  );

  Future<({OfflineSource? source, TorrentResolution? torrents})>
  resolvePlayback(PlaybackItem item, CancelToken cancel) async {
    final lookup = playback(item, cancel: cancel);
    try {
      final local = await lookup.local;
      if (local != null) return (source: local, torrents: null);
      final peer = await lookup.peer;
      if (peer != null) return (source: peer, torrents: null);
      return (source: null, torrents: await lookup.torrents);
    } finally {
      lookup.close();
    }
  }

  DownloadSources? download(PlaybackItem item, {bool peers = true}) {
    if (_downloads.containsKey(item.id)) return null;
    final lookup = SourceLookup<StreamDownloadOffer, CopyOffer>(
      local: () =>
          _optional(() => _ref.read(streamDownloadProvider).offer(item)),
      peer: () => _optional(
        () async =>
            peers ? await _ref.read(peerDownloadLookupProvider)(item) : null,
      ),
      search: (token) => _ref.read(torrentSearchProvider)(item, cancel: token),
      onClose: () => _downloads.remove(item.id),
    );
    _downloads[item.id] = lookup;
    return lookup;
  }

  Future<T?> _optional<T>(Future<T?> Function() lookup) async {
    try {
      return await lookup();
    } catch (error, stack) {
      _log.fine('Source unavailable', error, stack);
      return null;
    }
  }
}
