import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../player/models.dart';
import '../player/queue_builder.dart';
import '../player/stream/offline_source.dart';
import '../torrents/resolution_models.dart';
import 'models.dart';
import 'notifier.dart';

/// Where else a download may be, e.g. on a paired device; none unless the
/// app provides it.
final peerSourceProvider = Provider<OfflineLookup>(
  (ref) =>
      (_) => null,
);

/// [item]'s download for the player: its file once finished, its torrent
/// while downloading, else a paired device's copy; null when there is none
/// to use.
OfflineSource? offlineSourceFor(Ref ref, PlaybackItem item) {
  final entry = ref.read(libraryProvider.notifier).entry(item.id);
  if (entry == null) return ref.read(peerSourceProvider)(item);
  final download = ref
      .read(downloadsProvider)
      .value
      ?.where((d) => d.id == entry.downloadId)
      .firstOrNull;
  return switch (offlineStateOf(entry, download)) {
    Downloaded() when File(entry.path).existsSync() => LocalFile(entry.path),
    Downloading() => DownloadTorrent(
      TorrentCandidate(
        release: entry.release,
        score: 0,
        qualityScore: 0,
        availabilityScore: 0,
        sizeScore: 0,
        requiresFileSelection: false,
      ),
      entry.fileIndex,
    ),
    _ => ref.read(peerSourceProvider)(item),
  };
}

/// The episodes of [request]'s series that are downloaded, in air order, on
/// the requested episode or the requested season's first: the queue to
/// play when the episode list cannot be fetched, e.g. offline. Null for a
/// movie, or when nothing of the series is downloaded.
PlayQueue? downloadedQueue(Ref ref, PlayRequest request) {
  switch (request) {
    case PlayEpisode(:final series, :final episode, :final season):
      final current = PlaybackItem.episode(series, episode, season: season);
      final items = _downloadedEpisodes(ref, series.id);
      if (items.isEmpty) return null;
      if (!items.any((i) => i.id == current.id)) {
        items
          ..add(current)
          ..sort(_airOrder);
      }
      return PlayQueue(
        items: items,
        index: items.indexWhere((i) => i.id == current.id),
        kind: QueueKind.episodes,
      );
    case PlayTitle(:final title, :final season)
        when title.canHaveEpisodes == true:
      final items = _downloadedEpisodes(ref, title.id);
      if (items.isEmpty) return null;
      final start = season == null
          ? 0
          : items.indexWhere((i) => (i.season ?? 0) >= season);
      return PlayQueue(
        items: items,
        index: start < 0 ? 0 : start,
        kind: QueueKind.episodes,
      );
    case PlayTitle():
      return null;
  }
}

/// [queue] followed by its series' downloaded episodes after its last, for
/// when the next season cannot be fetched; null when there are none.
PlayQueue? withDownloadedAfter(Ref ref, PlayQueue queue) {
  final last = queue.items.last;
  final series = last.series;
  if (series == null) return null;
  final more = _downloadedEpisodes(
    ref,
    series.id,
  ).where((i) => _airOrder(i, last) > 0).toList();
  return more.isEmpty ? null : queue.extended(more);
}

List<PlaybackItem> _downloadedEpisodes(Ref ref, String seriesId) {
  final downloads = {
    for (final d in ref.read(downloadsProvider).value ?? <DownloadItem>[])
      d.id: d,
  };
  return [
    for (final e in ref.read(libraryProvider))
      if (e.item.series?.id == seriesId &&
          offlineStateOf(e, downloads[e.downloadId]) is Downloaded)
        e.item,
  ]..sort(_airOrder);
}

int _airOrder(PlaybackItem a, PlaybackItem b) {
  final season = (a.season ?? 0).compareTo(b.season ?? 0);
  return season != 0 ? season : (a.episode ?? 0).compareTo(b.episode ?? 0);
}
