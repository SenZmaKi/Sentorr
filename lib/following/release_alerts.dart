import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../home/series_updates.dart';
import '../notifications/notification_service.dart';
import '../settings/notifier.dart';
import 'auto_downloads.dart';
import 'latest_episode.dart';
import 'models.dart';
import 'notifier.dart';
import 'releases.dart';
import 'tracked.dart';

final _log = Logger('sentorr.following.alerts');

/// Looks for new episodes of watched series while Sentorr runs, including
/// from the tray, and notifies when one is next for the viewer.
final releaseAlertsProvider = Provider<ReleaseAlerts>((ref) {
  final alerts = ReleaseAlerts(ref);
  ref.onDispose(alerts.dispose);
  return alerts;
});

class ReleaseAlerts {
  ReleaseAlerts(this._ref);

  /// Episodes air at most daily; this catches one within hours.
  static const interval = Duration(hours: 3);

  /// Startup is left alone first.
  static const startupDelay = Duration(minutes: 1);

  final Ref _ref;
  Timer? _timer;
  Future<void>? _running;

  void start() {
    if (_timer != null) return;
    _log.info(
      'Checking for new episodes in ${startupDelay.inMinutes}m, '
      'then every ${interval.inHours}h',
    );
    _timer = Timer(startupDelay, () {
      unawaited(check());
      _timer = Timer.periodic(interval, (_) => unawaited(check()));
    });
  }

  /// Fetches the latest episode of each followed series afresh and
  /// notifies about the ones worth it. One run at a time.
  Future<void> check() => _running ??= _check().whenComplete(() {
    _running = null;
  });

  Future<void> _check() async {
    final year = DateTime.now().year;
    final followed = [
      for (final s in _ref.read(trackedSeriesProvider))
        if (s.series.endYear == null || s.series.endYear! >= year) s,
    ];
    if (followed.isEmpty) {
      _log.fine('No airing series to check');
      // Ended series may still have episodes left to download.
      await _ref.read(autoDownloadsProvider).checkAll();
      return;
    }
    final clock = Stopwatch()..start();
    final imdb = _ref.read(imdbRepositoryProvider);
    var notified = 0, failed = 0;
    for (final series in followed) {
      try {
        final update = await latestEpisode(imdb, series.id, refresh: true);
        if (update != null && await _notify(series, update)) notified++;
      } catch (error, stack) {
        failed++;
        _log.warning('New episode check failed for ${series.id}', error, stack);
      }
    }
    _log.info(
      'Checked ${followed.length} series in ${clock.elapsedMilliseconds}ms: '
      '$notified notified${failed == 0 ? '' : ', $failed failed'}',
    );
    // The shelf reads the responses just cached.
    if (_ref.mounted) _ref.invalidate(seriesUpdatesProvider);
    if (_ref.mounted) await _ref.read(autoDownloadsProvider).checkAll();
  }

  /// Whether the viewer was told about [update].
  Future<bool> _notify(FollowedSeries followed, SeriesUpdate update) async {
    final settings = _ref.read(settingsProvider).notifications;
    final n = update.number;
    _log.fine(
      '${followed.id} latest S${n?.season}E${n?.episode} aired '
      '${update.aired.toIso8601String().split('T').first}, '
      'viewer reached S${followed.reached.season}E${followed.reached.episode}',
    );
    if (!settings.notifyNewEpisodes ||
        !followed.notify ||
        !shouldNotify(followed, update)) {
      return false;
    }
    await _ref
        .read(notificationServiceProvider)
        .showNewEpisode(
          seriesId: followed.id,
          title: '${update.series.title}: new episode',
          body: 'S${n!.season} E${n.episode} · ${update.episode.title.title}',
        );
    await _ref
        .read(followedSeriesProvider.notifier)
        .markNotified(followed.id, update.episode.title.id);
    return true;
  }

  void dispose() => _timer?.cancel();
}
