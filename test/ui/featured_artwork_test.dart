import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/ui/pages/home/featured_artwork.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';

class _Imdb extends FakeImdbRepository {
  final requested = <String>{};
  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) {
    requested.add(id);
    return super.getTitleDetails(id);
  }
}

void main() {
  testWidgets('rapid spotlight changes retain only the latest outgoing image', (
    tester,
  ) async {
    Widget show(int index) => MaterialApp(
      home: SpotlightCrossfade(
        child: Text('artwork $index', key: ValueKey(index)),
      ),
    );
    await tester.pumpWidget(show(0));
    await tester.pumpWidget(show(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(show(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('artwork 0'), findsNothing);
    expect(find.text('artwork 1'), findsOneWidget);
    expect(find.text('artwork 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('artwork 1'), findsNothing);
    expect(find.text('artwork 2'), findsOneWidget);
  });

  testWidgets(
    'spotlight loads current and upcoming titles, including wraparound',
    (tester) async {
      final imdb = _Imdb();
      final container = ProviderContainer(
        overrides: [imdbRepositoryProvider.overrideWithValue(imdb)],
      );
      addTearDown(container.dispose);
      final titles = [for (var n = 1; n <= 5; n++) fakeTitle(n)];
      Widget show(int index) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSentorrTheme(Brightness.dark),
          home: SizedBox(
            width: 900,
            height: 450,
            child: FeaturedArtwork(titles: titles, index: index),
          ),
        ),
      );
      await tester.pumpWidget(show(0));
      await tester.pump();
      expect(imdb.requested, {'tt1', 'tt2'});
      await tester.pumpWidget(show(1));
      await tester.pump();
      expect(imdb.requested, {'tt1', 'tt2', 'tt3'});
      await tester.pumpWidget(show(4));
      await tester.pump(const Duration(seconds: 2));
      expect(imdb.requested, {'tt1', 'tt2', 'tt3', 'tt5'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
}
