import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/watching/repository.dart';

/// Keeps what it is given in memory; nothing touches disk.
class MemoryWatchHistory extends WatchHistoryRepository {
  MemoryWatchHistory() : super(JsonFileStore(File('unused')));

  List<WatchEntry> saved = [];

  @override
  Future<List<WatchEntry>> load() async => saved;

  @override
  Future<void> save(List<WatchEntry> entries) async => saved = entries;
}

/// Overrides for a watch history starting with [entries].
List<Override> watchHistoryOverrides([
  List<WatchEntry> entries = const [],
  MemoryWatchHistory? repository,
]) => [
  watchHistoryRepositoryProvider.overrideWithValue(
    repository ?? MemoryWatchHistory(),
  ),
  initialWatchHistoryProvider.overrideWithValue(entries),
];
