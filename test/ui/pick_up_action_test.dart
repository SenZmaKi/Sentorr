import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/launch.dart';
import 'package:sentorr/titles/pick_up.dart';
import 'package:sentorr/ui/shared/play_route.dart';
import 'package:sentorr/ui/shared/title_route.dart';

import '../support/fake_imdb.dart';

void main() {
  testWidgets('caught-up lookup opens title without launching playback; '
      'failed lookup retries instead of starting episode one', (tester) async {
    final title = fakeTitle(2, series: true);
    var attempts = 0;
    final container = ProviderContainer(
      overrides: [
        pickUpProvider(title.id).overrideWith((ref) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return const PickUp(season: 2);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () => ref.playOrPickUp(title),
                child: const Text('Continue'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(attempts, 1);
    expect(container.read(playbackLaunchProvider), isNull);
    expect(container.read(titleRoutesProvider), isEmpty);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(attempts, 2);
    expect(container.read(playbackLaunchProvider), isNull);
    expect(container.read(titleRoutesProvider).single.title.id, title.id);
  });
}
