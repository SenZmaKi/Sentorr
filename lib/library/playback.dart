import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../player/models.dart';
import '../player/stream/offline_source.dart';
import '../torrents/resolution_models.dart';
import 'models.dart';
import 'notifier.dart';

/// [item]'s download for the player: its file once finished, its torrent
/// while downloading; null when there is none to use.
OfflineSource? offlineSourceFor(Ref ref, PlaybackItem item) {
  final entry = ref.read(libraryProvider.notifier).entry(item.id);
  if (entry == null) return null;
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
    _ => null,
  };
}
