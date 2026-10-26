import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/sync/continuity/notifier.dart';
import 'package:sentorr/sync/continuity/session.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/ui/pages/home/continuity_card.dart';
import 'package:sentorr/ui/pages/home/home_layout.dart';
import 'package:sentorr/ui/shared/layout/layout_size.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

class _Offers extends ContinuityOffers {
  @override
  List<ContinuityOffer> build() => [
    ContinuityOffer(
      'mac',
      'MacBook',
      ContinuitySession(
        id: 'watching',
        media: PeerMedia(
          item: PlaybackItem(title: fakeTitle(1)),
          size: 100,
          name: 'movie.mp4',
          release: fakeRelease(1),
          fileIndex: 0,
        ),
        position: const Duration(seconds: 83),
        duration: const Duration(minutes: 10),
        playing: true,
      ),
    ),
  ];
}

class _Session extends PlayerSessionNotifier {
  _Session(this.open);
  final bool open;
  @override
  PlayerSession? build() =>
      open ? PlayerSession(request: PlayTitle(fakeTitle(2))) : null;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('phone continuity card shows and dismisses ($brightness)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            continuityOffersProvider.overrideWith(_Offers.new),
            playerSessionProvider.overrideWith(() => _Session(false)),
          ],
          child: MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: HomeLayout(
                layout: LayoutSize(const Size(390, 844)),
                textScaler: const TextScaler.linear(1.5),
                child: const ContinuityCard(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Playing on MacBook'), findsOneWidget);
      expect(find.text('1:23'), findsOneWidget);
      expect(find.text('Continue here'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Dismiss continuity suggestion'));
      await tester.pumpAndSettle();
      expect(find.text('Continue here'), findsNothing);
    });
  }

  testWidgets('existing local player suppresses continuity suggestion', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          continuityOffersProvider.overrideWith(_Offers.new),
          playerSessionProvider.overrideWith(() => _Session(true)),
        ],
        child: const MaterialApp(home: Scaffold(body: ContinuityCard())),
      ),
    );
    expect(find.text('Continue here'), findsNothing);
  });
}
