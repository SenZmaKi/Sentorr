import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/integrity.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

class FixtureIntegrity extends LibraryIntegrity {
  FixtureIntegrity(super.ref, {this.offline = false, this.failure});
  final bool offline;
  final Object? failure;
  int fileChecks = 0;
  @override
  Future<Uint8List?> metadata(LibraryEntry entry) async =>
      offline ? null : Uint8List(0);
  @override
  Future<void> verify(
    LibraryEntry entry,
    String path,
    Uint8List data, {
    OnIntegrityProgress? onProgress,
  }) async {
    fileChecks++;
    if (failure case final error?) throw error;
  }
}

void main() {
  final entry = LibraryEntry(
    item: PlaybackItem(title: fakeTitle(1)),
    downloadId: 'file',
    release: fakeRelease(1),
    fileIndex: 0,
    path: '/movie.mkv',
    addedAt: DateTime(2026),
  );
  for (final scenario in [
    (offline: false, error: null, expected: IntegrityState.valid),
    (offline: true, error: null, expected: IntegrityState.unavailable),
    (
      offline: false,
      error: const IncompleteMedia(),
      expected: IntegrityState.damaged,
    ),
    (
      offline: false,
      error: const UnverifiableMedia(),
      expected: IntegrityState.inconclusive,
    ),
    (
      offline: false,
      error: StateError('disk unavailable'),
      expected: IntegrityState.unavailable,
    ),
  ]) {
    test(
      'verification verdict: offline=${scenario.offline}, ${scenario.error}',
      () async {
        late FixtureIntegrity integrity;
        final container = ProviderContainer(
          overrides: [
            ...libraryOverrides([entry]),
            libraryIntegrityProvider.overrideWith(
              (ref) => integrity = FixtureIntegrity(
                ref,
                offline: scenario.offline,
                failure: scenario.error,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(libraryIntegrityProvider)
            .check(entry);
        expect(result.state, scenario.expected);
        expect(integrity.fileChecks, scenario.offline ? 0 : 1);
        expect(
          container.read(libraryProvider).single.verifiedAt != null,
          scenario.expected == IntegrityState.valid,
        );
      },
    );
  }
}
