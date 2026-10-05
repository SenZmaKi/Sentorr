import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import '../engine_models.dart';
import '../models.dart';
import 'cancellation.dart';
import 'piece_scheduler.dart';
import 'stream_host.dart';

/// Normal libtorrent priority for files downloaded in full.
const wantedPriority = 4;

class TorrentOwner {
  final wanted = <int>{};
  bool paused = false;
}

/// One torrent in the shared session and everyone holding it. Native calls
/// stay in the engine isolate.
class TorrentEntry {
  TorrentEntry({
    required this.infoHash,
    required this.handle,
    required this.savePath,
    required this.storage,
  });
  final String infoHash;
  final TorrentHandle handle;
  String savePath;
  TorrentStorage storage;

  /// Engine-created folders to delete when the torrent leaves.
  final temporary = <Directory>[];
  final owners = <String, TorrentOwner>{};
  final streams = <int, StreamHost>{};
  final lifetime = Cancellation();
  final ready = Completer<void>();
  List<TorrentFileEntry> files = const [];
  PieceScheduler? scheduler;
  Uint8List _base = Uint8List(0);
  bool? _appliedPause;
  Future<void> _priorities = Future.value();
  TorrentStatus? _status;
  List<int> _fileBytes = const [];

  Set<int> get wanted => {
    for (final o in owners.values)
      if (!o.paused) ...o.wanted,
  };

  /// Paused only when every owner paused it, so a stream always runs.
  bool get paused => owners.values.every((o) => o.paused);

  /// Waits for metadata, then downloads nothing until an owner wants it.
  Future<void> prepare(Future<void> Function(bool Function()) until) async {
    await until(() {
      try {
        files = handle.getFiles();
        return files.isNotEmpty;
      } catch (_) {
        return false;
      }
    });
    scheduler = PieceScheduler(handle, base: (p) => _base[p]);
    await _setFiles(until);
    if (!ready.isCompleted) ready.complete();
  }

  /// Downloads the files owners want, keeping stream windows in place.
  Future<void> applyWanted(Future<void> Function(bool Function()) until) {
    if (files.isEmpty) return Future.value();
    final operation = _priorities.then((_) => _setFiles(until));
    _priorities = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _setFiles(Future<void> Function(bool Function()) until) async {
    final wanted = this.wanted;
    final priorities = [
      for (final f in files)
        wanted.contains(f.index) && (f.flags & 1) == 0 ? wantedPriority : 0,
    ];
    handle.prioritizeFiles(priorities);
    // Priorities apply on libtorrent's thread; windows set before then
    // would be overwritten.
    await until(() {
      final applied = handle.getFilePriorities();
      for (var n = 0; n < priorities.length; n++) {
        if (applied[n] != priorities[n]) return false;
      }
      return true;
    });
    final base = Uint8List(handle.numPieces);
    final length = handle.pieceLength;
    for (final f in files) {
      if (priorities[f.index] == 0 || f.size == 0) continue;
      final last = (f.offset + f.size - 1) ~/ length;
      for (var p = f.offset ~/ length; p <= last; p++) {
        base[p] = wantedPriority;
      }
    }
    _base = base;
    scheduler?.reapply();
  }

  void applyPause() {
    final paused = this.paused;
    if (_appliedPause == paused) return;
    if (paused) {
      handle.pause();
      _appliedPause = true;
      return;
    }
    handle.resume();
    _appliedPause = false;
    try {
      handle.forceReannounce();
      handle.forceDhtAnnounce();
    } catch (_) {}
  }

  void connect(List peers) {
    for (final peer in peers) {
      handle.connectPeer(
        address: peer['address'] as String,
        port: peer['port'] as int,
      );
    }
  }

  TorrentStreamFile fileOf(TorrentFileEntry f) => TorrentStreamFile(
    index: f.index,
    path: f.path,
    length: f.size,
    isPadFile: (f.flags & 1) != 0,
  );

  /// Reads native state; throws when the handle is unusable.
  TorrentSnapshot snapshot() {
    final status = _status = handle.getStatus();
    if (files.isNotEmpty) _fileBytes = handle.getFileProgress();
    return describe(status);
  }

  /// The last state read, e.g. as the torrent leaves.
  TorrentSnapshot describe([TorrentStatus? status]) {
    final s = status ?? _status;
    final live = status != null;
    return TorrentSnapshot(
      infoHash: infoHash,
      savePath: savePath,
      storage: storage,
      owners: Set.unmodifiable(owners.keys),
      pausedOwners: Set.unmodifiable({
        for (final e in owners.entries)
          if (e.value.paused) e.key,
      }),
      files: List.unmodifiable(files.map(fileOf)),
      wanted: Set.unmodifiable(wanted),
      fileBytes: List.unmodifiable([
        for (final f in files)
          f.index < _fileBytes.length
              ? _fileBytes[f.index].clamp(0, f.size)
              : 0,
      ]),
      paused: paused,
      transferState: live
          ? transferState(s!.state)
          : TorrentTransferState.unknown,
      downloadBytesPerSecond: live ? s!.downloadPayloadRate.round() : 0,
      uploadBytesPerSecond: live ? s!.uploadPayloadRate.round() : 0,
      receivedBytes: s?.allTimeDownload ?? 0,
      uploadedBytes: s?.allTimeUpload ?? 0,
      verifiedBytes: s?.totalDone ?? 0,
      peers: live ? s!.numPeers : 0,
      seeds: live ? s!.numSeeds : 0,
      knownPeers: s?.listPeers ?? 0,
      connections: live ? s!.numConnections : 0,
      connectionCandidates: live ? s!.connectCandidates : 0,
      streams: List.unmodifiable([
        for (final stream in streams.values)
          StreamSnapshot(
            id: stream.id,
            owner: stream.owner,
            file: fileOf(stream.file),
            cachedBytes: stream.bytes.cachedBytes,
            servedBytes: stream.server?.servedBytes ?? 0,
            requests: stream.server?.requestCount ?? 0,
          ),
      ]),
      error: s == null || s.error.isEmpty ? null : s.error,
    );
  }
}

TorrentTransferState transferState(int? native) => switch (native) {
  1 => TorrentTransferState.checkingFiles,
  2 => TorrentTransferState.downloadingMetadata,
  3 => TorrentTransferState.downloading,
  4 => TorrentTransferState.finished,
  5 => TorrentTransferState.seeding,
  7 => TorrentTransferState.checkingResumeData,
  _ => TorrentTransferState.unknown,
};
