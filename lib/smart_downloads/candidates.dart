import 'package:logging/logging.dart';

import '../following/due_episodes.dart';
import '../following/models.dart';
import '../imdb/repository.dart';
import '../player/models.dart';
import '../watching/models.dart';
import '../watching/notifier.dart';
import 'models.dart';

final _log = Logger('sentorr.smart_downloads.candidates');

/// Series and movies picks are drawn from, most recent first.
const maxSeries = 5, maxEpisodesPerSeries = 3, maxRecommendationSources = 3;

/// What smart downloads would download, best first: items the viewer is
/// partway through, then the next episodes of series they are watching,
/// one per series per round, then movies like ones they finished. Lazy,
/// so IMDb is asked only as far as the reserve needs; [skip] filters out
/// what is downloaded, dismissed or failed. Each item comes once.
Stream<SmartPick> smartCandidates({
  required ImdbRepository imdb,
  required List<WatchEntry> history,
  required List<FollowedSeries> series,
  required bool Function(PlaybackItem item) skip,
  DateTime? now,
}) async* {
  final seen = <String>{};
  bool fresh(PlaybackItem item) => !skip(item) && seen.add(item.id);

  for (final entry in inProgressEntries(history)) {
    if (fresh(entry.item)) yield SmartPick(entry.item, 'Continue watching');
  }

  final recent = [...series]
    ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  final episodes = <List<PlaybackItem>>[];
  for (final s in recent.take(maxSeries)) {
    try {
      episodes.add(
        await dueEpisodes(imdb, s, limit: maxEpisodesPerSeries, now: now),
      );
    } catch (error) {
      _log.warning('Could not list episodes of ${s.id}', error);
    }
  }
  for (var round = 0; round < maxEpisodesPerSeries; round++) {
    for (final due in episodes) {
      if (round < due.length && fresh(due[round])) {
        yield SmartPick(due[round], 'Next episode');
      }
    }
  }

  final year = (now ?? DateTime.now()).year;
  final watched = {for (final e in history) e.id};
  final sources = [
    for (final e in history)
      if (!e.isEpisode && e.finished) e,
  ].take(maxRecommendationSources);
  final suggestions = <List<SmartPick>>[];
  for (final source in sources) {
    try {
      final page = await imdb.getRecommendations(source.id);
      suggestions.add([
        for (final t in page.items)
          if (t.canHaveEpisodes != true &&
              (t.releaseYear ?? year + 1) <= year &&
              !watched.contains(t.id))
            SmartPick(
              PlaybackItem(title: t),
              'Because you watched ${source.title.title}',
            ),
      ]);
    } catch (error) {
      _log.warning('Could not get titles like ${source.id}', error);
    }
  }
  final longest = suggestions.fold(0, (n, s) => s.length > n ? s.length : n);
  for (var i = 0; i < longest; i++) {
    for (final picks in suggestions) {
      if (i < picks.length && fresh(picks[i].item)) yield picks[i];
    }
  }
}
