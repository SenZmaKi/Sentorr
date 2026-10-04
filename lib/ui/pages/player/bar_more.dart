import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/menu.dart';
import '../../components/player_control.dart';
import 'bar_fit.dart';
import 'player_actions.dart';
import 'player_ui.dart';

/// The bar's overflow: the [controls] it had no room for, as a menu (a
/// bottom sheet on a touch phone), so every action stays reachable.
class BarMore extends StatelessWidget {
  const BarMore({
    super.key,
    required this.controls,
    required this.ui,
    required this.actions,
    required this.queue,
  });

  final List<BarControl> controls;
  final PlayerUi ui;
  final PlayerActions actions;
  final PlayQueue? queue;

  @override
  Widget build(BuildContext context) => ActionMenu(
    title: 'More',
    actions: [for (final c in controls) _action(context, c)],
    builder: (context, menu) => PlayerControl(
      icon: Icons.more_vert_rounded,
      tooltip: 'More',
      selected: menu.isOpen,
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    ),
  );

  MenuAction _action(BuildContext context, BarControl c) => switch (c) {
    BarControl.rotate => MenuAction(
      'Rotate',
      icon: Icons.screen_rotation_rounded,
      onPressed: () => actions.rotate(MediaQuery.orientationOf(context)),
    ),
    BarControl.fullscreen => MenuAction(
      ui.fullscreen ? 'Exit full screen' : 'Full screen',
      icon: ui.fullscreen
          ? Icons.fullscreen_exit_rounded
          : Icons.fullscreen_rounded,
      onPressed: actions.toggleFullscreen,
    ),
    BarControl.settings => MenuAction(
      'Settings',
      icon: Icons.settings_outlined,
      onPressed: () => ui.toggle(PlayerPanel.settings),
    ),
    BarControl.episodes => MenuAction(
      queue?.kind == QueueKind.episodes ? 'Episodes' : 'Up next',
      icon: Icons.video_library_outlined,
      onPressed: () => ui.toggle(PlayerPanel.queue),
    ),
    BarControl.next => MenuAction(
      'Next',
      icon: Icons.skip_next_rounded,
      onPressed: actions.next,
    ),
    BarControl.captions => MenuAction(
      'Captions',
      icon: Icons.closed_caption_outlined,
      onPressed: actions.toggleSubtitles,
    ),
    BarControl.torrents => MenuAction(
      'Torrents',
      icon: Icons.swap_horiz_rounded,
      onPressed: actions.toggleTorrents,
    ),
    BarControl.previous => MenuAction(
      'Previous',
      icon: Icons.skip_previous_rounded,
      onPressed: actions.previous,
    ),
    BarControl.popOut => MenuAction(
      'Pop out',
      icon: Icons.picture_in_picture_alt_rounded,
      onPressed: actions.popOut,
    ),
    BarControl.volume => MenuAction(
      'Mute or unmute',
      icon: Icons.volume_up_rounded,
      onPressed: actions.toggleMute,
    ),
  };
}
