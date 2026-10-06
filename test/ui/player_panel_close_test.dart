import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/player_layout.dart';
import 'package:sentorr/ui/pages/player/player_ui.dart';
import 'package:sentorr/ui/pages/player/top_bar.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'fullscreen panels protect player close controls in $brightness',
      (tester) async {
        final ui = PlayerUi()..fullscreen = true;
        final stream = ValueNotifier<StreamStatus?>(null);
        addTearDown(ui.dispose);
        addTearDown(stream.dispose);
        var closed = 0, docked = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: PlayerLayoutScope(
              child: PlayerUiScope(
                ui: ui,
                child: Scaffold(
                  body: TopBar(
                    item: null,
                    fallbackTitle: 'Movie',
                    stream: stream,
                    onBack: () => docked++,
                    onClose: () => closed++,
                  ),
                ),
              ),
            ),
          ),
        );
        for (final panel in [
          PlayerPanel.settings,
          PlayerPanel.queue,
          PlayerPanel.torrents,
        ]) {
          ui.toggle(panel);
          await tester.pump();
          await tester.tap(find.byTooltip('Stop and close'));
          await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
          expect(closed, 0);
          expect(docked, 0);
          final closeIcon = tester.widget<Icon>(
            find.byIcon(Icons.close_rounded),
          );
          // The outlined overlay supplies an explicit disabled color; flat
          // controls inherit theirs from IconTheme.
          final color =
              closeIcon.color ??
              IconTheme.of(tester.element(find.byIcon(Icons.close_rounded)))
                  .color;
          expect(
            color,
            brightness == Brightness.dark
                ? OverlayColors.inactiveTrack
                : PlayerColors.light.inactiveTrack,
          );
        }
        ui.closePanel();
        await tester.pump();
        await tester.tap(find.byTooltip('Stop and close'));
        expect(closed, 1);
        ui.toggle(PlayerPanel.settings);
        ui.fullscreen = false;
        await tester.pump();
        await tester.tap(find.byTooltip('Stop and close'));
        expect(closed, 2);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
