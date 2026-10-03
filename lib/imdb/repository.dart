import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../shared/net/cache_tiers.dart';
import 'client.dart';
import 'mappers.dart' as map;
import 'models.dart';
import 'queries.dart';

/// IMDb owns the unofficial schema. Sentorr owns query documents and models.
/// The supplied Dio remains caller-owned; no global singleton or browser.
class ImdbRepository {
  ImdbRepository(Dio dio, {String? endpoint})
    : _client = endpoint == null
          ? ImdbClient(dio)
          : ImdbClient(dio, endpoint: endpoint);
  final ImdbClient _client;

  void _limit(int value) {
    if (value < 1 || value > 50) throw RangeError.range(value, 1, 50, 'limit');
  }

  void _id(String value) {
    if (!RegExp(r'^tt\d+$').hasMatch(value)) {
      throw ArgumentError.value(value, 'titleId');
    }
  }

  T _parse<T>(T Function() action) {
    try {
      return action();
    } on ImdbException {
      rethrow;
    } catch (error, stack) {
      // The schema is unofficial; this names the field that moved.
      Logger('sentorr.imdb').warning('Unexpected response shape', error, stack);
      throw const ImdbException('Unexpected IMDb response shape.');
    }
  }

  map.Json _title(map.Json data, String id) {
    final title = map.object(data['title']);
    if (title == null) throw ImdbException('Title $id was not found.');
    return title;
  }

  Map<String, Object?> _pageVariables(String id, int limit, String? cursor) {
    _id(id);
    _limit(limit);
    return {'id': id, 'first': limit, 'after': ?cursor};
  }

  Future<List<ImdbTitle>> trendingTitles({
    int limit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    _limit(limit);
    final data = await _client.query(
      'SentorrTrending',
      trendingTitlesQuery,
      {'first': limit},
      cancelToken: cancelToken,
      refresh: refresh,
    );
    return _parse(() => map.page(data['topMeterTitles'], map.title).items);
  }

  Future<ImdbPage<ImdbTitle>> searchTitles(
    ImdbSearchFilters filters, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    _limit(limit);
    final data = await _client.query(
      'SentorrSearch',
      searchTitlesQuery,
      {
        'first': limit,
        'after': ?cursor,
        'constraints': filters.constraints,
        'sort': filters.ordering,
      },
      tier: CacheTier.liveSearch,
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(
      () => map.page(
        data['advancedTitleSearch'],
        (node) => map.title(map.object(node['title'])!),
      ),
    );
  }

  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    _id(id);
    _limit(previewLimit);
    final data = await _client.query(
      'SentorrDetails',
      titleDetailsQuery,
      {'id': id, 'first': previewLimit},
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(() => map.details(_title(data, id)));
  }

  Future<ImdbEpisode> getEpisode(
    String id, {
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    _id(id);
    final data = await _client.query(
      'SentorrEpisode',
      episodeQuery,
      {'id': id},
      refresh: refresh,
      cancelToken: cancelToken,
    );
    final episode = _parse(() => map.episode(_title(data, id)));
    if (episode.title.typeId != 'tvEpisode') {
      throw ImdbException('$id is not an episode.');
    }
    return episode;
  }

  Future<ImdbPage<ImdbEpisode>> getEpisodes(
    String id,
    int seasonNumber, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    if (seasonNumber < 0) throw RangeError.value(seasonNumber, 'seasonNumber');
    final variables = _pageVariables(id, limit, cursor)
      ..['season'] = seasonNumber.toString();
    final data = await _client.query(
      'SentorrEpisodes',
      episodesQuery,
      variables,
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(() {
      final episodes = map.object(_title(data, id)['episodes']);
      if (episodes == null) {
        throw ImdbException('$id has no episode collection.');
      }
      return map.page(episodes['episodes'], map.episode);
    });
  }

  Future<ImdbPage<ImdbReview>> getReviews(
    String id, {
    int limit = 20,
    String? cursor,
    bool hideSpoilers = true,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    final variables = _pageVariables(id, limit, cursor)
      ..['filter'] = {if (hideSpoilers) 'spoiler': 'EXCLUDE'};
    final data = await _client.query(
      'SentorrReviews',
      reviewsQuery,
      variables,
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(() => map.page(_title(data, id)['reviews'], map.review));
  }

  Future<ImdbPage<ImdbCredit>> getCredits(
    String id, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.query(
      'SentorrCredits',
      creditsQuery,
      _pageVariables(id, limit, cursor),
      tier: CacheTier.reference,
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(() => map.page(_title(data, id)['credits'], map.credit));
  }

  Future<ImdbPage<ImdbTitle>> getRecommendations(
    String id, {
    int limit = 10,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.query(
      'SentorrRecommendations',
      recommendationsQuery,
      _pageVariables(id, limit, cursor),
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(
      () => map.page(_title(data, id)['moreLikeThisTitles'], map.title),
    );
  }

  Future<ImdbPage<ImdbImage>> getImages(
    String id, {
    int limit = 20,
    String? cursor,
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.query(
      'SentorrImages',
      imagesQuery,
      _pageVariables(id, limit, cursor),
      tier: CacheTier.reference,
      refresh: refresh,
      cancelToken: cancelToken,
    );
    return _parse(
      () => map.page(_title(data, id)['images'], (j) => map.image(j)!),
    );
  }

  Future<List<ImdbTitle>> suggestTitles(
    String term, {
    CancelToken? cancelToken,
  }) async {
    final normalized = term.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final response = await _client.dio.get<Object?>(
      'https://v3.sg.media-imdb.com/suggestion/x/${Uri.encodeComponent(normalized)}.json',
      cancelToken: cancelToken,
      options: Options(
        extra: cachedRequest(
          CacheTier.liveSearch,
          isValid: (data) => ImdbClient.decodeJson(data)['d'] is List,
        ),
      ),
    );
    if (response.statusCode != 200) {
      throw ImdbException('HTTP ${response.statusCode}');
    }
    final json = ImdbClient.decodeJson(response.data);
    return _parse(
      () => map
          .array(json['d'])
          .cast<map.Json>()
          .where((j) => RegExp(r'^tt\d+$').hasMatch(j['id'] as String))
          .map(
            (j) => ImdbTitle(
              id: j['id'] as String,
              title: j['l'] as String,
              poster: map.object(j['i']) == null
                  ? null
                  : ImdbImage(url: map.object(j['i'])!['imageUrl'] as String),
              releaseYear: j['y'] as int?,
              typeId: j['qid'] as String?,
            ),
          )
          .toList(),
    );
  }
}
