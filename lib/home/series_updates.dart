import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../following/latest_episode.dart';
import '../following/notifier.dart';
import '../following/releases.dart';

export '../following/latest_episode.dart' show SeriesUpdate, airDate;

/// The latest aired episode of every followed series still airing.
final seriesUpdatesProvider = FutureProvider<List<SeriesUpdate>>((ref) async {
  final imdb = ref.watch(imdbRepositoryProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  // Progress changes every few seconds while watching; only a change in
  // which series are followed needs new lookups.
  ref.watch(
    followedSeriesProvider.select((l) => [for (final s in l) s.id].join(',')),
  );
  final year = DateTime.now().year;
  final followed = [
    for (final s in ref.read(followedSeriesProvider))
      if (s.series.endYear == null || s.series.endYear! >= year) s,
  ];
  Object? failure;
  final updates = await Future.wait([
    for (final s in followed)
      latestEpisode(imdb, s.id, cancel: cancel).catchError((
        Object error,
        StackTrace stack,
      ) {
        if (!(error is DioException && CancelToken.isCancel(error))) {
          Logger(
            'sentorr.following',
          ).warning('Skipped ${s.id} on the new episodes shelf', error, stack);
        }
        failure ??= error;
        return null;
      }),
  ]);
  final found = updates.nonNulls.toList();
  // One broken series is skipped; all failing means IMDb is unreachable.
  if (found.isEmpty && failure != null) throw failure!;
  return found;
});

bool _within(DateTime? date, int days) =>
    date != null && DateTime.now().difference(date).inDays <= days;

/// Recent episodes that are next for the viewer: they saw the one before.
final newEpisodesProvider = Provider<AsyncValue<List<SeriesUpdate>>>((ref) {
  final followed = {for (final s in ref.watch(followedSeriesProvider)) s.id: s};
  return ref
      .watch(seriesUpdatesProvider)
      .whenData(
        (updates) => [
          for (final u in updates)
            if (followed[u.series.id] case final f?
                when _within(u.aired, 45) && isNextFor(f, u))
              u,
        ]..sort((a, b) => b.aired.compareTo(a.aired)),
      );
});

final newSeasonsProvider = Provider<AsyncValue<List<SeriesUpdate>>>(
  (ref) => ref
      .watch(seriesUpdatesProvider)
      .whenData(
        (updates) =>
            updates
                .where((u) => u.season > 1 && _within(u.premiered, 120))
                .toList()
              ..sort((a, b) => b.premiered!.compareTo(a.premiered!)),
      ),
);
