import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/repository.dart';
import 'package:sentorr/shared/net/net.dart';

/// Explicit, bounded live check. Never part of the offline test suite.
Future<void> main() async {
  final network = NetworkClient();
  final repository = ImdbRepository(network.dio);
  try {
    final trending = await repository.trendingTitles(limit: 2, refresh: true);
    stdout.writeln('Trending: ${trending.map((t) => t.id).join(", ")}');
    final filters = ImdbSearchFilters(term: 'matrix');
    final search = await repository.searchTitles(
      filters,
      limit: 2,
      refresh: true,
    );
    final second = await repository.searchTitles(
      filters,
      limit: 2,
      cursor: search.nextCursor,
      refresh: true,
    );
    stdout.writeln(
      'Search: ${search.items.length}/${second.items.length} '
      'across two pages, total ${search.total}',
    );
    for (final id in ['tt0133093', 'tt0903747']) {
      final details = await repository.getTitleDetails(
        id,
        previewLimit: 2,
        refresh: true,
      );
      stdout.writeln(
        'Details ${details.title.title}: ${details.credits.items.length} '
        'credits, ${details.seasons.length} seasons, ${details.images.items.length} images',
      );
    }
    final episodes = await repository.getEpisodes(
      'tt0903747',
      2,
      limit: 2,
      refresh: true,
    );
    final ep2 = await repository.getEpisodes(
      'tt0903747',
      2,
      limit: 2,
      cursor: episodes.nextCursor,
      refresh: true,
    );
    stdout.writeln(
      'Episodes: ${[...episodes.items, ...ep2.items].map((e) => e.episodeNumber)}',
    );
    final episode = await repository.getEpisode(
      episodes.items.first.title.id,
      refresh: true,
    );
    stdout.writeln('Episode detail: ${episode.title.title}');
    final reviews = await repository.getReviews(
      'tt0133093',
      limit: 2,
      refresh: true,
    );
    final rev2 = await repository.getReviews(
      'tt0133093',
      limit: 2,
      cursor: reviews.nextCursor,
      refresh: true,
    );
    stdout.writeln(
      'Reviews: ${reviews.items.length}/${rev2.items.length} across two pages',
    );
    final credits = await repository.getCredits(
      'tt0133093',
      limit: 2,
      refresh: true,
    );
    final credits2 = await repository.getCredits(
      'tt0133093',
      limit: 2,
      cursor: credits.nextCursor,
      refresh: true,
    );
    stdout.writeln(
      'Credits: ${credits.items.length}/${credits2.items.length} across two pages',
    );
    final images = await repository.getImages(
      'tt0903747',
      limit: 2,
      refresh: true,
    );
    final images2 = await repository.getImages(
      'tt0903747',
      limit: 2,
      cursor: images.nextCursor,
      refresh: true,
    );
    stdout.writeln(
      'Images: ${images.items.length}/${images2.items.length} across two pages',
    );
    final related = await repository.getRecommendations(
      'tt0133093',
      limit: 2,
      refresh: true,
    );
    stdout.writeln('Recommendations: ${related.items.length}');
  } catch (error) {
    stderr.writeln(error);
    if (error is DioException) stderr.writeln(error.response?.data);
    exitCode = 1;
  } finally {
    await network.close();
  }
}
