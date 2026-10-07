import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/subtitles.dart';
import 'package:sentorr/ui/pages/player/captions_control.dart';
import 'package:sentorr/ui/pages/player/player_actions.dart';
import 'package:sentorr/ui/pages/player/player_layout.dart';
import 'package:sentorr/ui/pages/player/player_ui.dart';
import 'package:sentorr/ui/pages/player/settings_menu.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_playback.dart';

class _Actions implements PlayerActions {
  _Actions(this.captions, this.ui);
  @override
  final PlaybackSubtitles captions;
  @override
  final PlayerUi ui;
  @override
  void toggleSubtitles() => captions.toggle();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'pending SRT remains selectable and CC shows progress in $brightness',
      (tester) async {
        final player = Player(platformPlayer: FakePlayback());
        final captions = PlaybackSubtitles(player);
        final ui = PlayerUi();
        addTearDown(captions.dispose);
        addTearDown(ui.dispose);
        final actions = _Actions(captions, ui);
        const file = TorrentStreamFile(
          index: 1,
          path: 'English.srt',
          length: 100,
          isPadFile: false,
        );
        captions.files = [const SubtitleDownload(file, bytes: 45)];
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: PlayerLayoutScope(
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 360,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CaptionsControl(actions: actions),
                          SettingsMenu(player: player, actions: actions),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .value,
          0.45,
        );
        expect(find.text('1 available'), findsOneWidget);
        await tester.tap(find.byType(CaptionsControl));
        await tester.pump();
        expect(captions.enabled, true);
        expect(find.text('English · Downloading 45%'), findsOneWidget);
        await tester.tap(find.text('Subtitles'));
        await tester.pumpAndSettle();
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Downloading 45%'), findsOneWidget);
        await tester.tap(find.text('Off'));
        await tester.pump();
        expect(captions.enabled, false);
        await tester.tap(find.text('English'));
        await tester.pump();
        expect(captions.enabled, true);
        expect(captions.selectedFile, 1);
        captions.files = [
          const SubtitleDownload(file, bytes: 100, path: '/tmp/English.srt'),
        ];
        captions.chooseFile(1);
        await tester.pump();
        expect(find.text('Ready'), findsNothing);
        expect(find.text('English'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
