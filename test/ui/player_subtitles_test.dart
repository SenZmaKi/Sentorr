import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/player/stream/subtitles.dart';
import 'package:sentorr/ui/pages/player/captions_control.dart';
import 'package:sentorr/ui/pages/player/captions_view.dart';
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

class _VisualPlayer extends FakePlayback {
  void emitSubtitle(List<String> lines) {
    state = state.copyWith(subtitle: lines);
    subtitleController.add(lines);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
  }
}

void main() {
  testWidgets('paused caption survives full, mini and pop-out round trips', (
    tester,
  ) async {
    final native = _VisualPlayer();
    const track = SubtitleTrack('1', 'English', 'en');
    native.state = native.state.copyWith(
      playing: false,
      track: native.state.track.copyWith(subtitle: track),
      subtitle: ['Paused caption'],
    );
    final player = Player(platformPlayer: native);
    final captions = PlaybackSubtitles(player)..opened();
    addTearDown(captions.dispose);
    Future<void> show(Size size, {required bool compact}) => tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Center(
          child: SizedBox.fromSize(
            size: size,
            child: CaptionsView(
              player: player,
              captions: captions,
              compact: compact,
              lifted: !compact,
            ),
          ),
        ),
      ),
    );
    for (final compactSize in [const Size(192, 108), const Size(480, 270)]) {
      await show(const Size(800, 600), compact: false);
      await tester.pumpAndSettle();
      expect(find.text('Paused caption'), findsOneWidget);
      await show(compactSize, compact: true);
      await tester.pumpAndSettle();
      final compactFrame = tester.getRect(find.byType(CaptionsView));
      expect(
        tester.getRect(find.text('Paused caption')).bottom,
        greaterThan(compactFrame.bottom - 20),
      );
      await show(const Size(800, 600), compact: false);
      await tester.pumpAndSettle();
      final fullFrame = tester.getRect(find.byType(CaptionsView));
      expect(
        tester.getRect(find.text('Paused caption')).bottom,
        closeTo(fullFrame.bottom - 128, 1),
      );
      expect(player.state.playing, false);
      expect(player.state.track.subtitle, track);
      expect(captions.visible, true);
      expect(tester.takeException(), isNull);
    }
  });
  for (final brightness in Brightness.values) {
    for (final size in [const Size(192, 108), const Size(480, 270)]) {
      testWidgets(
        'compact captions stay near the bottom at $size in $brightness',
        (tester) async {
          final native = _VisualPlayer();
          const track = SubtitleTrack('1', 'English', 'en');
          native.state = native.state.copyWith(
            track: native.state.track.copyWith(subtitle: track),
            subtitle: ['Compact caption', 'Second line'],
          );
          final player = Player(platformPlayer: native);
          final captions = PlaybackSubtitles(player)..opened();
          addTearDown(captions.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: CaptionsView(
                    player: player,
                    captions: captions,
                    compact: true,
                    // Even retained full-player control state must not lift it.
                    lifted: true,
                  ),
                ),
              ),
            ),
          );
          final overlay = tester.getRect(find.byType(CaptionsView));
          final text = tester.getRect(
            find.text('Compact caption\nSecond line'),
          );
          expect(text.bottom, greaterThan(overlay.bottom - 20));
          expect(text.bottom, lessThan(overlay.bottom));
          expect(text.top, greaterThan(overlay.center.dy));
          expect(text.center.dx, closeTo(overlay.center.dx, 1));
          expect(tester.takeException(), isNull);
          native.emitSubtitle(['Updated caption']);
          await tester.pump();
          expect(find.text('Updated caption'), findsOneWidget);
          captions.off();
          await tester.pump();
          expect(find.text('Updated caption'), findsNothing);
        },
      );
    }
    testWidgets(
      'Off hides retained and newly arriving caption text in $brightness',
      (tester) async {
        final native = _VisualPlayer();
        const track = SubtitleTrack('1', 'English', 'en');
        native.state = native.state.copyWith(
          track: native.state.track.copyWith(subtitle: track),
          subtitle: ['Current caption', ''],
        );
        final player = Player(platformPlayer: native);
        final captions = PlaybackSubtitles(player);
        captions.opened();
        addTearDown(captions.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: CaptionsView(
                player: player,
                captions: captions,
                lifted: false,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Current caption'), findsOneWidget);
        captions.off();
        await tester.pump();
        expect(find.text('Current caption'), findsNothing);
        native.emitSubtitle(['Later caption', '']);
        await tester.pump();
        expect(find.text('Later caption'), findsNothing);
        captions.on();
        await tester.pump();
        expect(find.text('Later caption'), findsOneWidget);
      },
    );
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
