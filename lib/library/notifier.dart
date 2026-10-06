import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../app/services.dart';
import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../settings/notifier.dart';
import 'models.dart';
import 'repository.dart';

final _log = Logger('sentorr.library');

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) =>
      throw StateError('Bootstrap must override libraryRepositoryProvider'),
);
final initialLibraryProvider = Provider<List<LibraryEntry>>(
  (ref) => throw StateError('Bootstrap must override initialLibraryProvider'),
);

/// The folder new downloads go to.
final downloadsDirectoryProvider = Provider<String>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.downloads.directory)) ??
      ref.watch(appPathsProvider).defaultDownloadsDirectory.path,
);

/// Downloaded movies and episodes, newest first.
final libraryProvider = NotifierProvider<LibraryNotifier, List<LibraryEntry>>(
  LibraryNotifier.new,
);

class LibraryNotifier extends Notifier<List<LibraryEntry>> {
  late LibraryRepository _repository;

  @override
  List<LibraryEntry> build() {
    _repository = ref.watch(libraryRepositoryProvider);
    return ref.watch(initialLibraryProvider);
  }

  LibraryEntry? entry(String id) => state.where((e) => e.id == id).firstOrNull;

  Future<void> add(LibraryEntry entry) {
    _log.info('Added ${entry.item} as download ${entry.downloadId}');
    return _commit([entry, ...state.where((e) => e.id != entry.id)]);
  }

  /// Stops [id]'s download and deletes its file. Other episodes of the same
  /// torrent keep theirs, so files are removed here rather than by the
  /// torrent engine.
  Future<void> remove(String id) => removeAll({id});

  /// Removes [ids] from the library at once, then stops their downloads and
  /// deletes their files once the engine has let each torrent go.
  Future<void> removeAll(Set<String> ids) async {
    final gone = [
      for (final e in state)
        if (ids.contains(e.id)) e,
    ];
    if (gone.isEmpty) return;
    await _commit([...state.where((e) => !ids.contains(e.id))]);
    final queue = ref.read(downloadQueueProvider);
    await Future.wait([
      for (final entry in gone)
        () async {
          _log.info('Removing ${entry.item} and ${entry.path}');
          // Cleared from download history, the queue no longer knows it.
          if (queue.items.any((d) => d.id == entry.downloadId)) {
            await queue.cancel(entry.downloadId);
          }
          await _delete(entry);
        }(),
    ]);
  }

  /// Queues [id]'s failed or paused download again.
  Future<void> retry(String id) async {
    final entry = this.entry(id);
    if (entry != null) {
      await ref.read(downloadQueueProvider).resume(entry.downloadId);
    }
  }

  Future<void> _delete(LibraryEntry entry) async {
    final file = File(entry.path);
    try {
      if (await file.exists()) await file.delete();
      // Season and title folders go once nothing else is in them.
      var folder = file.parent;
      final root = p.normalize(ref.read(downloadsDirectoryProvider));
      while (p.isWithin(root, folder.path) &&
          await folder.exists() &&
          await folder.list().isEmpty) {
        await folder.delete();
        folder = folder.parent;
      }
    } on FileSystemException catch (error) {
      _log.warning('Could not delete ${entry.path}', error);
    }
  }

  Future<void> _commit(List<LibraryEntry> next) {
    state = List.unmodifiable(next);
    return _repository.save(state);
  }
}

/// Items being prepared for download: torrent found, file being chosen.
final planningProvider = NotifierProvider<PlanningNotifier, Set<String>>(
  PlanningNotifier.new,
);

class PlanningNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void start(String id) => state = {...state, id};
  void end(String id) => state = {...state}..remove(id);
}

/// A file on its way from a paired device instead of a torrent. Its
/// [entry] joins the library once the file is complete.
class CopyProgress {
  const CopyProgress(this.entry, {required this.from, this.progress = 0});
  final LibraryEntry entry;

  /// The device's name.
  final String from;

  /// 0–1; 0 also while waiting for earlier copies.
  final double progress;
}

/// Items being copied from paired devices, by id.
final copyingProvider =
    NotifierProvider<CopyingNotifier, Map<String, CopyProgress>>(
      CopyingNotifier.new,
    );

class CopyingNotifier extends Notifier<Map<String, CopyProgress>> {
  @override
  Map<String, CopyProgress> build() => const {};

  void set(CopyProgress copy) => state = {...state, copy.entry.id: copy};
  void end(String id) => state = {...state}..remove(id);
}

/// Whether item [id] can be asked to download: not downloaded, on its
/// way, copying or in another review. A failed download can be again.
bool downloadable(Ref ref, String id) {
  if (ref.read(planningProvider).contains(id) ||
      ref.read(copyingProvider).containsKey(id)) {
    return false;
  }
  final entry = ref.read(libraryProvider.notifier).entry(id);
  if (entry == null) return true;
  final download = ref
      .read(downloadsProvider)
      .value
      ?.where((d) => d.id == entry.downloadId)
      .firstOrNull;
  return offlineStateOf(entry, download) is DownloadFailed;
}

/// Where item [id] stands offline.
final offlineStateProvider = Provider.family<OfflineState, String>((ref, id) {
  if (ref.watch(copyingProvider.select((all) => all[id])) case final copy?) {
    return copy.state;
  }
  if (ref.watch(planningProvider).contains(id)) return const Planning();
  final entry = ref.watch(
    libraryProvider.select((all) => all.where((e) => e.id == id).firstOrNull),
  );
  if (entry == null) return const NotDownloaded();
  final download = ref.watch(
    downloadsProvider.select(
      (all) => all.value?.where((d) => d.id == entry.downloadId).firstOrNull,
    ),
  );
  return offlineStateOf(entry, download);
});

/// [entry]'s state given its download, or its file when the download was
/// cleared from history.
OfflineState offlineStateOf(LibraryEntry entry, DownloadItem? download) {
  if (download == null) {
    return File(entry.path).existsSync()
        ? Downloaded(entry)
        : DownloadFailed(entry, 'The file is missing');
  }
  if (download.hasFinishedDownloading) return Downloaded(entry);
  final progress = download.progress;
  return switch (download.status) {
    DownloadStatus.completed || DownloadStatus.seeding => Downloaded(entry),
    DownloadStatus.failed ||
    DownloadStatus.cancelled => DownloadFailed(entry, download.error),
    DownloadStatus.preparing => Downloading(
      entry,
      progress: progress,
      status: OfflineProgress.preparing,
    ),
    DownloadStatus.queued => Downloading(
      entry,
      progress: progress,
      status: OfflineProgress.queued,
    ),
    DownloadStatus.downloading => Downloading(
      entry,
      progress: progress,
      status: OfflineProgress.downloading,
    ),
    DownloadStatus.paused => Downloading(
      entry,
      progress: progress,
      status: OfflineProgress.paused,
    ),
  };
}

extension CopyState on CopyProgress {
  OfflineState get state => Downloading(
    entry,
    progress: progress,
    status: OfflineProgress.copying,
    from: from,
  );
}
