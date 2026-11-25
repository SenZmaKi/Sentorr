import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../shared/net/online.dart';
import '../torrents/providers.dart';
import 'models.dart';
import 'file_damage.dart';
import 'integrity_result.dart';
export 'integrity_result.dart';
import 'notifier.dart';

final _log = Logger('sentorr.library.integrity');

final libraryIntegrityProvider = Provider<LibraryIntegrity>(
  LibraryIntegrity.new,
);

class IncompleteMedia implements Exception {
  const IncompleteMedia();
  @override
  String toString() =>
      'This file is incomplete or damaged. Verify and recover '
      'it to download the missing pieces.';
}

/// Checks the receiving file against its original torrent, independently of
/// the source's completion claim. Metadata is fetched only while online.
class LibraryIntegrity {
  LibraryIntegrity(this.ref);
  final Ref ref;

  Future<Uint8List?> metadata(LibraryEntry entry) async {
    if (!await ref.read(internetProbeProvider)()) return null;
    return ref
        .read(torrentMetadataProvider)
        .fetch(entry.release, CancelToken());
  }

  /// Checks all selected-file pieces, regardless of container or failure offset.
  Future<IntegrityResult> check(
    LibraryEntry entry, {
    OnIntegrityProgress? onProgress,
  }) async {
    var stage = 'fetching torrent metadata';
    try {
      onProgress?.call(const IntegrityProgress(IntegrityStage.details));
      final data = await metadata(entry);
      if (data == null) {
        return const IntegrityResult(
          IntegrityState.unavailable,
          'Verification is unavailable offline. Connect to the internet '
          'and retry verification.',
        );
      }
      stage = 'checking local torrent data';
      _log.info('Verifying ${entry.id} (${entry.infoHash})');
      await verify(entry, entry.path, data, onProgress: onProgress);
      _log.info('Verified ${entry.id}');
      return const IntegrityResult(
        IntegrityState.valid,
        'No missing or damaged pieces found. All torrent pieces for this '
        'file are valid.',
      );
    } on IncompleteMedia {
      return const IntegrityResult(
        IntegrityState.damaged,
        'This file has missing or damaged data. Recover it to download '
        'the missing pieces.',
      );
    } on UnverifiableMedia {
      return const IntegrityResult(
        IntegrityState.unavailable,
        'Verification could not confirm all pieces. Neighbouring torrent '
        'files may be needed to check shared boundary pieces.',
      );
    } on Object catch (error, stack) {
      _log.warning(
        'Could not verify ${entry.id} (${entry.infoHash}) while $stage',
        error,
        stack,
      );
      return const IntegrityResult(
        IntegrityState.unavailable,
        'Verification could not finish. Retry verification. If it keeps '
        'failing, check the app logs for the verification error.',
      );
    }
  }

  Future<void> verify(
    LibraryEntry entry,
    String path,
    Uint8List data, {
    OnIntegrityProgress? onProgress,
  }) async {
    final engine = TorrentEngine();
    const owner = 'verification';
    StreamSubscription<List<TorrentSnapshot>>? checking;
    try {
      onProgress?.call(const IntegrityProgress(IntegrityStage.file));
      final hash = await engine.add(
        TorrentSource.metadata(data, expectedInfoHash: entry.infoHash),
        owner: owner,
        directory: p.dirname(path),
        storage: TorrentStorage.kept,
      );
      final files = await engine.metadata(hash);
      final file = files.where((f) => f.index == entry.fileIndex).firstOrNull;
      if (file == null) throw const UnverifiableMedia();
      if (!await File(path).exists() ||
          await File(path).length() != file.length) {
        throw const IncompleteMedia();
      }
      await engine.rename(hash, {entry.fileIndex: p.basename(path)});
      onProgress?.call(const IntegrityProgress(IntegrityStage.pieces));
      if (onProgress != null) {
        // Monotonic: a check libtorrent began on add may yield to the recheck.
        var fraction = 0.0;
        checking = engine.states.listen((torrents) {
          final t = torrents.where((t) => t.infoHash == hash).firstOrNull;
          if (t?.transferState != TorrentTransferState.checkingFiles) return;
          fraction = max(fraction, t!.checkingProgress);
          onProgress(IntegrityProgress(IntegrityStage.pieces, fraction));
        }, onError: (Object _) {});
      }
      final bytes = await engine.verify(hash);
      await checking?.cancel();
      onProgress?.call(const IntegrityProgress(IntegrityStage.pieces, 1));
      if (entry.fileIndex >= bytes.length ||
          bytes[entry.fileIndex] != file.length) {
        // Boundary-piece ambiguity cannot explain an invalid MP4 header.
        // Keep full hashing for every format; this supplies extra evidence
        // when a multi-file torrent lacks neighbouring boundary bytes.
        if (hasMissingMp4Header(path, mediaName: entry.path) ||
            files.where((f) => !f.isPadFile && f.length > 0).length == 1) {
          throw const IncompleteMedia();
        }
        throw const UnverifiableMedia();
      }
    } finally {
      await checking?.cancel();
      await engine.close();
    }
  }

  /// Reuses existing bytes; the torrent engine checks them and fetches missing
  /// pieces. The replacement queue record cannot inherit stale completion.
  Future<void> recover(LibraryEntry entry) async {
    final data = await metadata(entry);
    if (data == null) {
      throw StateError('Connect to the internet to recover this file.');
    }
    final queue = ref.read(downloadQueueProvider);
    if (queue.items.any((d) => d.id == entry.downloadId)) {
      await queue.cancel(entry.downloadId);
    }
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: entry.item.label,
        torrentData: data,
        destinationDirectory: p.dirname(entry.path),
        selectedFileIndices: [entry.fileIndex],
        renamedFiles: {entry.fileIndex: p.basename(entry.path)},
      ),
    );
    await ref
        .read(libraryProvider.notifier)
        .add(
          LibraryEntry(
            item: entry.item,
            downloadId: id,
            release: entry.release,
            fileIndex: entry.fileIndex,
            path: entry.path,
            addedAt: entry.addedAt,
            origin: entry.origin,
            reason: entry.reason,
          ),
        );
  }
}
