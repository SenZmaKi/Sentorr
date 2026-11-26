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
import 'local_metadata.dart';
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
/// the source's completion claim. Metadata already on the device is used
/// first; otherwise it is fetched while online.
class LibraryIntegrity {
  LibraryIntegrity(this.ref);
  final Ref ref;

  /// Checks run one at a time: two native sessions must not hash or write
  /// the same torrent's files together.
  Future<void> _tail = Future.value();

  Future<Uint8List?> metadata(LibraryEntry entry) async {
    if (await localMetadata(ref, entry) case final local?) return local;
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
          'Verification needs this torrent\'s details, which are not on this '
          'device. Connect to the internet and retry verification.',
        );
      }
      stage = 'checking local torrent data';
      _log.info('Verifying ${entry.id} (${entry.infoHash})');
      await verify(entry, entry.path, data, onProgress: onProgress);
      _log.info('Verified ${entry.id}');
      await _markVerified(entry);
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
        IntegrityState.inconclusive,
        'Some pieces this file shares with neighbouring torrent files could '
        'not be confirmed. Recovering keeps valid data and downloads any '
        'pieces that fail.',
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

  /// Hashes [path], [entry]'s file or a copy of it on its way, against
  /// [data]. Throws [IncompleteMedia] or [UnverifiableMedia] when it fails.
  Future<void> verify(
    LibraryEntry entry,
    String path,
    Uint8List data, {
    OnIntegrityProgress? onProgress,
  }) {
    final run = _tail.then(
      (_) => _verify(entry, path, data, onProgress: onProgress),
    );
    _tail = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _verify(
    LibraryEntry entry,
    String path,
    Uint8List data, {
    OnIntegrityProgress? onProgress,
  }) async {
    final engine = TorrentEngine();
    const owner = 'verification';
    StreamSubscription<List<TorrentSnapshot>>? checking;
    // The engine saves resume state when it closes. Only the library file's
    // belongs there; a copy's partial must not remap the torrent's file.
    final resume = resumeFileOf(entry);
    final kept = path == entry.path
        ? null
        : await resume.exists()
        ? await resume.readAsBytes()
        : Uint8List(0);
    try {
      onProgress?.call(const IntegrityProgress(IntegrityStage.file));
      final hash = await engine.add(
        TorrentSource.metadata(data, expectedInfoHash: entry.infoHash),
        owner: owner,
        directory: entry.saveDirectory,
        storage: TorrentStorage.kept,
      );
      final files = await engine.metadata(hash);
      final file = files.where((f) => f.index == entry.fileIndex).firstOrNull;
      if (file == null) throw const UnverifiableMedia();
      if (!await File(path).exists() ||
          await File(path).length() != file.length) {
        throw const IncompleteMedia();
      }
      await engine.rename(hash, {
        entry.fileIndex: p.relative(path, from: entry.saveDirectory),
      });
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
        // Boundary-piece ambiguity cannot explain an invalid header.
        // Keep full hashing for every format; this supplies extra evidence
        // when a multi-file torrent lacks neighbouring boundary bytes.
        if (hasMissingHeader(path, mediaName: entry.path) ||
            files.where((f) => !f.isPadFile && f.length > 0).length == 1) {
          throw const IncompleteMedia();
        }
        throw const UnverifiableMedia();
      }
    } finally {
      await checking?.cancel();
      await engine.close();
      if (kept != null) await _restore(resume, kept);
    }
  }

  Future<void> _restore(File resume, Uint8List kept) async {
    try {
      if (kept.isEmpty) {
        if (await resume.exists()) await resume.delete();
      } else {
        await resume.writeAsBytes(kept, flush: true);
      }
    } on FileSystemException catch (error) {
      _log.warning('Could not restore ${resume.path}', error);
    }
  }

  /// Records that [entry]'s file checked intact, unless it changed since.
  /// Failing to record it leaves the file for another check, not invalid.
  Future<void> _markVerified(LibraryEntry entry) async {
    try {
      final library = ref.read(libraryProvider.notifier);
      final current = library.entry(entry.id);
      if (current == null || !current.sameFile(entry)) return;
      await library.update(current.verified(DateTime.now()));
    } on Object catch (error, stack) {
      _log.warning('Could not record verifying ${entry.id}', error, stack);
    }
  }

  /// Reuses existing bytes; the torrent engine checks them and fetches missing
  /// pieces. The replacement queue record cannot inherit stale completion.
  Future<void> recover(LibraryEntry entry) async {
    final data = await metadata(entry);
    if (data == null) {
      throw StateError('Connect to the internet to recover this file.');
    }
    // Replacing the download while a check hashes its files would race.
    await _tail;
    final queue = ref.read(downloadQueueProvider);
    if (queue.items.any((d) => d.id == entry.downloadId)) {
      await queue.cancel(entry.downloadId);
    }
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: entry.item.label,
        torrentData: data,
        trackers: entry.release.trackers,
        destinationDirectory: entry.saveDirectory,
        selectedFileIndices: [entry.fileIndex],
        renamedFiles: {entry.fileIndex: entry.savedName},
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
            bytes: entry.bytes,
          ),
        );
  }
}
