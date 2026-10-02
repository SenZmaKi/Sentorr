import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/player/launch.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/providers.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/ui/pages/launch/launch_dialog.dart';
import 'package:sentorr/ui/pages/launch/launch_host.dart';
import 'package:sentorr/ui/pages/torrent_picker/torrent_option.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

final _autoPlayDelay = const TorrentSettings().autoPlayDelay;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Future<List<TorrentRelease>> Function(TorrentQuery) answer,
) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      ...watchHistoryOverrides(),
      imdbRepositoryProvider.overrideWithValue(FakeImdbRepository()),
      torrentRepositoryProvider.overrideWithValue(
        TorrentRepository([FakeTorrentSource(answer)]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: LaunchHost(
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ref.playTitle(fakeTitle(1)),
                child: const Text('Play title'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Play title'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  testWidgets('an exact match plays when the countdown ends', (tester) async {
    final container = await _pump(tester, (_) async => [fakeRelease(1)]);
    expect(find.text('Ready to play'), findsOneWidget);
    expect(find.text('Play in 4s'), findsOneWidget);
    expect(container.read(playerSessionProvider), isNull);

    await tester.pump(_autoPlayDelay);
    await tester.pumpAndSettle();
    expect(find.byType(LaunchDialog), findsNothing);
    expect(container.read(playerSessionProvider)!.torrents, contains('tt1'));
  });

  testWidgets('touching the dialog stops the countdown', (tester) async {
    final container = await _pump(
      tester,
      (_) async => [fakeRelease(1), fakeRelease(2, resolution: 720)],
    );
    await tester.tap(find.text('Show 1 more'));
    await tester.pump(_autoPlayDelay * 2);
    expect(find.text('Play'), findsOneWidget);
    expect(container.read(playerSessionProvider), isNull);

    await tester.tap(find.byType(TorrentOption).last);
    await tester.pump();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    final torrent = container.read(playerSessionProvider)!.torrents['tt1']!;
    expect(torrent.release.resolution, 720);
  });

  testWidgets('more torrents can be sorted and filtered', (tester) async {
    await _pump(
      tester,
      (_) async => [
        fakeRelease(1, name: 'Title 1 2026 1080p WEB-DL x264'),
        fakeRelease(2, name: 'Title 1 2026 720p HDTV x264', resolution: 720),
        fakeRelease(
          3,
          name: 'Title 1 2026 2160p BluRay x265',
          resolution: 2160,
        ),
      ],
    );
    await tester.tap(find.text('Show 2 more'));
    await tester.pump();
    expect(find.byType(TorrentOption), findsNWidgets(3));
    expect(find.text('3 torrents'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pump();
    await tester.tap(find.text('Any quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720p · 1'));
    await tester.pump();
    // Escape would cancel the launch; a tap outside closes the menu.
    await tester.tap(find.text('Ready to play'));
    await tester.pumpAndSettle();
    expect(find.byType(TorrentOption), findsOneWidget);
    expect(find.text('1 of 3 torrents'), findsOneWidget);
    expect(find.text('Filters · 1'), findsOneWidget);

    // Folded away, the filter stays visible as a chip that removes it.
    await tester.tap(find.text('Filters · 1'));
    await tester.pump();
    await tester.tap(find.text('720p'));
    await tester.pump();
    expect(find.byType(TorrentOption), findsNWidgets(3));
  });

  testWidgets('a close match explains itself and waits', (tester) async {
    final container = await _pump(
      tester,
      (_) async => [fakeRelease(1, resolution: 720)],
    );
    expect(find.text('Closest match'), findsOneWidget);
    expect(find.textContaining('Not available in 1080p.'), findsOneWidget);
    await tester.pump(_autoPlayDelay * 2);
    expect(find.byType(LaunchDialog), findsOneWidget);
    expect(container.read(playerSessionProvider), isNull);
  });

  testWidgets('a miss can be searched under another title', (tester) async {
    final container = await _pump(
      tester,
      (q) async =>
          q.title == 'Other' ? [fakeRelease(1, name: 'Other 2026')] : [],
    );
    expect(find.text('Couldn’t find a torrent'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Other');
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ready to play'), findsOneWidget);
    expect(container.read(playbackLaunchProvider)!.query!.title, 'Other');
  });

  testWidgets('Escape cancels the launch', (tester) async {
    final container = await _pump(tester, (_) async => [fakeRelease(1)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(LaunchDialog), findsNothing);
    expect(container.read(playbackLaunchProvider), isNull);
    await tester.pump(_autoPlayDelay);
    expect(container.read(playerSessionProvider), isNull);
  });
}
