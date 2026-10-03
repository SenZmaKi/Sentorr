import 'package:flutter/widgets.dart';

import '../../../player/engine.dart';
import '../../../player/session.dart';
import '../../shared/theme/theme.dart';
import 'episodes_panel.dart';
import 'panel_slot.dart';
import 'player_actions.dart';
import 'player_ui.dart';
import 'settings_menu.dart';
import 'torrents_panel.dart';

/// The open panel's content and preferred width, wherever it is placed:
/// floating or as a sheet in [PanelSlot], or docked beside the picture.
/// Null when no panel is open or the open one has nothing to show.
SlotPanel? openPlayerPanel({
  required PlayerUi ui,
  required PlayerSession session,
  required PlaybackEngine engine,
  required PlayerActions actions,
}) {
  final queue = session.queue;
  return switch (ui.panel) {
    PlayerPanel.settings => (
      width: PlayerMetrics.menuWidth,
      child: SettingsMenu(
        key: const ValueKey('settings'),
        player: engine.player,
        actions: actions,
      ),
    ),
    PlayerPanel.queue when queue != null => (
      width: PlayerMetrics.queueWidth,
      child: EpisodesPanel(
        key: const ValueKey('queue'),
        queue: queue,
        onJump: actions.session.jump,
        onClose: ui.closePanel,
      ),
    ),
    PlayerPanel.torrents when session.current != null => (
      width: PlayerMetrics.torrentsWidth,
      child: TorrentsPanel(
        key: ValueKey('torrents ${session.current!.id}'),
        item: session.current!,
        status: engine.streaming.status,
        onSwitch: (torrent, options) =>
            actions.switchTorrent(torrent, options: options),
        onClose: ui.closePanel,
      ),
    ),
    _ => null,
  };
}
