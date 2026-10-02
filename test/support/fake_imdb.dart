import 'package:dio/dio.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/repository.dart';

ImdbTitle fakeTitle(int n, {bool series = false, int? year}) => ImdbTitle(
  id: 'tt$n',
  title: 'Title $n',
  typeId: series ? 'tvSeries' : 'movie',
  canHaveEpisodes: series,
  releaseYear: year ?? 2026,
  rating: 7.5,
  runtimeSeconds: 5400,
  plot: 'Plot $n',
);

/// In-memory IMDb with no artwork, so widget tests never touch the network.
class FakeImdbRepository implements ImdbRepository {
  FakeImdbRepository({
    List<ImdbTitle>? trending,
    this.seasons = const {},
    this.episodes = const {},
  }) : trending =
           trending ??
           [for (var i = 1; i <= 12; i++) fakeTitle(i, series: i.isEven)];

  final List<ImdbTitle> trending;

  /// Season numbers per series ID.
  final Map<String, List<int>> seasons;

  /// Episodes per `seriesId/season`.
  final Map<String, List<ImdbEpisode>> episodes;

  @override
  Future<List<ImdbTitle>> trendingTitles({
    int limit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => trending.take(limit).toList();

  @override
  Future<ImdbPage<ImdbTitle>> searchTitles(
    ImdbSearchFilters filters, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => ImdbPage(items: trending.take(limit).toList());

  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => ImdbTitleDetails(
    title: trending.firstWhere((t) => t.id == id),
    credits: ImdbPage(items: const []),
    recommendations: ImdbPage(
      items: trending.where((t) => t.id != id).take(4).toList(),
    ),
    images: ImdbPage(items: const []),
    seasons: seasons[id] ?? const [],
  );

  @override
  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => ImdbPage(items: episodes['$id/$seasonNumber'] ?? const []);

  @override
  Future<ImdbPage<ImdbReview>> getReviews(
    String id, {
    int limit = 20,
    String? cursor,
    bool hideSpoilers = true,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async => ImdbPage(
    items: [
      const ImdbReview(
        id: 'rw1',
        title: 'Gripping',
        content: 'Loved it.',
        rating: 9,
        upVotes: 1200,
        downVotes: 40,
      ),
      if (!hideSpoilers)
        const ImdbReview(
          id: 'rw2',
          title: 'That ending',
          content: 'The twist is everything.',
          spoiler: true,
        ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
