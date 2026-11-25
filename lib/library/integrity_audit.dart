import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../player/session.dart';
import '../shared/net/online.dart';
import 'integrity.dart';
import 'models.dart';
import 'notifier.dart';

final _log = Logger('sentorr.library.audit');

/// Bootstrap starts it after the download queue is restored.
final integrityAuditProvider = Provider<IntegrityAudit>((ref) {
  final audit = IntegrityAudit(ref);
  ref.onDispose(audit.dispose);
  return audit;
});

/// Checks downloaded files nothing has checked yet: those finished before
/// downloads were verified, and copies received without the torrent's
/// details. One at a time, only while nothing plays. Confirmed damage is
/// recovered; a check that cannot finish is retried on reconnecting.
class IntegrityAudit {
  IntegrityAudit(this._ref, {this.delay = const Duration(minutes: 1)});
  final Ref _ref;

  /// Before the first check, so startup and resumed playback come first.
  final Duration delay;

  /// Files already checked this run, by id and path, whatever the result.
  final _tried = <(String, String)>{};
  final _subscriptions = <ProviderSubscription<Object?>>[];
  StreamSubscription<List<DownloadItem>>? _changes;
  Timer? _start;
  bool _running = false, _disposed = false;

  void start() {
    if (_changes != null || _disposed) return;
    final queue = _ref.read(downloadQueueProvider);
    // Restored finished downloads may predate verification. Those that
    // finish from now on were checked by the queue before finishing.
    final finished = {
      for (final item in queue.items)
        if (item.hasFinishedDownloading) item.id,
    };
    _changes = queue.changes.listen((items) {
      for (final item in items) {
        if (item.hasFinishedDownloading && finished.add(item.id)) {
          unawaited(_checkedByQueue(item.id));
        }
      }
    });
    _subscriptions
      ..add(_ref.listen<List<LibraryEntry>>(libraryProvider, (_, _) => _run()))
      ..add(
        _ref.listen<PlayerSession?>(playerSessionProvider, (_, session) {
          if (session == null) _run();
        }),
      )
      ..add(
        _ref.listen<bool>(onlineProvider, (was, online) {
          if (was == false && online) {
            _tried.clear();
            _run();
          }
        }),
      );
    _start = Timer(delay, _run);
  }

  Future<void> _checkedByQueue(String downloadId) async {
    final library = _ref.read(libraryProvider.notifier);
    for (final entry in _ref.read(libraryProvider)) {
      if (entry.downloadId == downloadId && entry.verifiedAt == null) {
        await library.update(entry.verified(DateTime.now()));
      }
    }
  }

  LibraryEntry? _next() {
    final downloads = _ref.read(downloadQueueProvider).items;
    // Another session must not write a torrent's files while this hashes them.
    final busy = {
      for (final d in downloads)
        if (!d.hasFinishedDownloading && !d.status.isTerminal) ?d.infoHash,
    };
    for (final entry in _ref.read(libraryProvider)) {
      if (entry.verifiedAt != null ||
          busy.contains(entry.infoHash) ||
          _tried.contains((entry.id, entry.path))) {
        continue;
      }
      final download = downloads
          .where((d) => d.id == entry.downloadId)
          .firstOrNull;
      if (offlineStateOf(entry, download) is Downloaded) return entry;
    }
    return null;
  }

  Future<void> _run() async {
    if (_running || _disposed || (_start?.isActive ?? true)) return;
    _running = true;
    try {
      while (!_disposed && _ref.read(playerSessionProvider) == null) {
        final entry = _next();
        if (entry == null) break;
        _tried.add((entry.id, entry.path));
        await _audit(entry);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _audit(LibraryEntry entry) async {
    try {
      final integrity = _ref.read(libraryIntegrityProvider);
      final result = await integrity.check(entry);
      _log.info('Audited ${entry.item}: ${result.state.name}');
      if (result.state != IntegrityState.damaged || _disposed) return;
      final current = _ref.read(libraryProvider.notifier).entry(entry.id);
      if (entry.sameFile(current)) await integrity.recover(entry);
    } on Object catch (error, stack) {
      _log.warning('Could not audit ${entry.item}', error, stack);
    }
  }

  void dispose() {
    _disposed = true;
    _start?.cancel();
    unawaited(_changes?.cancel());
    for (final s in _subscriptions) {
      s.close();
    }
  }
}
