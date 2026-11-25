import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../downloads/background_hold.dart';
import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../following/notifier.dart';
import '../following/tracked.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../library/planner.dart';
import '../player/models.dart';
import '../settings/models.dart';
import '../settings/notifier.dart';
import '../shared/disk_space.dart';
import '../watching/notifier.dart';
import 'candidates.dart';
import 'dismissals.dart';
import 'models.dart';
import 'reserve.dart';

final _log = Logger('sentorr.smart_downloads');

/// The reserve automatic downloads hold now.
final smartReserveProvider = Provider<Reserve>((ref) {
  final downloads = ref.watch(downloadsProvider).value ?? const [];
  return reserveOf(
    entries: ref.watch(libraryProvider),
    downloads: {for (final d in downloads) d.id: d},
    history: {for (final e in ref.watch(watchHistoryProvider)) e.id: e},
    followed: {for (final s in ref.watch(followedSeriesProvider)) s.id: s},
  );
});

final smartStatusProvider = NotifierProvider<SmartStatusNotifier, SmartStatus>(
  SmartStatusNotifier.new,
);

class SmartStatusNotifier extends Notifier<SmartStatus> {
  @override
  SmartStatus build() => SmartStatus.off;

  void set(SmartStatus status) => state = status;
}

final smartDownloadsProvider = Provider<SmartDownloads>((ref) {
  final smart = SmartDownloads(ref);
  ref.onDispose(smart.dispose);
  return smart;
});

/// Keeps the reserve of unwatched content at its target: deletes smart
/// downloads once watched and picks more while automatic downloads may
/// run and the viewer's own downloads are done.
class SmartDownloads {
  SmartDownloads(this._ref);
  final Ref _ref;

  static const startupDelay = Duration(minutes: 1);
  static const interval = Duration(minutes: 30);

  /// Waits for changes to settle, e.g. a run of watch progress.
  static const settle = Duration(seconds: 15);

  /// Torrent searches one run may make.
  static const maxAttempts = 6;

  /// Space left on the disk smart downloads won't take.
  static const minFreeBytes = 5 * 1024 * 1024 * 1024;

  final _subscriptions = <ProviderSubscription<Object?>>[];
  final _timers = <Timer>[];
  Timer? _debounce;
  CancelToken? _cancel;
  Future<void>? _running;
  bool _again = false;

  /// Items whose torrent search failed this session.
  final _failed = <String>{};

  void start() {
    if (_timers.isNotEmpty) return;
    _subscriptions
      ..add(
        _ref.listen<SmartDownloadSettings>(
          settingsProvider.select((s) => s.smart),
          (before, now) {
            if (before?.enabled == true && !now.enabled) _cancel?.cancel();
            _soon(Duration.zero);
          },
        ),
      )
      ..add(
        _ref.listen<BackgroundHold?>(backgroundHoldProvider, (_, hold) {
          if (hold != null) _cancel?.cancel();
          _soon(hold == null ? settle : Duration.zero);
        }),
      )
      ..add(
        _ref.listen(
          smartReserveProvider.select(
            (r) => (r.planned, r.watched.length, r.failed.length),
          ),
          (_, _) => _soon(settle),
        ),
      );
    _timers
      ..add(Timer(startupDelay, refill))
      ..add(Timer.periodic(interval, (_) => refill()));
  }

