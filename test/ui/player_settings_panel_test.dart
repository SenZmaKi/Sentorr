import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/ui/pages/player/player_actions.dart';
import 'package:sentorr/ui/pages/player/player_ui.dart';
import 'package:sentorr/ui/pages/player/settings_menu.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import 'package:sentorr/ui/pages/player/panel_slot.dart';
import 'package:sentorr/ui/pages/player/player_dock.dart';
import 'package:sentorr/ui/pages/player/player_layout.dart';

import '../support/fake_playback.dart';

void main() {
  for (final size in [const Size(1000, 700), const Size(1920, 1080)]) {
    testWidgets('settings popup becomes a full-height panel at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const menu = Key('settings panel');
      final ui = PlayerUi()..toggle(PlayerPanel.settings);
      addTearDown(ui.dispose);
      final player = Player(platformPlayer: FakePlayback());
      const picture = Key('picture');
      SlotPanel panel() => (
        width: 320.0,
        child: SettingsMenu(key: menu, player: player, actions: _Actions(ui)),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSentorrTheme(Brightness.dark),
            home: PlayerLayoutScope(
              child: ListenableBuilder(
                listenable: ui,
                builder: (context, _) => PlayerDock(
                  panel: ui.settingsPopup ? null : panel(),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: SizedBox(key: picture)),
                      PanelSlot(
                        floatingBars: false,
                        popup: ui.settingsPopup,
                        panel: panel(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final popup = tester.getRect(find.byType(SettingsMenu));
      expect(popup.height, lessThan(size.height - 112));
      expect(popup.bottom, size.height - 96);
      expect(tester.getSize(find.byKey(picture)).width, size.width);
      ui.fullscreen = true;
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is SettingsMenu && widget.key == menu,
        ),
      );
      expect(rect.width, 320);
      expect(
        tester.getSize(find.byKey(picture)).width,
        size.width >= 1440 ? size.width - 336 : size.width,
      );
      expect(rect.top, 16);
      expect(rect.bottom, size.height - (size.width >= 1440 ? 16 : 96));
      await tester.tap(find.text('Playback speed'));
      await tester.pumpAndSettle();
      expect(find.text('0.25×'), findsOneWidget);
      expect(tester.getRect(find.byType(SettingsMenu)), rect);
      ui.fullscreen = false;
      await tester.pumpAndSettle();
      final restored = tester.getRect(find.byType(SettingsMenu));
      expect(restored.height, lessThan(rect.height));
      expect(restored.bottom, size.height - 96);
      expect(tester.getSize(find.byKey(picture)).width, size.width);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pump(const Duration(seconds: 3));
      expect(ui.panel, PlayerPanel.none);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Actions implements PlayerActions {
  _Actions(this.ui);

  @override
  final PlayerUi ui;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
