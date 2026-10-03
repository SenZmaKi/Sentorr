import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/player/launch.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/settings/models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

/// IMDb as seen offline: every lookup fails without an answer.
class _OfflineImdb extends FakeImdbRepository {
  Never _fail() => throw DioException(
    requestOptions: RequestOptions(),
    type: DioExceptionType.connectionError,
  );

  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => _fail();

  @override
  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => _fail();
}

final _series = fakeTitle(2, series: true);

ImdbEpisode _episode(int season, int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$season$n', title: 'Episode $n'),
  seasonNumber: season,
  episodeNumber: n,
);

ProviderContainer _container(List<(int, int)> downloaded) {
  final dir = Directory.systemTemp.createTempSync('sentorr_offline');
  addTearDown(() => dir.deleteSync(recursive: true));
  final entries = [
    for (final (season, n) in downloaded)
      LibraryEntry(
        item: PlaybackItem.episode(_series, _episode(season, n)),
        downloadId: 'd$season$n',
        release: fakeRelease(season * 10 + n),
        fileIndex: 0,
        path: (File('${dir.path}/s${season}e$n.mkv')..createSync()).path,
        addedAt: DateTime(2026, 10, 3),
      ),
  ];
  final container = ProviderContainer(
    overrides: [
      ...libraryOverrides(entries),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      imdbRepositoryProvider.overrideWithValue(_OfflineImdb()),
      downloadsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _codes(PlayQueue queue) => [
  for (final i in queue.items) 'S${i.season}E${i.episode}',
];

void main() {
  test('offline, a series plays its downloaded episodes in order', () async {
    final container = _container([(2, 1), (1, 2), (1, 1)]);
    container.read(playbackLaunchProvider.notifier).start(PlayTitle(_series));
    await _settle();

    expect(container.read(playbackLaunchProvider), isNull);
    final session = container.read(playerSessionProvider)!;
    expect(session.error, isNull);
    expect(_codes(session.queue!), ['S1E1', 'S1E2', 'S2E1']);
    expect(session.queue!.current.id, 'tt911');
  });

  test('offline, an episode continues through the later downloads', () async {
    final container = _container([(1, 1), (1, 3), (2, 1)]);
    container
        .read(playerSessionProvider.notifier)
        .play(PlayEpisode(_series, _episode(1, 3), season: 1));
    await _settle();

    final session = container.read(playerSessionProvider)!;
    expect(session.error, isNull);
    expect(session.resolving, isFalse);
    expect(_codes(session.queue!), ['S1E1', 'S1E3', 'S2E1']);
    expect(session.queue!.current.id, 'tt913');
    expect(session.queue!.next!.id, 'tt921');
  });

  test('offline with nothing downloaded, the failure stands', () async {
    final container = _container([]);
    container.read(playbackLaunchProvider.notifier).start(PlayTitle(_series));
    await _settle();

    expect(container.read(playbackLaunchProvider)!.error, isNotNull);
    expect(container.read(playerSessionProvider), isNull);
  });
}
