import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/ui/components/pick_up_button.dart';
import 'package:sentorr/ui/components/skeleton.dart';
import 'package:sentorr/ui/components/surface.dart';
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
  late int episodeLists;

  Future<ProviderContainer> show(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double scale = 1,
  }) async {
    request = Completer<PickUp?>();
    plays = 0;
    episodeLists = 0;
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
                      PickUpButton(
                        titleId: 'tt2',
                        onPressed: () => plays++,
                        onCaughtUp: () => episodeLists++,
                      ),
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

  testWidgets('a title with nothing to pick up shows Play', (tester) async {
    pick = null;
    await show(tester);
    expect(find.text('Play'), findsOneWidget);
    expect(find.byType(Skeleton), findsNothing);
    await tester.tap(find.byType(PickUpButton));
    expect(plays, 1);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('text skeleton keeps its button size in $brightness at '
          '$scale', (tester) async {
        pick = const PickUp(season: 2, pending: true);
        final container = await show(
          tester,
          brightness: brightness,
          scale: scale,
        );
        expect(find.byType(Skeleton), findsOneWidget);
        expect(find.textContaining('Continue'), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        final surface = tester.widget<DepthBox>(
          find.descendant(
            of: find.byType(PickUpButton),
            matching: find.byType(DepthBox),
          ),
        );
        final context = tester.element(find.byType(PickUpButton));
        expect(surface.style.fill, context.colors.action);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
          context.colors.onAction,
        );
        final before = tester.getRect(find.byType(PickUpButton));
        final neighbour = tester.getRect(find.byKey(const ValueKey('next')));
        final skeleton = tester.getRect(find.byType(Skeleton));
        final icon = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
        expect(skeleton.left, greaterThanOrEqualTo(icon.right + 8));
        expect(skeleton.right, lessThan(before.right));
        expect(skeleton.height, lessThan(before.height));
        await tester.tap(find.byType(PickUpButton));
        expect(plays, 1, reason: 'loading keeps the normal enabled button');

        for (final resolved in [
          _continue(12),
          const PickUp(season: 2),
          PickUp(
            season: null,
            item: PlaybackItem(title: fakeTitle(3)),
            resume: true,
          ),
        ]) {
          pick = resolved;
          container.invalidate(pickUpPresentationProvider('tt2'));
          await tester.pump();
          expect(find.byType(Skeleton), findsNothing);
          expect(tester.getRect(find.byType(PickUpButton)), before);
          expect(tester.getRect(find.byKey(const ValueKey('next'))), neighbour);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('caught up opens episodes instead of playing', (tester) async {
    pick = const PickUp(season: 2);
    await show(tester);
    expect(find.text('Caught up'), findsOneWidget);
    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    await tester.tap(find.byType(PickUpButton));
    expect(episodeLists, 1);
    expect(plays, 0);
  });

  testWidgets('failed lookup offers retry without changing size', (
    tester,
  ) async {
    pick = const PickUp(season: 2, pending: true);
    await show(tester);
    final before = tester.getSize(find.byType(PickUpButton));
    request.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Retry continue'), findsOneWidget);
    expect(tester.getSize(find.byType(PickUpButton)), before);
    await tester.tap(find.byType(PickUpButton));
    expect(plays, 1);
  });
}
