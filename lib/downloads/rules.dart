/// Pure download rules the queue applies: which files, how far along,
/// when sharing is done.
library;

import 'package:torrent_stream/torrent_stream.dart';

import 'models.dart';

/// [job]'s files by index: its selection, or every non-padding file.
/// Throws when the selection or renames name files the torrent lacks.
Map<int, TorrentStreamFile> chooseFiles(
  TorrentDownloadJob job,
  List<TorrentStreamFile> files,
) {
  final byIndex = {for (final f in files) f.index: f};
  final indices = job.selectedFileIndices.isEmpty
      ? [
          for (final f in files)
            if (!f.isPadFile) f.index,
        ]
      : job.selectedFileIndices;
  if (indices.isEmpty ||
      indices.any((i) => byIndex[i] == null || byIndex[i]!.isPadFile) ||
      job.renamedFiles.keys.any((i) => byIndex[i] == null)) {
    throw ArgumentError('Invalid torrent file selection');
  }
  return {for (final i in indices) i: byIndex[i]!};
}

/// Whether a finished download that began sharing at [started] is done
/// sharing under [settings].
bool seedingDone(
  DownloadItem item,
  DownloadSettings settings,
  DateTime started,
) => switch (settings.seedingMode) {
  SeedingMode.disabled => true,
  SeedingMode.indefinitely => false,
  SeedingMode.limited =>
    item.uploadedBytes >= item.totalBytes * settings.seedRatio &&
        DateTime.now().difference(started) >= settings.seedTime,
};

/// [item] with [torrent]'s progress; rates only while it transfers.
/// [uploadedBefore] is what earlier runs shared, since the engine counts
/// from each add.
DownloadItem progressOf(
  DownloadItem item,
  TorrentSnapshot torrent, {
  required int uploadedBefore,
}) {
  final moving =
      item.status == DownloadStatus.downloading ||
      item.status == DownloadStatus.seeding;
  return item.copyWith(
    files: [
      for (final f in item.files)
        DownloadFileProgress(
          f.index,
          f.path,
          f.totalBytes,
          torrent.bytesOf(f.index),
        ),
    ],
    downloadBytesPerSecond: moving
        ? torrent.downloadBytesPerSecond.toDouble()
        : 0,
    uploadBytesPerSecond: moving ? torrent.uploadBytesPerSecond.toDouble() : 0,
    uploadedBytes: uploadedBefore + torrent.uploadedBytes,
    peers: moving ? torrent.peers : 0,
    seeds: moving ? torrent.seeds : 0,
  );
}
