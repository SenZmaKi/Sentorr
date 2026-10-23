import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/ui/pages/player/audio_selection.dart';
import 'package:sentorr/ui/pages/player/menu_rows.dart';
import 'package:sentorr/ui/components/scrolling_text.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/player/track_labels.dart';

import '../support/fake_playback.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('resolves auto audio and scrolls its label in $brightness', (
      tester,
    ) async {
      final player = Player(platformPlayer: FakePlayback());
      addTearDown(player.dispose);
      const japanese = AudioTrack(
        '2',
        'Original theatrical surround soundtrack',
        'jpn',
      );
      const tracks = Tracks(audio: [AudioTrack('1', null, 'eng'), japanese]);
      final pending = Completer<String?>();
      Future<void> show(Track track) => tester.pumpWidget(
        MaterialApp(
          theme: buildSentorrTheme(brightness),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: AudioSelection(
                player: player,
                tracks: tracks,
                track: track,
                readNativeId: () => pending.future,
                builder: (audio) => PlayerMenuRow(
                  label: 'Audio',
                  value: audio == null ? '2 available' : audioLabel(audio),
                  scrollValue: audio != null,
                  selected: audio?.id == japanese.id,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await show(const Track());
      expect(find.text('2 available'), findsOneWidget);
      pending.complete('2');
      await tester.pump();
      final row = tester.widget<PlayerMenuRow>(find.byType(PlayerMenuRow));
      expect(row.value, audioLabel(japanese));
      expect(row.scrollValue, isTrue);
      expect(row.selected, isTrue);
      expect(find.byType(ScrollingText), findsOneWidget);
      await show(const Track(audio: AudioTrack('1', null, null)));
      await tester.pump();
      expect(
        tester.widget<PlayerMenuRow>(find.byType(PlayerMenuRow)).value,
        'English',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