  /// Evicts what was watched and tops the reserve up. One run at a time;
  /// asked during one, another follows it.
  Future<void> refill() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = () async {
      do {
        _again = false;
        try {
          await _run();
        } catch (error, stack) {
          _log.warning('Smart downloads run failed', error, stack);
        }
      } while (_again && _ref.mounted);
    }().whenComplete(() => _running = null);
  }

  /// Hands [id] to the viewer: it stays when watched, and one still on its
  /// way downloads as theirs.
  Future<void> keep(String id) async {
    final entry = _ref.read(libraryProvider.notifier).entry(id);
    if (entry == null || entry.origin != LibraryOrigin.smart) return;
    _log.info('Keeping ${entry.item}');
    await _ref
        .read(libraryProvider.notifier)
        .add(entry.owned(LibraryOrigin.manual));
    final queue = _ref.read(downloadQueueProvider);
    if (queue.items.any((d) => d.id == entry.downloadId)) {
      await queue.promote(entry.downloadId);
    }
  }

  /// Deletes [id] and picks something else instead.
  Future<void> remove(String id) async {
    await _ref.read(smartDismissalsProvider).add(id);
    await _ref.read(libraryProvider.notifier).remove(id);
    _soon(Duration.zero);
  }

  /// Deletes every smart download.
  Future<void> clear() async {
    _cancel?.cancel();
    await _ref.read(libraryProvider.notifier).removeAll({
      for (final e in _ref.read(libraryProvider))
        if (e.origin == LibraryOrigin.smart) e.id,
    });
  }

  void _soon(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, refill);
  }

  void _status(SmartStatus status) {
    if (_ref.mounted) _ref.read(smartStatusProvider.notifier).set(status);
  }

  Future<void> _run() async {
    final settings = _ref.read(settingsProvider).smart;
    if (!settings.enabled) {
      _status(SmartStatus.off);
      return _dropUnfinished();
    }
    final hold = _ref.read(backgroundHoldProvider);
    if (hold == BackgroundHold.playback) {
      return _status(SmartStatus.waitingForPlayback);
    }
    await _evict();
    if (hold != null) {
      return _status(switch (hold) {
        BackgroundHold.offline => SmartStatus.offline,
        _ => SmartStatus.waitingForWifi,
      });
    }
    if (_viewerDownloading()) {
      return _status(SmartStatus.waitingForDownloads);
    }
    if (_settled(settings.target)) return;
    final free = await freeBytes(_ref.read(downloadsDirectoryProvider));
    if (free != null && free < minFreeBytes) {
      return _status(SmartStatus.lowDiskSpace);
    }
    final history = _ref.read(watchHistoryProvider);
    final series = _ref.read(trackedSeriesProvider);
    if (history.isEmpty && series.isEmpty) {
      return _status(SmartStatus.noHistory);
    }
    _status(SmartStatus.filling);
    final cancel = _cancel = CancelToken();
    final dismissed = await _ref.read(smartDismissalsProvider).load();
    final watched = {for (final e in history) e.id: e};
    final followed = {
      for (final s in _ref.read(followedSeriesProvider)) s.id: s,
    };
    bool skip(PlaybackItem item) =>
        dismissed.contains(item.id) ||
        _failed.contains(item.id) ||
        !downloadable(_ref, item.id) ||
        _ref.read(libraryProvider.notifier).entry(item.id) != null ||
        isWatched(item, watched, followed);
    var attempts = 0;
    await for (final pick in smartCandidates(
      imdb: _ref.read(imdbRepositoryProvider),
      history: history,
      series: series,
      skip: skip,
    )) {
      if (cancel.isCancelled || !_ref.mounted) return;
      if (_ref.read(backgroundHoldProvider) != null) return;
      if (attempts++ >= maxAttempts) break;
      _log.info('Picking $pick');
      try {
        await _ref
            .read(downloadPlannerProvider)
            .download(
              pick.item,
              origin: LibraryOrigin.smart,
              reason: pick.reason,
              cancel: cancel,
            );
      } catch (error) {
        if (cancel.isCancelled) return;
        _log.info('Could not pick ${pick.item}: $error');
        _failed.add(pick.item.id);
      }
      if (_settled(settings.target)) return;
    }
    if (!cancel.isCancelled && _ref.mounted) {
      final reserve = _ref.read(smartReserveProvider);
      _status(
        reserve.pending > Duration.zero
            ? SmartStatus.downloading
            : SmartStatus.nothingToPick,
      );
    }
  }

  /// Sets the status and says true when the reserve needs nothing more.
  bool _settled(Duration target) {
    final reserve = _ref.read(smartReserveProvider);
    if (reserve.planned >= target) {
      _status(
        reserve.pending > Duration.zero
            ? SmartStatus.downloading
            : SmartStatus.full,
      );
      return true;
    }
    return false;
  }

  /// Whether any of the viewer's own downloads is unfinished.
  bool _viewerDownloading() => _ref
      .read(downloadQueueProvider)
      .items
      .any(
        (d) =>
            !d.job.background &&
            !d.status.isTerminal &&
            d.status != DownloadStatus.paused &&
            !d.hasFinishedDownloading,
      );

  /// Deletes smart downloads that were watched or failed.
  Future<void> _evict() async {
    final reserve = _ref.read(smartReserveProvider);
    for (final e in reserve.failed) {
      _failed.add(e.id);
    }
    final gone = {...reserve.watched, ...reserve.failed}.map((e) => e.id);
    if (gone.isEmpty) return;
    _log.info('Evicting ${gone.length} watched or failed smart downloads');
    await _ref.read(libraryProvider.notifier).removeAll(gone.toSet());
  }

  /// Turned off, unfinished smart downloads go; finished ones stay.
  Future<void> _dropUnfinished() async {
    final downloads = {
      for (final d in _ref.read(downloadsProvider).value ?? const []) d.id: d,
    };
    final unfinished = {
      for (final e in _ref.read(libraryProvider))
        if (e.origin == LibraryOrigin.smart &&
            offlineStateOf(e, downloads[e.downloadId]) is! Downloaded)
          e.id,
    };
    if (unfinished.isEmpty) return;
    _log.info('Dropping ${unfinished.length} unfinished smart downloads');
    await _ref.read(libraryProvider.notifier).removeAll(unfinished);
  }

  void dispose() {
    _cancel?.cancel();
    _debounce?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    for (final s in _subscriptions) {
      s.close();
    }
  }
}
