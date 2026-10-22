import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/following/auto_downloads.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/latest_episode.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/mark_watched.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/torrents/resolution_models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_following.dart';
import '../support/fake_lists.dart';
import '../support/fake_library.dart';
import '../support/fake_planner.dart';

final show = ImdbTitle(id: 'tt1', title: 'Show', canHaveEpisodes: true);
ImdbEpisode ep(int n) => ImdbEpisode(
  title: ImdbTitle(id: 'tt10$n', title: 'Episode $n'),
  seasonNumber: 1,
  episodeNumber: n,
  releaseDate: const ImdbDate(year: 2024, month: 1, day: 1),
);

class GatedImdb extends FakeImdbRepository {
  GatedImdb(ImdbTitle title)
    : super(
        trending: [title],
        seasons: {
          title.id: [1],
        },
        episodes: {
          '${title.id}/1': [ep(1), ep(2), ep(3)],
        },
      );
  final entered = Completer<void>(), gate = Completer<void>();
  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    return super.getTitleDetails(
      id,
      previewLimit: previewLimit,
      refresh: refresh,
      cancelToken: cancelToken,
    );
  }
}

class PagedImdb extends FakeImdbRepository {
  PagedImdb()
    : super(
        trending: [show],
        seasons: {
          show.id: [1],
        },
      );
  final cursors = <String?>[];
  @override
  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    cursors.add(cursor);
    return ImdbPage(
      items: [
        for (
          var n = cursor == null ? 1 : 51;
          n <= (cursor == null ? 50 : 60);
          n++
        )
          ep(n),
      ],
      total: 60,
      nextCursor: cursor == null ? 'next' : null,
    );
  }
}

class GatedPlanner extends FakePlanner {
  final entered = Completer<void>();
  @override
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    bool automatic = false,
    CancelToken? cancel,
  }) {
    if (!entered.isCompleted) entered.complete();
    return super.download(
      item,
      torrent: torrent,
      automatic: automatic,
      cancel: cancel,
    );
  }
}

void main() {
  for (final revoke in ['off', 'unfollow', 'untrack']) {
    test('$revoke cancels pending automatic torrent planning', () async {
      final imdb = GatedImdb(show)..gate.complete();
      final planner = GatedPlanner()..gate = Completer<void>();
      final c = ProviderContainer(
        overrides: [
          imdbRepositoryProvider.overrideWithValue(imdb),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          ...watchingOverrides([show]),
          ...followedSeriesOverrides([
            following(show, episode: 1).copyWith(autoDownload: true),
          ]),
          ...libraryOverrides(),
          downloadPlannerProvider.overrideWithValue(planner),
        ],
      );
      try {
        final pending = c.read(autoDownloadsProvider).check(show.id);
        await planner.entered.future;
        if (revoke == 'off') {
          await c
              .read(followedSeriesProvider.notifier)
              .setAutoDownload(show.id, false);
        } else if (revoke == 'unfollow') {
          await c.read(followedSeriesProvider.notifier).unfollow(show.id);
        } else {
          await c
              .read(watchListsProvider.notifier)
              .set(show, WatchStatus.dropped);
        }
        planner.gate!.complete();
        await pending;
        expect(planner.planned, isEmpty);
        expect(c.read(autoDownloadReviewsProvider), isEmpty);
      } finally {
        c.dispose();
      }
    });
  }

  test('per-series Off revokes pending episode listing', () async {
    final imdb = GatedImdb(show), planner = FakePlanner();
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(imdb),
        initialSettingsProvider.overrideWithValue(const AppSettings()),
        ...watchingOverrides([show]),
        ...followedSeriesOverrides([
          following(show, episode: 1).copyWith(autoDownload: true),
        ]),
        ...libraryOverrides(),
        downloadPlannerProvider.overrideWithValue(planner),
      ],
    );
    try {
      final running = c.read(autoDownloadsProvider).check(show.id);
      await imdb.entered.future;
      await c
          .read(followedSeriesProvider.notifier)
          .setAutoDownload(show.id, false);
      imdb.gate.complete();
      await running;
      expect(c.read(followedProvider(show.id))!.autoDownload, isFalse);
      expect(planner.planned, isEmpty);
    } finally {
      c.dispose();
    }
  });
  test('newer Dropped invalidates pending Completed', () async {
    final imdb = GatedImdb(show);
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(imdb),
        ...watchListsOverrides(),
        ...followedSeriesOverrides(),
      ],
    );
    try {
      final lists = c.read(watchListsProvider.notifier);
      final pending = lists.set(show, WatchStatus.completed);
      await imdb.entered.future;
      await lists.set(show, WatchStatus.dropped);
      imdb.gate.complete();
      await pending;
      expect(lists.statusOf(show.id), WatchStatus.dropped);
    } finally {
      c.dispose();
    }
  });
  test('unfollow invalidates a pending follow', () async {
    final imdb = GatedImdb(show);
    final c = ProviderContainer(
      overrides: [
        imdbRepositoryProvider.overrideWithValue(imdb),
        ...followedSeriesOverrides(),
      ],
    );
    try {
      final notifier = c.read(followedSeriesProvider.notifier);
      final pending = notifier.follow(show);
      await imdb.entered.future;
      await notifier.unfollow(show.id);
      imdb.gate.complete();
      await pending;
      expect(c.read(followedProvider(show.id)), isNull);
    } finally {
      c.dispose();
    }
  });
}
