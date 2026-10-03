import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../downloads/progress_summary.dart';
import '../notifications/notification_service.dart';
import '../settings/notifier.dart';
import 'models.dart';
import 'notifier.dart';

final _log = Logger('sentorr.library.download_alerts');

/// Bootstrap starts it after the download queue is restored.
final downloadAlertsProvider = Provider<DownloadAlerts>((ref) {
  final alerts = DownloadAlerts(ref);
  ref.onDispose(alerts.dispose);
  return alerts;
});

/// Notifies when downloads finish or fail. A season's episodes are told
/// about together once none of it is still downloading. Automatic downloads
/// have their own "ready to watch" notification from following.
class DownloadAlerts {
  DownloadAlerts(this._ref);
  final Ref _ref;

  /// Downloads already done, failed or cancelled, which are not told again.
  final _settled = <String>{};

  /// Finished downloads waiting for the rest of their season, by batch.
  final _waiting = <String, List<DownloadItem>>{};
  StreamSubscription<List<DownloadItem>>? _changes;
  Future<void> _tail = Future.value();

  /// Completes once every notification already due has been shown.
  Future<void> get shown => _tail;

  void start() {
    if (_changes != null) return;
    final queue = _ref.read(downloadQueueProvider);
    // Restored downloads were already told about, or never will be.
    for (final item in queue.items) {
      if (item.isDone || item.status.isTerminal) _settled.add(item.id);
    }
    _changes = queue.changes.listen(_changed);
  }

  void _changed(List<DownloadItem> items) {
    final finished = <DownloadItem>[];
    final failed = <DownloadItem>[];
    for (final item in items) {
      if (_settled.contains(item.id)) continue;
      switch (item.status) {
        case DownloadStatus.seeding || DownloadStatus.completed:
          _settled.add(item.id);
          finished.add(item);
        case DownloadStatus.failed:
          _settled.add(item.id);
          failed.add(item);
        case DownloadStatus.cancelled:
          _settled.add(item.id);
        default:
      }
    }
    final entries = {
      for (final e in _ref.read(libraryProvider)) e.downloadId: e,
    };
    for (final item in finished) {
      if (entries[item.id]?.automatic ?? false) continue;
      _waiting.putIfAbsent(item.job.batchId ?? item.id, () => []).add(item);
    }
    for (final key in _waiting.keys.toList()) {
      final busy = items.any(
        (i) =>
            (i.job.batchId ?? i.id) == key &&
            DownloadProgressSummary.isDownloading(i),
      );
      if (!busy) _finished(key, _waiting.remove(key)!, entries);
    }
    for (final item in failed) {
      _show(
        key: item.id,
        title: 'Download failed',
        body: [item.job.title, ?item.error].join(': '),
      );
    }
  }

  void _finished(
    String key,
    List<DownloadItem> items,
    Map<String, LibraryEntry> entries,
  ) {
    if (items.length == 1) {
      _show(
        key: key,
        title: 'Download complete',
        body: '${items.single.job.title} is ready to watch',
      );
      return;
    }
    final episode = entries[items.first.id]?.item;
    final series = episode?.series?.title;
    _show(
      key: key,
      title: series == null
          ? 'Downloads complete'
          : '$series season ${episode!.season} downloaded',
      body: '${items.length} episodes ready to watch',
    );
  }

  void _show({
    required String key,
    required String title,
    required String body,
  }) {
    if (!_ref.read(settingsProvider).notifications.notifyDownloadsReady) {
      return;
    }
    final notifications = _ref.read(notificationServiceProvider);
    _tail = _tail
        .then(
          (_) => notifications.showDownload(key: key, title: title, body: body),
        )
        .catchError((Object error) {
          _log.warning('Could not show a download notification', error);
        });
  }

  void dispose() => unawaited(_changes?.cancel());
}
