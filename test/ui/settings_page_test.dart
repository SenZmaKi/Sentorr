import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/session_config.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/notifier.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/providers.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/ui/pages/settings/settings_category.dart';
import 'package:sentorr/ui/pages/settings/settings_page.dart';
import 'package:sentorr/ui/pages/settings/settings_search.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/watching/models.dart';
import 'package:torrent_stream/torrent_stream.dart' show TorrentProxyKind;

import '../support/fake_following.dart';
import '../support/fake_library.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

class _Source extends FakeTorrentSource {
  _Source(this.id) : super((_) async => []);
  @override
  final TorrentSourceId id;
}

/// Saves in memory: real file IO never completes in a widget test.
class _MemorySettings extends SettingsRepository {
  _MemorySettings() : super(JsonFileStore(File('unused')));

  @override
  Future<void> save(AppSettings settings) async {}
}

Future<ProviderContainer> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      settingsRepositoryProvider.overrideWithValue(_MemorySettings()),
      torrentDirectoryProvider.overrideWithValue('/torrents'),
      downloadsDirectoryProvider.overrideWithValue('/downloads'),
      ...followedSeriesOverrides(),
      ...libraryOverrides(),
      ...watchHistoryOverrides([
        WatchEntry.of(
          PlaybackItem(title: fakeTitle(1)),
          position: const Duration(minutes: 30),
          duration: const Duration(hours: 1),
        ),
      ]),
      torrentRepositoryProvider.overrideWithValue(
        TorrentRepository([
          for (final id in TorrentSourceId.values) _Source(id),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: const Scaffold(body: SettingsPage()),
      ),
    ),
  );
  return container;
}

Finder _menuItem(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.text(label),
);

