import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;

import 'models.dart';

abstract interface class DownloadBackend {
  DownloadTransfer add(TorrentDownloadJob job);
  void configure(DownloadSettings settings);
  void close();
}

abstract interface class DownloadTransfer {
  DownloadItem snapshot(DownloadItem previous);
  void pause();
  void resume();
  void remove({bool deleteFiles = false});
}

/// All native calls are owned by the download isolate.
class LibtorrentDownloadBackend implements DownloadBackend {
  Session? _session;
  DownloadSettings _settings = const DownloadSettings();
  Session get session {
    if (_session == null) {
      _session = createSession();
      configure(_settings);
    }
    return _session!;
  }

  @override
  void configure(DownloadSettings settings) {
    settings.validate();
    _settings = settings;
    final s = _session;
    if (s == null) return;
    s.applyConfig(
      SessionConfig(
        downloadRateLimit: settings.downloadBytesPerSecond,
        uploadRateLimit: settings.uploadBytesPerSecond,
        connectionsLimit: settings.maxConnections,
      ),
    );
    s.setDhtEnabled(settings.enableDht);
    s.setLsdEnabled(settings.enableLsd);
    s.setUpnpEnabled(settings.enableUpnp);
    s.setNatPmpEnabled(settings.enableNatPmp);
  }

  @override
  DownloadTransfer add(TorrentDownloadJob job) {
    if (job.torrentData.isEmpty) throw ArgumentError('Empty torrent metadata');
    final root = path.normalize(path.absolute(job.destinationDirectory));
    final renames = <int, String>{};
    for (final e in job.renamedFiles.entries) {
      final relative = path.isAbsolute(e.value)
          ? path.relative(e.value, from: root)
          : path.normalize(e.value);
      if (relative == '.' ||
          relative.isEmpty ||
          path.isAbsolute(relative) ||
          path.split(relative).first == '..') {
        throw ArgumentError(
          'Torrent file names must stay within the save directory',
        );
      }
      renames[e.key] = relative;
    }
    Directory(root).createSync(recursive: true);
    final s = session;
    // Add paused: queued jobs must not download before file priorities are set.
    final handle = s.addTorrentFromTags([
      LibtorrentTagItem.bytesValue(LibtorrentTag.torTorrent, job.torrentData),
      LibtorrentTagItem.intValue(
        LibtorrentTag.torTorrentSize,
        job.torrentData.length,
      ),
      LibtorrentTagItem.stringValue(LibtorrentTag.torSavePath, root),
      LibtorrentTagItem.intValue(LibtorrentTag.torPaused, 1),
      LibtorrentTagItem.intValue(LibtorrentTag.torAutoManaged, 0),
      LibtorrentTagItem.intValue(LibtorrentTag.torDuplicateIsError, 1),
      if (renames.isNotEmpty)
        LibtorrentTagItem.renamedFilesValue(
          LibtorrentTag.torRenamedFiles,
          renames,
        ),
    ]);
    try {
      final files = handle.getFiles();
      final indices = job.selectedFileIndices.isEmpty
          ? files.where((f) => (f.flags & 1) == 0).map((f) => f.index).toSet()
          : job.selectedFileIndices.toSet();
      if (indices.isEmpty ||
          indices.any((i) => i < 0 || i >= files.length) ||
          renames.keys.any((i) => i < 0 || i >= files.length)) {
        throw ArgumentError('Invalid torrent file selection');
      }
      handle.prioritizeFiles([
        for (final f in files) indices.contains(f.index) ? 7 : 0,
      ]);
      return _NativeTransfer(s, handle, [
        for (final f in files)
          if (indices.contains(f.index)) f,
      ]);
    } catch (_) {
      s.removeTorrent(handle, deleteFiles: false);
      rethrow;
    }
  }

  @override
  void close() {
    _session?.close();
    _session = null;
  }
}

class _NativeTransfer implements DownloadTransfer {
  _NativeTransfer(this.session, this.handle, this.files);
  final Session session;
  final TorrentHandle handle;
  final List<TorrentFileEntry> files;
  int? _uploadOffset;
  @override
  DownloadItem snapshot(DownloadItem previous) {
    final s = handle.getStatus();
    _uploadOffset ??= previous.uploadedBytes;
    if (s.error.isNotEmpty) throw StateError(s.error);
    final progress = handle.getFileProgress();
    final running =
        previous.status == DownloadStatus.downloading ||
        previous.status == DownloadStatus.seeding;
    return DownloadItem(
      id: previous.id,
      job: previous.job,
      status: previous.status,
      files: List.unmodifiable([
        for (final f in files)
          DownloadFileProgress(
            f.index,
            f.path,
            f.size,
            progress[f.index].clamp(0, f.size),
          ),
      ]),
      downloadBytesPerSecond: running ? s.downloadRate : 0,
      uploadBytesPerSecond: running ? s.uploadRate : 0,
      uploadedBytes: _uploadOffset! + s.allTimeUpload,
      peers: s.numPeers,
      seeds: s.numSeeds,
      seedingStartedAt: previous.seedingStartedAt,
    );
  }

  @override
  void pause() => handle.pause();
  @override
  void resume() {
    handle.resume();
    try {
      handle.forceReannounce();
      handle.forceDhtAnnounce();
    } catch (_) {}
  }

  @override
  void remove({bool deleteFiles = false}) =>
      session.removeTorrent(handle, deleteFiles: deleteFiles);
}
