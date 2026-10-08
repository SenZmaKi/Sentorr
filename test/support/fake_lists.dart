import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/lists/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

/// Keeps what it is given in memory; nothing touches disk.
class MemoryWatchLists extends WatchListsRepository {
  MemoryWatchLists() : super(JsonFileStore(File('unused')));

  List<ListEntry> saved = [];

  @override
  Future<List<ListEntry>?> load() async => saved;

  @override
  Future<void> save(List<ListEntry> entries) async => saved = entries;
}

List<Override> watchListsOverrides([
  List<ListEntry> entries = const [],
  MemoryWatchLists? repository,
]) => [
  watchListsRepositoryProvider.overrideWithValue(
    repository ?? MemoryWatchLists(),
  ),
  initialWatchListsProvider.overrideWithValue(entries),
];

/// [titles] on the Watching list, so their new episodes are looked for.
List<Override> watchingOverrides(Iterable<ImdbTitle> titles) =>
    watchListsOverrides([
      for (final t in titles)
        ListEntry(
          title: t,
          status: WatchStatus.watching,
          updatedAt: DateTime(2026),
        ),
    ]);
