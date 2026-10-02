import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../imdb/models.dart';
import '../imdb/repository.dart';

const _series = ['tvSeries', 'tvMiniSeries'];

/// Public catalog rows on the home page, each one IMDb request.
enum CatalogRow {
  trending('Trending now', 'Most watched this week'),
  newReleases('New releases', 'Movies out in the last few months'),
  popularSeries('Popular series'),
  popularMovies('Popular movies'),
  topRated('All-time greats', 'The highest rated movies and series'),
  action('Action'),
  comedy('Comedy'),
  sciFi('Sci-fi'),
  animation('Animation'),
  horror('Horror');

  const CatalogRow(this.title, [this.subtitle]);
  final String title;
  final String? subtitle;

  Future<List<ImdbTitle>> fetch(ImdbRepository imdb, CancelToken cancel) async {
    Future<List<ImdbTitle>> search(ImdbSearchFilters filters) async =>
        (await imdb.searchTitles(
          filters,
          limit: 24,
          cancelToken: cancel,
        )).items;
    // Genre rows skip obscure or unreleased entries with few votes.
    ImdbSearchFilters genre(String id) =>
        ImdbSearchFilters(genres: [id], voteCount: ImdbRange(min: 5000));
    final now = DateTime.now();
    return switch (this) {
      trending => imdb.trendingTitles(limit: 30, cancelToken: cancel),
      newReleases => search(
        ImdbSearchFilters(
          typeIds: const ['movie'],
          releasedFrom: now.subtract(const Duration(days: 120)),
          releasedThrough: now,
          voteCount: ImdbRange(min: 2000),
        ),
      ),
      popularSeries => search(ImdbSearchFilters(typeIds: _series)),
      popularMovies => search(
        ImdbSearchFilters(
          typeIds: const ['movie'],
          releasedThrough: now,
          voteCount: ImdbRange(min: 1000),
        ),
      ),
      topRated => search(
        ImdbSearchFilters(
          voteCount: ImdbRange(min: 250000),
          sort: ImdbSort.rating,
          descending: true,
        ),
      ),
      action => search(genre('Action')),
      comedy => search(genre('Comedy')),
      sciFi => search(genre('Sci-Fi')),
      animation => search(genre('Animation')),
      horror => search(genre('Horror')),
    };
  }
}

final catalogRowProvider = FutureProvider.family<List<ImdbTitle>, CatalogRow>((
  ref,
  row,
) {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return row.fetch(ref.watch(imdbRepositoryProvider), cancel);
});

/// The spotlight rotates through the top of the trending chart.
final featuredTitlesProvider = FutureProvider<List<ImdbTitle>>((ref) async {
  final trending = await ref.watch(
    catalogRowProvider(CatalogRow.trending).future,
  );
  return trending.where((t) => t.poster != null).take(5).toList();
});
