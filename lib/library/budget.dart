import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../following/notifier.dart';
import '../player/models.dart';
import '../player/session.dart';
import '../settings/notifier.dart';
import '../smart_downloads/reserve.dart';
import '../watching/notifier.dart';
import 'budget_requests.dart';
import 'models.dart';
import 'notifier.dart';
import 'planner.dart';

export 'budget_requests.dart';

final _log = Logger('sentorr.library.budget');

/// A download or copy, or room held for one being queued, and its size.
typedef _Space = (LibraryEntry?, int);

/// No room left in the download budget, and nothing could be deleted, or
/// the viewer kept the budget as it was.
class DownloadBudgetFull extends DownloadPlanException {
  const DownloadBudgetFull()
    : super('Not enough room left in the space for downloads.');
}

/// Space downloads and copies take, by who asked for them.
class BudgetUsage {
  const BudgetUsage({
    required this.yours,
    required this.automatic,
    required this.budget,
  });

  /// What the viewer downloaded or copied, which only they delete.
  final int yours;

  /// Series and smart downloads, which make room by deleting watched ones.
  final int automatic;
  final int budget;

  int get used => yours + automatic;
  int get free => budget - used;
}

final downloadBudgetProvider = Provider<DownloadBudget>((ref) {
  final budget = DownloadBudget(ref);
  ref.listen(settingsProvider.select((s) => s.downloads.budgetBytes), (
    before,
    now,
  ) {
    if (before != null && now < before) unawaited(budget.trim());
  });
  return budget;
});

/// The space the download budget allows and what fills it, for Settings.
final budgetUsageProvider = FutureProvider.autoDispose<BudgetUsage>((ref) {
  ref.watch(libraryProvider);
  // Which copies run, not how far along they are.
  ref.watch(copyingProvider.select((c) => c.keys.join(' ')));
  ref.watch(settingsProvider.select((s) => s.downloads.budgetBytes));
  return ref.watch(downloadBudgetProvider).usage();
});

/// Keeps downloads and copies within the space the viewer gave them. Each
/// counts at its full size from when it is queued, so the budget holds
/// before it finishes. Room is made by deleting watched automatic
/// downloads, and for anything but a smart pick, unwatched smart picks too;
/// the viewer's own downloads are never deleted.
class DownloadBudget {
  DownloadBudget(this._ref);
  final Ref _ref;

  /// Room held for items being queued, until their library entry counts.
  final _held = <String, int>{};
  Future<void> _tail = Future.value();

  /// Budgets suggested when raising one, rounded up to this.
  static const raiseStep = 5 * 1024 * 1024 * 1024;

  int get _budget => _ref.read(settingsProvider).downloads.budgetBytes;

  Future<BudgetUsage> usage() async {
    var yours = 0, automatic = 0;
    for (final (entry, bytes) in await _sizes()) {
      entry?.automatic ?? false ? automatic += bytes : yours += bytes;
    }
    return BudgetUsage(yours: yours, automatic: automatic, budget: _budget);
  }

  /// Holds room for [bytes] of [item] from [origin] until [release]. Makes
  /// it by deleting what may be deleted; when that is not enough asks the
  /// viewer to raise the budget for their own downloads, and throws
  /// [DownloadBudgetFull] when they don't or nobody asked for it.
  Future<void> hold(PlaybackItem item, int bytes, LibraryOrigin origin) =>
      _serial(() async {
        final sizes = await _sizes(except: item.id);
        final used = sizes.fold(0, (sum, s) => sum + s.$2);
        final short = used + bytes - _budget;
        if (short > 0) {
          final freed = _choose(sizes, short, origin: origin);
          if (freed != null) {
            await _delete(freed, 'make room for $item');
          } else if (origin != LibraryOrigin.manual ||
              !await _raise(item, bytes, used)) {
            _log.info('No room for $item in the download budget');
            throw const DownloadBudgetFull();
          }
        }
        _held[item.id] = bytes;
      });

  /// Makes room for [entry], already counted as it is on its way, e.g. a
  /// copy; throws as [hold] does.
  Future<void> fit(LibraryEntry entry) async {
    await hold(entry.item, entry.bytes ?? 0, entry.origin);
    release(entry.id);
  }

  /// Stops holding room for [itemId]; its library entry counts instead.
  void release(String itemId) => _held.remove(itemId);