void main() {
  for (final (name, size) in [
    ('compact', const Size(390, 844)),
    ('desktop', const Size(1440, 1000)),
  ]) {
    testWidgets('every category lays out at $name width', (tester) async {
      await _pump(tester, size);
      for (final category in SettingsCategory.available) {
        if (size.width < 840) {
          await tester.ensureVisible(find.text(category.title));
          await tester.pumpAndSettle();
          await tester.tap(find.text(category.title));
        } else {
          await tester.tap(find.text(category.title).first);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: category.title);
        if (size.width < 840) {
          await tester.tap(find.text('All settings'));
          await tester.pumpAndSettle();
        }
      }
    });
  }

  testWidgets('search shows matching settings from every category', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));
    await tester.enterText(find.byType(TextField).first, 'tray');
    await tester.pumpAndSettle();
    expect(find.text('Close to tray'), findsOneWidget);
    expect(find.text('Preferred quality'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No settings match'), findsOneWidget);
  });

  testWidgets('search forgives typos only when nothing matches as typed', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));
    await tester.enterText(find.byType(TextField).first, 'qualty');
    await tester.pumpAndSettle();
    expect(find.text('Preferred quality'), findsOneWidget);
    expect(find.textContaining('No settings match'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'seed');
    await tester.pumpAndSettle();
    expect(find.text('Share after downloading'), findsOneWidget);
    // "seed" is typed exactly, so "speed" settings stay out.
    expect(find.text('Download limit'), findsNothing);
  });

  testWidgets('a result names its category and opens it', (tester) async {
    await _pump(tester, const Size(1440, 1000));
    await tester.enterText(find.byType(TextField).first, 'proxy');
    await tester.pumpAndSettle();
    expect(find.text('Proxy and VPN'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Open Network'));
    await tester.pumpAndSettle();
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Proxy and VPN'), findsOneWidget);
  });

  group('settingsMatch', () {
    bool match(String q, String terms, {bool fuzzy = false}) =>
        settingsMatch(q, [terms], fuzzy: fuzzy);

    test('every query word starts or sits inside a word', () {
      expect(match('pref qual', 'Preferred quality'), isTrue);
      expect(match('load', 'Simultaneous downloads'), isTrue);
      expect(match('pref seed', 'Preferred quality'), isFalse);
      expect(match('', 'anything'), isTrue);
    });

    test('words written together match words written apart', () {
      expect(match('autodownload', 'Auto-download'), isTrue);
      expect(match('auto download', 'Autodownload'), isTrue);
    });

    test('synonyms find each other', () {
      expect(match('seeding', 'Share after downloading'), isTrue);
      expect(match('directory', 'Torrent folder'), isTrue);
      expect(match('4k', 'Preferred quality'), isTrue);
    });

    test('typos are forgiven only when fuzzy', () {
      expect(match('notifcations', 'Allow notifications'), isFalse);
      expect(match('notifcations', 'Allow notifications', fuzzy: true), isTrue);
      expect(match('seders', 'Minimum seeders', fuzzy: true), isTrue);
      expect(match('tray', 'Preferred quality', fuzzy: true), isFalse);
    });
  });

  testWidgets('a disabled source is left out of torrent searches', (
    tester,
  ) async {
    final container = await _pump(tester, const Size(1440, 1000));
    await tester.tap(find.text('Finding torrents').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Search YTS'));
    await tester.pumpAndSettle();
    await container.read(settingsProvider.notifier).flushed;
    expect(
      container.read(settingsProvider).sources.enabled(TorrentSourceId.yts),
      isFalse,
    );
    final ids = container
        .read(torrentResolverProvider)
        .repository
        .sources
        .map((s) => s.id);
    expect(ids, isNot(contains(TorrentSourceId.yts)));
    expect(ids, contains(TorrentSourceId.pirateBay));
  });

  testWidgets('a limit switches between a named value and a custom one', (
    tester,
  ) async {
    final container = await _pump(tester, const Size(1440, 1000));
    int limit() =>
        container.read(settingsProvider).network.downloadLimitBytesPerSecond;
    expect(limit(), 0);
    await tester.tap(find.text('Network').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlimited').first);
    await tester.pumpAndSettle();
    await tester.tap(_menuItem('Custom'));
    await tester.pumpAndSettle();
    await container.read(settingsProvider.notifier).flushed;
    expect(limit(), 10 * 1024 * 1024);
    expect(find.text('MB/s'), findsOneWidget);
    await tester.tap(find.text('Custom').first);
    await tester.pumpAndSettle();
    await tester.tap(_menuItem('Unlimited'));
    await tester.pumpAndSettle();
    await container.read(settingsProvider.notifier).flushed;
    expect(limit(), 0);
    expect(find.text('MB/s'), findsNothing);
  });

  testWidgets('choosing a proxy shows where it is and how to log in', (
    tester,
  ) async {
    final container = await _pump(tester, const Size(1440, 1000));
    await tester.tap(find.text('Network').first);
    await tester.pumpAndSettle();
    expect(find.text('Proxy and VPN'), findsOneWidget);
    expect(find.text('Proxy host'), findsNothing);
    await tester.ensureVisible(find.text('None').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').first);
    await tester.pumpAndSettle();
    await tester.tap(_menuItem('SOCKS5'));
    await tester.pumpAndSettle();
    await container.read(settingsProvider.notifier).flushed;
    expect(
      container.read(settingsProvider).network.proxy.kind,
      TorrentProxyKind.socks5,
    );
    expect(find.text('Proxy host'), findsOneWidget);
    expect(find.text('Proxy password'), findsOneWidget);
  });

  test('the network defaults to uTP, discovery and no limits', () {
    const n = NetworkSettings();
    expect(n.utp, isTrue);
    expect(n.dht && n.lsd && n.upnp && n.natPmp, isTrue);
    expect(n.downloadLimitBytesPerSecond, 0);
    expect(n.uploadLimitBytesPerSecond, 0);
  });

  test('limits saved with streaming move to the network', () {
    final settings = AppSettings.fromJson({
      'streaming': {'utp': false, 'downloadLimitBytesPerSecond': 5000},
    });
    expect(settings.network.utp, isFalse);
    expect(settings.network.downloadLimitBytesPerSecond, 5000);
  });

  test('downloads and following settings survive a round trip', () {
    final settings = AppSettings.fromJson(
      const AppSettings(
        downloads: DownloadPreferences(
          directory: '/media',
          maxActive: 4,
          pauseWhileStreaming: false,
          seeding: SeedingMode.limited,
          seedRatio: 2,
        ),
        following: FollowingSettings(
          autoDownload: AutoDownload.all,
          keepEpisodes: 3,
        ),
      ).toJson(),
    );
    final d = settings.downloads;
    expect(d.directory, '/media');
    expect(d.maxActive, 4);
    expect(d.pauseWhileStreaming, isFalse);
    expect(d.queue.seedingMode, SeedingMode.limited);
    expect(d.queue.seedRatio, 2);
    expect(settings.following.autoDownload, AutoDownload.all);
    expect(settings.following.keepEpisodes, 3);
    expect(settings.following.downloads(null), isTrue);
    expect(settings.following.downloads(false), isFalse);
    expect(const FollowingSettings().downloads(null), isFalse);
    expect(
      const FollowingSettings(autoDownload: AutoDownload.off).downloads(true),
      isFalse,
    );
  });

  test('settings survive a round trip and fall back on bad values', () {
    final settings = AppSettings.fromJson(
      const AppSettings(
        torrents: TorrentSettings(autoPlayDelaySeconds: 9, minimumSeeders: 5),
        sources: SourceSettings(disabled: {TorrentSourceId.bitsearch}),
        streaming: StreamingSettings(keepRecentTorrents: 0),
        network: NetworkSettings(utp: false),
      ).toJson(),
    );
    expect(settings.torrents.autoPlayDelaySeconds, 9);
    expect(settings.torrents.minimumSeeders, 5);
    expect(settings.sources.enabled(TorrentSourceId.bitsearch), isFalse);
    expect(settings.streaming.keepRecentTorrents, 0);
    expect(settings.network.utp, isFalse);
    final bad = AppSettings.fromJson({
      'torrents': {'autoPlayDelaySeconds': 999},
      'sources': {
        'disabled': ['gone', 'yts'],
      },
      'streaming': {'readAheadBytes': -1, 'torrentDirectory': ''},
    });
    expect(bad.torrents.autoPlayDelaySeconds, 4);
    expect(bad.sources.disabled, {TorrentSourceId.yts});
    expect(
      bad.streaming.readAheadBytes,
      const StreamingSettings().readAheadBytes,
    );
    expect(bad.streaming.torrentDirectory, isNull);
  });
}
