import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

/// Keeps what it is given in memory; nothing touches disk.
class MemoryLibrary extends LibraryRepository {
  MemoryLibrary() : super(JsonFileStore(File('unused')));

  List<LibraryEntry> saved = [];

  @override
  Future<List<LibraryEntry>> load() async => saved;

  @override
  Future<void> save(List<LibraryEntry> entries) async => saved = entries;
}

List<Override> libraryOverrides([
  List<LibraryEntry> entries = const [],
  MemoryLibrary? repository,
]) => [
  libraryRepositoryProvider.overrideWithValue(repository ?? MemoryLibrary()),
  initialLibraryProvider.overrideWithValue(entries),
];
