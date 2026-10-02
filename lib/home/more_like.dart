import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../following/notifier.dart';
import '../imdb/models.dart';
import '../watching/notifier.dart';

/// How many of the most recently watched titles the seed is drawn from,
/// so the row stays close to what the viewer is into now.
const _recent = 3;

/// Drawn once per launch: the seed changes between launches, not while
/// the viewer browses.
final _draw = Random().nextInt(1 << 16);

/// Movies and series the viewer watched, most recent first; series only
/// followed from their page are not watched.
final _watchedProvider = Provider<List<ImdbTitle>>((ref) {
  final watched = [
    for (final e in ref.watch(watchHistoryProvider))
      (title: e.series ?? e.title, at: e.updatedAt),
    for (final s in ref.watch(followedSeriesProvider))
      if (!s.manual) (title: s.series, at: s.watchedAt),
  ]..sort((a, b) => b.at.compareTo(a.at));
  final seen = <String>{};
  return [
    for (final w in watched)
      if (seen.add(w.title.id)) w.title,
  ];
});

/// The recent title the "More like" row recommends from; null with no
/// watch history.
final moreLikeSeedProvider = Provider<ImdbTitle?>((ref) {
  // Progress saves every few seconds; only a change in the recent titles
  // needs a new pick.
  ref.watch(
    _watchedProvider.select((l) => l.take(_recent).map((t) => t.id).join(',')),
  );
  final recent = ref.read(_watchedProvider).take(_recent).toList();
  return recent.isEmpty ? null : recent[_draw % recent.length];
});

/// Titles like [moreLikeSeedProvider], leaving out what the viewer has
/// already watched.
final moreLikeProvider = FutureProvider<List<ImdbTitle>>((ref) async {
  final seed = ref.watch(moreLikeSeedProvider);
  if (seed == null) return const [];
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final page = await ref
      .watch(imdbRepositoryProvider)
      .getRecommendations(seed.id, limit: 24, cancelToken: cancel);
  final known = {for (final t in ref.read(_watchedProvider)) t.id};
  return [
    for (final t in page.items)
      if (!known.contains(t.id)) t,
  ];
});