  /// Deletes what may be deleted until downloads fit the budget again,
  /// e.g. after it was lowered.
  Future<void> trim() => _serial(() async {
    final sizes = await _sizes();
    final short = sizes.fold(0, (sum, s) => sum + s.$2) - _budget;
    if (short <= 0) return;
    final freed =
        _choose(sizes, short, origin: LibraryOrigin.manual) ??
        _deletable(sizes, LibraryOrigin.manual);
    await _delete(freed, 'fit a lowered budget');
  });

  Future<bool> _raise(PlaybackItem item, int bytes, int used) async {
    final needed = used + bytes;
    final suggested = (needed + raiseStep - 1) ~/ raiseStep * raiseStep;
    final raise = await _ref
        .read(budgetRequestsProvider.notifier)
        .ask(
          BudgetRequest(
            item: item,
            bytes: bytes,
            used: used,
            budget: _budget,
            suggested: suggested,
          ),
        );
    if (!raise) return false;
    _log.info('Raising the download budget to $suggested for $item');
    await _ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            downloads: s.downloads.copyWith(budgetBytes: suggested),
          ),
        );
    return true;
  }

  /// The fewest deletable entries, oldest first, that free [short] bytes;
  /// null when all of them would not.
  List<LibraryEntry>? _choose(
    List<_Space> sizes,
    int short, {
    required LibraryOrigin origin,
  }) {
    final bytes = {for (final (e, b) in sizes) ?e?.id: b};
    final chosen = <LibraryEntry>[];
    var freed = 0;
    for (final entry in _deletable(sizes, origin)) {
      if (freed >= short) break;
      chosen.add(entry);
      freed += bytes[entry.id]!;
    }
    return freed >= short ? chosen : null;
  }

  /// What may go to make room for [origin], first to go first: watched
  /// automatic downloads, then unless it is a smart pick itself, unwatched
  /// smart picks. What is playing stays.
  List<LibraryEntry> _deletable(List<_Space> sizes, LibraryOrigin origin) {
    final history = {for (final e in _ref.read(watchHistoryProvider)) e.id: e};
    final followed = {
      for (final s in _ref.read(followedSeriesProvider)) s.id: s,
    };
    final playing = _ref.read(playerSessionProvider)?.current?.id;
    final copying = _ref.read(copyingProvider);
    final candidates = [
      for (final (e, _) in sizes)
        if (e != null &&
            e.automatic &&
            e.id != playing &&
            !copying.containsKey(e.id))
          e,
    ]..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    final watched = [
      for (final e in candidates)
        if (isWatched(e.item, history, followed)) e,
    ];
    return [
      ...watched,
      if (origin != LibraryOrigin.smart)
        for (final e in candidates)
          if (e.origin == LibraryOrigin.smart && !watched.contains(e)) e,
    ];
  }

  Future<void> _delete(List<LibraryEntry> entries, String why) async {
    if (entries.isEmpty) return;
    _log.info('Deleting ${entries.length} automatic downloads to $why');
    await _ref.read(libraryProvider.notifier).removeAll({
      for (final e in entries) e.id,
    });
  }

  /// Every download and copy with the space it takes, and room held for
  /// items being queued, which has no entry yet.
  Future<List<_Space>> _sizes({String? except}) async {
    final downloads = {
      for (final d in _ref.read(downloadsProvider).value ?? const []) d.id: d,
    };
    final entries = {
      for (final c in _ref.read(copyingProvider).values) c.entry.id: c.entry,
      for (final e in _ref.read(libraryProvider)) e.id: e,
    }..remove(except);
    return [
      for (final e in entries.values)
        (e, await _size(e, downloads[e.downloadId])),
      for (final MapEntry(key: id, value: bytes) in _held.entries)
        if (id != except && !entries.containsKey(id)) (null, bytes),
    ];
  }

  static Future<int> _size(LibraryEntry entry, DownloadItem? download) async {
    if (entry.bytes case final bytes?) return bytes;
    final file = download?.files
        .where((f) => f.index == entry.fileIndex)
        .firstOrNull;
    if (file != null && file.totalBytes > 0) return file.totalBytes;
    try {
      final saved = File(entry.path);
      if (await saved.exists()) return await saved.length();
    } on FileSystemException {
      // Unreadable files take no room we can count.
    }
    return 0;
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
