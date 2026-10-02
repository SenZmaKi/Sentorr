import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/repository.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

/// Keeps what it is given in memory; nothing touches disk.
class MemoryFollowedSeries extends FollowedSeriesRepository {
  MemoryFollowedSeries() : super(JsonFileStore(File('unused')));

  List<FollowedSeries> saved = [];

  @override
  Future<List<FollowedSeries>?> load() async => saved;

  @override
  Future<void> save(List<FollowedSeries> series) async => saved = series;
}

List<Override> followedSeriesOverrides([
  List<FollowedSeries> series = const [],
  MemoryFollowedSeries? repository,
]) => [
  followedSeriesRepositoryProvider.overrideWithValue(
    repository ?? MemoryFollowedSeries(),
  ),
  initialFollowedSeriesProvider.overrideWithValue(series),
];

FollowedSeries following(
  ImdbTitle series, {
  int season = 1,
  required int episode,
  double progress = 1,
  DateTime? watchedAt,
  String? notified,
}) => FollowedSeries(
  series: series,
  reached: (season: season, episode: episode),
  progress: progress,
  watchedAt: watchedAt ?? DateTime.now(),
  notified: notified,
);
