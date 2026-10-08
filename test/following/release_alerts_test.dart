import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/release_alerts.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/notifications/notification_service.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/repository.dart';

import '../support/fake_following.dart';
import '../support/fake_lists.dart';
import '../support/fake_imdb.dart';

class _Notifications extends NotificationService {
  final shown = <String>[];

  @override
  Future<void> showNewEpisode({
    required String seriesId,
    required String title,
    required String body,
  }) async => shown.add('$seriesId $body');
}

class _NoSettingsFile implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ImdbDate _date(DateTime d) =>
    ImdbDate(year: d.year, month: d.month, day: d.day);

void main() {
  final now = DateTime.now();
  final series = fakeTitle(1, series: true);
  final imdb = FakeImdbRepository(
    trending: [series],
    seasons: {
      'tt1': [1],
    },
    episodes: {
      'tt1/1': [
        for (final (n, days) in [(4, 7), (5, 0)])
          ImdbEpisode(
            title: ImdbTitle(id: 'tt91$n', title: 'Episode $n'),
            seasonNumber: 1,
            episodeNumber: n,
            releaseDate: _date(now.subtract(Duration(days: days))),
          ),
      ],
    },
  );

  (ProviderContainer, _Notifications) setUpWith(AppSettings settings) {
    final notifications = _Notifications();
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(imdb),
        notificationServiceProvider.overrideWithValue(notifications),
        initialSettingsProvider.overrideWithValue(settings),
        settingsRepositoryProvider.overrideWithValue(_NoSettingsFile()),
        ...watchingOverrides([series]),
        ...followedSeriesOverrides([
          following(
            series,
            episode: 4,
            watchedAt: now.subtract(const Duration(days: 3)),
          ),
        ]),
      ],
    );
    addTearDown(c.dispose);
    return (c, notifications);
  }

  test('notifies once about an episode the viewer is caught up to', () async {
    final (c, notifications) = setUpWith(const AppSettings());
    final alerts = c.read(releaseAlertsProvider);
    await alerts.check();
    expect(notifications.shown, ['tt1 S1 E5 · Episode 5']);
    expect(c.read(followedSeriesProvider).single.notified, 'tt915');
    await alerts.check();
    expect(notifications.shown, hasLength(1));
  });

  test('stays quiet when new episode notifications are off', () async {
    final (c, notifications) = setUpWith(
      const AppSettings(
        notifications: NotificationSettings(newEpisodes: false),
      ),
    );
    await c.read(releaseAlertsProvider).check();
    expect(notifications.shown, isEmpty);
    expect(c.read(followedSeriesProvider).single.notified, isNull);
  });
}
