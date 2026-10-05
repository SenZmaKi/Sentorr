import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../shared/parallel.dart';
import 'payload.dart';
import 'file_version.dart';

/// What this device offers paired devices: its finished downloads whose
/// files are still on disk, and those still on their way.
Future<PeerLibrary> sharedLibrary(Ref ref) async {
  final downloads = _downloads(ref);
  final completed = <LibraryEntry>[];
  final coming = <PeerDownload>[
    for (final c in ref.read(copyingProvider).values)
      PeerDownload(
        item: c.entry.item,
        transfer: PeerTransfer.copying,
        progress: c.progress,
      ),
  ];
  for (final e in ref.read(libraryProvider)) {
    final download = downloads[e.downloadId];
    switch (offlineStateOf(e, download)) {
      case Downloaded():
        completed.add(e);
      case Downloading(:final status, :final progress):
        coming.add(
          PeerDownload(
            item: e.item,
            transfer: _transfer(status),
            progress: progress,
            size: download?.totalBytes ?? 0,
          ),
        );
      default:
    }
  }
  final media = await parallelMapOrdered<LibraryEntry, PeerMedia?>(
    completed,
    maxConcurrent: 4,
    operation: (entry) async {
      final file = File(entry.path);
      final stat = await file.stat();
      return stat.type == FileSystemEntityType.file
          ? PeerMedia.of(
              entry,
              stat.size,
              version: fileVersionFromStat(file, stat),
            )
          : null;
    },
  );
  return PeerLibrary(media: media.nonNulls.toList(), downloads: coming);
}

/// [itemId]'s finished file, or null when this device has none to share.
File? sharedFile(Ref ref, String itemId) {
  final entry = ref.read(libraryProvider.notifier).entry(itemId);
  if (entry == null) return null;
  final download = _downloads(ref)[entry.downloadId];
  if (offlineStateOf(entry, download) is! Downloaded) return null;
  final file = File(entry.path);
  return file;
}

/// Changes when what this device shares does: an item added, removed,
/// started, paused or finished, but not as bytes arrive.
final sharedLibraryShapeProvider = Provider<String>((ref) {
  final downloads = {
    for (final d in ref.watch(downloadsProvider).value ?? <DownloadItem>[])
      d.id: d.status,
  };
  return [
    for (final id in ref.watch(copyingProvider).keys) '$id:copying',
    for (final e in ref.watch(libraryProvider))
      '${e.id}:${e.path}:${e.release.infoHash}:${e.fileIndex}:${downloads[e.downloadId]?.name}',
  ].join(',');
});

Map<String, DownloadItem> _downloads(Ref ref) => {
  for (final d in ref.read(downloadsProvider).value ?? <DownloadItem>[])
    d.id: d,
};

PeerTransfer _transfer(OfflineProgress status) => switch (status) {
  OfflineProgress.preparing || OfflineProgress.queued => PeerTransfer.queued,
  OfflineProgress.downloading => PeerTransfer.downloading,
  OfflineProgress.paused => PeerTransfer.paused,
  OfflineProgress.copying => PeerTransfer.copying,
};
