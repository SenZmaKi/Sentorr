import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/providers.dart';
import 'package:sentorr/ui/components/cards/review_card_skeleton.dart';
import 'package:sentorr/ui/components/shelf.dart';
import 'package:sentorr/ui/pages/title/title_shelves.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'reviews reserve space while loading then hide empty results: $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final result = Completer<List<ImdbReview>>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              titleReviewsProvider.overrideWith((ref, key) => result.future),
            ],
            child: MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: Scaffold(
                body: Builder(
                  builder: (context) => SingleChildScrollView(
                    child: ReviewsShelf(
                      titleId: 'tt1',
                      layout: TitleShelfLayout(
                        context,
                        layout: LayoutSize(MediaQuery.sizeOf(context)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Reviews'), findsOneWidget);
        expect(find.byType(ReviewCardSkeleton), findsWidgets);
        for (final width in [390.0, 1440.0, 3440.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pump();
          final shelf = tester.widget<Shelf>(find.byType(Shelf));
          final tilesWidth =
              shelf.itemCount * shelf.tileWidth +
              (shelf.itemCount - 1) * Space.s16;
          expect(tilesWidth, greaterThan(width));
          expect(tester.takeException(), isNull);
        }
        result.complete([]);
        await tester.pump();
        await tester.pump();
        expect(find.text('Reviews'), findsNothing);
        expect(find.byType(ReviewCardSkeleton), findsNothing);
      },
    );
  }
}
