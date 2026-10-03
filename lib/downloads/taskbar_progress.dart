import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import 'manager.dart';
import 'models.dart';
import 'progress_summary.dart';
import 'queue.dart';

final _log = Logger('sentorr.downloads.taskbar');

/// Bootstrap starts it on Windows after the queue is restored.
final taskbarProgressProvider = Provider<TaskbarProgress>((ref) {
  final progress = TaskbarProgress(ref.watch(downloadQueueProvider));
  ref.onDispose(() => unawaited(progress.dispose()));
  return progress;
});

/// Shows overall download progress on the app's Windows taskbar button:
/// green while downloading, yellow when every unfinished download is paused.
class TaskbarProgress {
  TaskbarProgress(this.queue);

  /// The plugin decodes values as int32, so byte counts past 2 GiB would
  /// crash it; progress is sent in these steps instead.
  static const _steps = 10000;
  final DownloadQueue queue;
  StreamSubscription<List<DownloadItem>>? _changes;
  (int, int)? _shown;
  Future<void> _tail = Future.value();

  void start() {
    if (!Platform.isWindows || _changes != null) return;
    _changes = queue.changes.listen(_render);
    _render(queue.items);
  }

  void _render(List<DownloadItem> items) {
    final paused = {
      for (final i in items)
        if (i.status == DownloadStatus.paused) i.id,
    };
    final summary = DownloadProgressSummary.of(items, held: paused);
    final (mode, value) = switch (summary) {
      null => (TaskbarProgressMode.noProgress, 0),
      DownloadProgressSummary(preparing: true) => (
        TaskbarProgressMode.indeterminate,
        0,
      ),
      DownloadProgressSummary(:final progress?, :final paused) => (
        paused ? TaskbarProgressMode.paused : TaskbarProgressMode.normal,
        (progress.clamp(0, 1) * _steps).round(),
      ),
      // Seeding alone has nothing left to show.
      _ => (TaskbarProgressMode.noProgress, 0),
    };
    if (_shown == (mode, value)) return;
    _shown = (mode, value);
    _serial(() async {
      if (mode != TaskbarProgressMode.noProgress &&
          mode != TaskbarProgressMode.indeterminate) {
        await WindowsTaskbar.setProgress(value, _steps);
      }
      await WindowsTaskbar.setProgressMode(mode);
    });
  }

  void _serial(Future<void> Function() task) {
    _tail = _tail.then((_) => task()).catchError((Object error) {
      _log.warning('Could not update taskbar progress', error);
    });
  }

  Future<void> dispose() async {
    if (_changes == null) return;
    await _changes?.cancel();
    _changes = null;
    _serial(
      () => WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress),
    );
    await _tail;
  }
}
