import 'package:dio/dio.dart';

import '../imdb/models.dart';
import '../imdb/repository.dart';

/// All episodes of a season, including later catalog pages. Totals describe
/// announced episodes, so callers still decide which dates have aired.
Future<ImdbPage<ImdbEpisode>> seasonEpisodes(
  ImdbRepository imdb,
  String id,
  int season, {
  bool refresh = false,
  CancelToken? cancel,
}) async {
  final episodes = <ImdbEpisode>[];
  final cursors = <String>{};
  String? cursor;
  int? total;
  do {
    final page = await imdb.getEpisodes(
      id,
      season,
      limit: 50,
      cursor: cursor,
      refresh: refresh,
      cancelToken: cancel,
    );
    episodes.addAll(page.items);
    total = page.total ?? total;
    cursor = page.nextCursor;
    if (cursor != null && !cursors.add(cursor)) {
      throw const FormatException('Repeated episode page cursor');
    }
  } while (cursor != null);
  return ImdbPage(items: episodes, total: total);
}
