import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/lists/snapshot.dart';
import 'package:sentorr/player/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';

const _hour = Duration(hours: 1);
final _movie = fakeTitle(1);
final _series = fakeTitle(2, series: true);
final _episode = PlaybackItem(
  title: ImdbTitle(id: 'tt211', title: 'Episode 1'),
  series: _series,
  season: 1,
  episode: 1,
);

ImdbTitle _ended(int n) => ImdbTitle(
  id: 'tt$n',
  title: 'Ended $n',
  canHaveEpisodes: true,
  endYear: 2024,
);

ImdbEpisode _aired(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt9$n', title: 'Episode $n'),
  seasonNumber: 1,
  episodeNumber: n,
  releaseDate: const ImdbDate(year: 2023, month: 1, day: 1),
);

void main() {
  late ProviderContainer container;
  late MemoryWatchLists repository;
  WatchListsNotifier lists() => container.read(watchListsProvider.notifier);
  WatchStatus? status(String id) => container.read(watchStatusProvider(id));
  final ended = _ended(8);
  PlaybackItem endedEpisode(int n) => PlaybackItem(
    title: _aired(n).title,
    series: ended,
    season: 1,
    episode: n,
  );

  /// Opens [item] and plays it to [fraction].
  Future<void> play(PlaybackItem item, double fraction) async {
    lists().started(item);
    await lists().record(item, position: _hour * fraction, duration: _hour);
  }

  setUp(() {
    repository = MemoryWatchLists();
    container = ProviderContainer(
      overrides: [
        ...watchListsOverrides(const [], repository),
        ...followedSeriesOverrides([following(_series, episode: 4)]),
        imdbRepositoryProvider.overrideWithValue(
          FakeImdbRepository(
            trending: [_movie, _series, ended],
            seasons: {
              ended.id: [1],
            },
            episodes: {
              '${ended.id}/1': [_aired(1), _aired(2)],
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('playing past a sample marks the movie or series watching', () async {
    await lists().set(_series, WatchStatus.dropped);
    lists().started(PlaybackItem(title: _movie));
    await lists().record(
      PlaybackItem(title: _movie),
      position: const Duration(seconds: 10),
      duration: _hour,
    );
    expect(status(_movie.id), isNull, reason: 'a sample is not watching');
    await play(PlaybackItem(title: _movie), .2);
    await play(_episode, .2);
    expect(status(_movie.id), WatchStatus.watching);
    expect(status(_series.id), WatchStatus.watching);
  });

  test('a planned movie watched through is completed', () async {
    final movie = PlaybackItem(title: _movie);
    await lists().set(_movie, WatchStatus.planned);
    await play(movie, .85);
    expect(status(_movie.id), WatchStatus.watching);
    await lists().record(movie, position: _hour * .9, duration: _hour);
    expect(status(_movie.id), WatchStatus.completed);
  });

  test('replaying a completed movie is a rewatch, counted when done', () async {
    final movie = PlaybackItem(title: _movie);
    await lists().set(_movie, WatchStatus.completed);
    await play(movie, .3);
    expect(status(_movie.id), WatchStatus.rewatching);
    await lists().record(movie, position: _hour, duration: _hour);
    expect(status(_movie.id), WatchStatus.completed);
    expect(container.read(watchListsProvider).single.rewatches, 1);
  });

  test('a new episode of a completed series is watching again', () async {
    await lists().set(_series, WatchStatus.completed);
    await play(_episode, .3);
    expect(status(_series.id), WatchStatus.rewatching, reason: 'E1 was seen');
    await lists().set(_series, WatchStatus.completed);
    await play(
      PlaybackItem(
        title: ImdbTitle(id: 'tt215', title: 'Episode 5'),
        series: _series,
        season: 1,
        episode: 5,
      ),
      .3,
    );
    expect(status(_series.id), WatchStatus.watching);
  });

  test('only the last episode of an ended series completes it', () async {
    await play(endedEpisode(1), 1);
    expect(status(ended.id), WatchStatus.watching);
    await play(endedEpisode(2), .5);
    expect(status(ended.id), WatchStatus.watching);
    await lists().record(endedEpisode(2), position: _hour, duration: _hour);
    expect(status(ended.id), WatchStatus.completed);
  });

  test('finishing the latest episode of a running series keeps it', () async {
    await play(_episode, 1);
    expect(status(_series.id), WatchStatus.watching);
  });

  test('removing keeps a tombstone that wins over older changes', () async {
    await lists().set(_movie, WatchStatus.planned);
    final before = lists().snapshot;
    await lists().set(_movie, null);
    expect(container.read(watchListsProvider), isEmpty);
    expect(lists().snapshot.entries.single.removed, true);
    await lists().merge(before);
    expect(status(_movie.id), isNull);
  });

  test('merging keeps each title\'s latest change from either side', () {
    final at = DateTime.now();
    ListEntry entry(ImdbTitle t, WatchStatus s, int revision) =>
        ListEntry(title: t, status: s, updatedAt: at, revision: revision);
    final mine = ListsSnapshot([
      entry(_movie, WatchStatus.paused, 3),
      entry(_series, WatchStatus.planned, 1),
    ]);
    final theirs = ListsSnapshot([
      entry(_movie, WatchStatus.dropped, 2),
      entry(_series, WatchStatus.watching, 4),
    ]);
    final merged = mine.merge(theirs);
    expect(merged.matches(theirs.merge(mine)), true);
    expect(
      {for (final e in merged.entries) e.id: e.status},
      {_movie.id: WatchStatus.paused, _series.id: WatchStatus.watching},
    );
    final json = ListsSnapshot.fromJson(merged.toJson());
    expect(json.matches(merged), true);
  });
  test('backups carry the lists; older backups restore none', () async {
    await lists().set(_movie, WatchStatus.planned);
    final bundle = BackupBundle(
      watch: const WatchSnapshot([], {}),
      following: const FollowedSnapshot([], {}),
      lists: lists().snapshot,
    );
    final restored = BackupBundle.decode(bundle.encode());
    expect(restored.lists.matches(bundle.lists), true);
    expect(restored.matches(bundle), true);
    final older = jsonDecode(bundle.encode()) as Map<String, dynamic>;
    older['version'] = 2;
    older.remove('formats');
    older.remove('lists');
    expect(BackupBundle.decode(jsonEncode(older)).lists.entries, isEmpty);
  });
}
