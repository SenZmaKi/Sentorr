import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/library/integrity.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/ui/components/download_button.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';
import 'playback_verification_test.dart' show ControlledIntegrity;

void main() {
  for (final brightness in Brightness.values) {
    for (final state in IntegrityState.values) {
      testWidgets('$brightness manual download verification: $state', (
        tester,
      ) async {
        final entry = LibraryEntry(
          item: PlaybackItem(title: fakeTitle(1)),
          downloadId: 'copy:peer:movie',
          release: fakeRelease(1),
          fileIndex: 0,
          path: '/movie.mkv',
          addedAt: DateTime(2026),
        );
        late ControlledIntegrity service;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...libraryOverrides([entry]),
              offlineStateProvider(entry.id)
                  .overrideWithValue(Downloaded(entry)),
              libraryIntegrityProvider.overrideWith(
                (ref) => service = ControlledIntegrity(ref),
              ),
            ],
            child: MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: Scaffold(
                body: Center(
                  child: DownloadButton(item: entry.item, labelled: true),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Downloaded'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify download'));
        // The running check spins, so it never settles.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(service.pending, hasLength(1));
        expect(find.text('Verifying download'), findsOneWidget);
        service.onProgress!(
          const IntegrityProgress(IntegrityStage.pieces, 0.42),
        );
        await tester.pump();
        expect(find.text('Check every piece'), findsOneWidget);
        expect(find.text('42%'), findsOneWidget);
        service.pending.single.complete(
          IntegrityResult(state, 'Check: $state'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Check: $state'), findsOneWidget);
        if (state == IntegrityState.damaged) {
          await tester.tap(find.text('Recover missing pieces'));
          await tester.pumpAndSettle();
          expect(service.recoveries, 1);
          expect(find.text('Recovery queued'), findsOneWidget);
        } else if (state == IntegrityState.unavailable) {
          await tester.tap(find.text('Retry verification'));
          await tester.pump(const Duration(seconds: 1));
          expect(service.pending, hasLength(2));
          await tester.tap(find.text('Close'));
          await tester.pump(const Duration(seconds: 1));
          service.pending.last.complete(
            const IntegrityResult(IntegrityState.valid, 'Verified'),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        } else {
          expect(find.text('Recover missing pieces'), findsNothing);
        }
      });
    }
  }
}
