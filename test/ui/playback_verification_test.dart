import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/integrity.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/pages/player/recover_download.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

class ControlledIntegrity extends LibraryIntegrity {
  ControlledIntegrity(super.ref);
  final pending = <Completer<IntegrityResult>>[];
  int recoveries = 0;
  bool replaceRecord = false;
  OnIntegrityProgress? onProgress;
  @override
  Future<IntegrityResult> check(
    LibraryEntry entry, {
    OnIntegrityProgress? onProgress,
  }) {
    this.onProgress = onProgress;
    final done = Completer<IntegrityResult>();
    pending.add(done);
    return done.future;
  }

  @override
  Future<void> recover(LibraryEntry entry) async {
    recoveries++;
    if (replaceRecord) {
      await ref
          .read(libraryProvider.notifier)
          .add(
            LibraryEntry(
              item: entry.item,
              downloadId: 'recovery',
              release: entry.release,
              fileIndex: entry.fileIndex,
              path: entry.path,
              addedAt: entry.addedAt,
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}

void main() {
  testWidgets(
    'recovery record replacement resumes playback without another check',
    (tester) async {
      final entry = LibraryEntry(
        item: PlaybackItem(title: fakeTitle(1)),
        downloadId: 'copy',
        release: fakeRelease(1),
        fileIndex: 0,
        path: '/movie.mkv',
        addedAt: DateTime(2026),
      );
      late ControlledIntegrity service;
      var ready = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...libraryOverrides([entry]),
            libraryIntegrityProvider.overrideWith(
              (ref) => service = ControlledIntegrity(ref)..replaceRecord = true,
            ),
          ],
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final current = ref.watch(libraryProvider).single;
                  return LocalPlaybackProblem(
                    key: ValueKey((current.id, current.path)),
                    entry: current,
                    onReady: () => ready++,
                    onBack: () {},
                    chooseLabel: 'Search for torrents',
                  );
                },
              ),
            ),
          ),
        ),
      );
      service.pending.single.complete(
        const IntegrityResult(IntegrityState.damaged, 'Damaged'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recover missing pieces'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(
        service.pending,
        hasLength(1),
        reason: 'must not recheck the active recovery',
      );
      expect(service.recoveries, 1);
    },
  );

  testWidgets('recording a passed check does not start another', (
    tester,
  ) async {
    final entry = LibraryEntry(
      item: PlaybackItem(title: fakeTitle(1)),
      downloadId: 'download',
      release: fakeRelease(1),
      fileIndex: 0,
      path: '/movie.mkv',
      addedAt: DateTime(2026),
    );
    late ControlledIntegrity service;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides([entry]),
          libraryIntegrityProvider.overrideWith(
            (ref) => service = ControlledIntegrity(ref),
          ),
        ],
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                final current = ref.watch(libraryProvider).single;
                return LocalPlaybackProblem(
                  key: ValueKey((current.id, current.path)),
                  entry: current,
                  onReady: () {},
                  onBack: () {},
                  onRetry: () {},
                  chooseLabel: 'Search for torrents',
                );
              },
            ),
          ),
        ),
      ),
    );
    service.pending.single.complete(
      const IntegrityResult(IntegrityState.valid, 'Valid'),
    );
    await widgetRef
        .read(libraryProvider.notifier)
        .update(entry.verified(DateTime(2026, 2)));
    await tester.pumpAndSettle();
    expect(service.pending, hasLength(1));
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final state in IntegrityState.values) {
      testWidgets('$brightness playback verification: $state', (tester) async {
        final entry = LibraryEntry(
          item: PlaybackItem(title: fakeTitle(1)),
          downloadId: 'download',
          release: fakeRelease(1),
          fileIndex: 0,
          path: '/movie.mkv',
          addedAt: DateTime(2026),
        );
        late ControlledIntegrity service;
        var ready = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...libraryOverrides([entry]),
              libraryIntegrityProvider.overrideWith(
                (ref) => service = ControlledIntegrity(ref),
              ),
            ],
            child: MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: Scaffold(
                body: LocalPlaybackProblem(
                  entry: entry,
                  onReady: () => ready++,
                  onBack: () {},
                  onRetry: () {},
                  chooseLabel: 'Search for torrents',
                ),
              ),
            ),
          ),
        );
        expect(service.pending, hasLength(1));
        expect(find.textContaining('Checking the file'), findsOneWidget);
        expect(find.text('Recover missing pieces'), findsNothing);
        service.pending.single.complete(
          IntegrityResult(state, 'Result: $state'),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Result: $state'), findsOneWidget);
        if (state.recoverable) {
          await tester.tap(find.text('Recover missing pieces'));
          await tester.pumpAndSettle();
          expect(service.recoveries, 1);
          expect(ready, 1);
        } else if (state == IntegrityState.unavailable) {
          expect(find.text('Recover missing pieces'), findsNothing);
          await tester.tap(find.text('Retry verification'));
          await tester.pump();
          expect(service.pending, hasLength(2));
          // A completed check after navigation must not update disposed UI.
          await tester.pumpWidget(const SizedBox());
          service.pending.last.complete(
            const IntegrityResult(IntegrityState.valid, 'Valid'),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        } else {
          expect(find.text('Recover missing pieces'), findsNothing);
          expect(find.text('Try again'), findsOneWidget);
        }
      });
    }
  }
}
