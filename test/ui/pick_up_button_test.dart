import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/ui/components/pick_up_button.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

PickUp _continue(int episode) => PickUp(
  season: 2,
  item: PlaybackItem(
    title: fakeTitle(3),
    series: fakeTitle(2, series: true),
    season: 2,
    episode: episode,
  ),
);

void main() {
  late PickUp? pick;
  late Completer<PickUp?> request;
  late int plays;

  Future<ProviderContainer> show(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double scale = 1,
  }) async {
    request = Completer<PickUp?>();
    plays = 0;
    final container = ProviderContainer(
      overrides: [
        pickUpPresentationProvider('tt2').overrideWith((ref) => pick),
        pickUpProvider('tt2').overrideWith((ref) => request.future),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSentorrTheme(brightness),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      PickUpButton(titleId: 'tt2', onPressed: () => plays++),
                      const SizedBox(
                        key: ValueKey('next'),
                        width: 70,
                        height: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('a title with nothing to pick up is a natural Play', (
    tester,
  ) async {
    pick = null;
    await show(tester);
    expect(find.text('Play'), findsOneWidget);
    expect(find.byType(Skeleton), findsNothing);
    final play = tester.getSize(find.byType(PickUpButton)).width;
    // Icon, gap, label and padding only: no reserved episode slot.
    expect(play, lessThan(tester.getSize(find.text('Play')).width + 80));
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('episode code fills its skeleton slot in $brightness at '
          '$scale', (tester) async {
        pick = const PickUp(season: 2, pending: true);
        final container = await show(
          tester,
          brightness: brightness,
          scale: scale,
        );
        final skeleton = find.byType(Skeleton);
        expect(skeleton, findsOneWidget);
        expect(
          find.textContaining('Continue ', findRichText: true),
          findsOneWidget,
        );
        final slot = tester.getTopLeft(skeleton);
        final icon = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
        final before = tester.getSize(find.byType(PickUpButton));
        await tester.tap(find.byType(PickUpButton));
        expect(plays, 1, reason: 'pending still plays via the lookup');

        pick = _continue(12);
        container.invalidate(pickUpPresentationProvider('tt2'));
        await tester.pump();
        expect(skeleton, findsNothing);
        final code = find.text('S2 E12');
        expect(tester.getTopLeft(code), slot);
        expect(tester.getRect(find.byIcon(Icons.play_arrow_rounded)), icon);
        final after = tester.getSize(find.byType(PickUpButton));
        expect(after.height, before.height);
        expect((after.width - before.width).abs(), lessThan(4 * scale));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('failed metadata lookup settles on Continue', (tester) async {
    pick = const PickUp(season: 2, pending: true);
    await show(tester);
    request.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });
}
